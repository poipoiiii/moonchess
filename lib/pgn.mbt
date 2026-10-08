/// PGN (Portable Game Notation) import and export.
///
/// The generator follows the format used by chess.js: a block of tag pairs
/// followed by the move text and a result token. The parser is tolerant of
/// comments (`{...}`), variations (`(...)`), NAGs (`$n`) and inline move
/// numbers, and it accepts SAN without the `+` / `#` suffix.

///|
/// Default seven-tag roster with fallbacks.
let pgn_roster : Array[(String, String)] = [
  ("Event", "?"),
  ("Site", "?"),
  ("Date", "????.??.??"),
  ("Round", "?"),
  ("White", "?"),
  ("Black", "?"),
  ("Result", "*"),
]

///|
/// Character at `index`, or NUL when out of range.
fn char_at(s : String, index : Int) -> Char {
  match s.get_char(index) {
    Some(c) => c
    None => '\u{0}'
  }
}

///|
/// Substring `s[start:end]` built by concatenating characters.
fn slice_string(s : String, start : Int, end : Int) -> String {
  let chars = s.to_array()
  let mut out = ""
  let mut i = if start < 0 { 0 } else { start }
  let stop = if end > chars.length() { chars.length() } else { end }
  while i < stop {
    out = out + chars[i].to_string()
    i = i + 1
  }
  out
}

///|
fn is_ascii_digit(ch : Char) -> Bool {
  ch >= '0' && ch <= '9'
}

///|
/// Whether `tok` is one of the PGN result tokens.
fn is_result_token(tok : String) -> Bool {
  tok == "1-0" || tok == "0-1" || tok == "1/2-1/2" || tok == "*"
}

///|
/// Remove a leading move-number such as `12.` or `12...` from a token.
fn strip_move_number(tok : String) -> String {
  let mut i = 0
  while i < tok.length() && is_ascii_digit(char_at(tok, i)) {
    i = i + 1
  }
  if i > 0 && i < tok.length() && char_at(tok, i) == '.' {
    while i < tok.length() && char_at(tok, i) == '.' {
      i = i + 1
    }
    return slice_string(tok, i, tok.length())
  }
  tok
}

///|
/// Delete PGN comments and variations, leaving headers and move text.
fn strip_pgn_comments(pgn : String) -> String {
  let mut out = ""
  let mut depth = 0
  let mut in_comment = false
  for ch in pgn {
    if in_comment {
      if ch == '}' {
        in_comment = false
      }
    } else if depth > 0 {
      if ch == '(' {
        depth = depth + 1
      } else if ch == ')' {
        depth = depth - 1
      }
    } else if ch == '{' {
      in_comment = true
    } else if ch == '(' {
      depth = depth + 1
    } else {
      out = out + ch.to_string()
    }
  }
  out
}

///|
/// Split a single tag-pair line `[Key "Value"]` into its parts.
fn parse_tag_pair(line : String) -> (String, String)? {
  match line.find(" ") {
    Some(space) => {
      let key = slice_string(line, 1, space)
      match (line.find("\""), line.rev_find("\"")) {
        (Some(q1), Some(q2)) =>
          if q2 > q1 {
            Some((key, slice_string(line, q1 + 1, q2)))
          } else {
            None
          }
        _ => None
      }
    }
    None => None
  }
}

///|
/// Play a SAN move, tolerating a missing or extra check / mate suffix.
fn Chess::apply_san(self : Chess, san : String) -> Bool {
  if self.move_by_san(san) is Some(_) {
    return true
  }
  if self.move_by_san(san + "+") is Some(_) {
    return true
  }
  if self.move_by_san(san + "#") is Some(_) {
    return true
  }
  let n = san.length()
  if n > 1 && (char_at(san, n - 1) == '+' || char_at(san, n - 1) == '#') {
    if self.move_by_san(slice_string(san, 0, n - 1)) is Some(_) {
      return true
    }
  }
  false
}

///|
/// Render the move text (with move numbers and line wrapping).
fn Chess::pgn_moves(self : Chess, max_width : Int) -> String {
  let moves = self.history()
  let mut text = ""
  let mut line = ""
  let mut number = 1
  for m in moves {
    let token = if m.color == White {
      let t = "\{number}. \{m.san}"
      number = number + 1
      t
    } else {
      m.san
    }
    if line == "" {
      line = token
    } else if line.length() + 1 + token.length() > max_width {
      text = text + line + "\n"
      line = token
    } else {
      line = line + " " + token
    }
  }
  if line != "" {
    text = text + line
  }
  text
}

///|
/// Export the game as PGN.
pub fn Chess::pgn(self : Chess, max_width? : Int = 80) -> String {
  let mut header = ""
  let seen : Array[String] = []
  for pair in pgn_roster {
    let value = match self.header(pair.0) {
      Some(v) => v
      None => pair.1
    }
    header = header + "[\{pair.0} \"\{value}\"]\n"
    seen.push(pair.0)
  }
  for pair in self.headers {
    if !seen.contains(pair.0) {
      header = header + "[\{pair.0} \"\{pair.1}\"]\n"
    }
  }
  let result = match self.header("Result") {
    Some(v) => v
    None => "*"
  }
  let moves = self.pgn_moves(max_width)
  let body = if moves == "" { result } else { moves + " " + result }
  header + "\n" + body + "\n"
}

///|
/// Load a game from PGN. Returns `true` if every move was applied.
pub fn Chess::load_pgn(self : Chess, pgn : String) -> Bool {
  self.headers = []
  self.reset()
  let cleaned = strip_pgn_comments(pgn)
  let mut move_text = ""
  for raw_line in cleaned.split("\n") {
    let trimmed = raw_line.trim().to_owned()
    if trimmed.length() == 0 {
      continue
    }
    if char_at(trimmed, 0) == '[' {
      match parse_tag_pair(trimmed) {
        Some((key, value)) => self.set_header(key, value)
        None => ()
      }
    } else {
      move_text = move_text + " " + trimmed
    }
  }
  let mut ok = true
  for raw in move_text.split(" ") {
    if raw.is_empty() {
      continue
    }
    let token = strip_move_number(raw.to_owned())
    if token.length() == 0 {
      continue
    }
    if is_result_token(token) {
      self.set_header("Result", token)
      break
    }
    if char_at(token, 0) == '$' {
      continue
    }
    if !self.apply_san(token) {
      ok = false
      break
    }
  }
  ok
}
