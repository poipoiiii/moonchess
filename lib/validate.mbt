/// Strict FEN validation.
///
/// `validate_fen` returns `None` for a well-formed, legal position, or a short
/// human-readable reason otherwise. It checks field count, rank widths, piece
/// letters, king counts, pawn placement, castling rights, the en-passant
/// square, the move counters, and that the side that just moved is not left in
/// check.

///|
/// Validate a FEN string, returning an error message when invalid.
pub fn validate_fen(fen : String) -> String? {
  let tokens : Array[String] = []
  for t in fen.split(" ") {
    if !t.is_empty() {
      tokens.push(t.to_owned())
    }
  }
  if tokens.length() != 6 {
    return Some("FEN must contain six space-delimited fields")
  }
  // 1. Piece placement.
  let rows : Array[String] = []
  for r in tokens[0].split("/") {
    rows.push(r.to_owned())
  }
  if rows.length() != 8 {
    return Some("FEN must describe eight ranks")
  }
  let mut white_kings = 0
  let mut black_kings = 0
  let mut rank = 7
  for row in rows {
    let mut file = 0
    for ch in row.to_array() {
      if ch >= '1' && ch <= '8' {
        file = file + (ch.to_int() - '0'.to_int())
      } else {
        match ch {
          'P' | 'p' =>
            if rank == 0 || rank == 7 {
              return Some("pawns may not sit on the first or last rank")
            } else {
              file = file + 1
            }
          'K' => {
            white_kings = white_kings + 1
            file = file + 1
          }
          'k' => {
            black_kings = black_kings + 1
            file = file + 1
          }
          'N' | 'B' | 'R' | 'Q' | 'n' | 'b' | 'r' | 'q' => file = file + 1
          _ => return Some("FEN contains an invalid piece letter")
        }
      }
    }
    if file != 8 {
      return Some("each FEN rank must describe eight files")
    }
    rank = rank - 1
  }
  if white_kings != 1 || black_kings != 1 {
    return Some("FEN must contain exactly one king per side")
  }
  // 2. Active color.
  match tokens[1] {
    "w" | "b" => ()
    _ => return Some("active color must be 'w' or 'b'")
  }
  // 3. Castling rights.
  if tokens[2] != "-" {
    let seen : Array[Char] = []
    for ch in tokens[2].to_array() {
      if ch != 'K' && ch != 'Q' && ch != 'k' && ch != 'q' {
        return Some("invalid castling rights")
      }
      if seen.contains(ch) {
        return Some("duplicate castling rights")
      }
      seen.push(ch)
    }
  }
  // 4. En passant square.
  if tokens[3] != "-" {
    match parse_square(tokens[3]) {
      Some(_) => ()
      None => return Some("invalid en passant square")
    }
  }
  // 5/6. Move counters.
  match parse_uint(tokens[4]) {
    Some(_) => ()
    None => return Some("invalid halfmove clock")
  }
  match parse_uint(tokens[5]) {
    Some(_) => ()
    None => return Some("invalid fullmove number")
  }
  // The side that just moved must not be left in check.
  match Chess::from_fen(fen) {
    Some(game) =>
      if king_in_check(game.board, game.turn.opponent()) {
        return Some("the side not to move is in check")
      }
    None => return Some("FEN could not be parsed")
  }
  None
}

///|
/// Whether a FEN string is valid.
pub fn is_valid_fen(fen : String) -> Bool {
  validate_fen(fen) is None
}
