/// The `Chess` game object, FEN handling, move application/undo, and static
/// position queries (check, insufficient material, repetition).

///|
/// Castling bit masks used to clear individual rights, indexed by right
/// (0 = White king-side, 1 = White queen-side, 2 = Black king-side,
/// 3 = Black queen-side).
let mask_keep : Array[Int] = [14, 13, 11, 7]

///|
/// Castling-right bits, in the same index order as `mask_keep`.
let castle_bits : Array[Int] = [1, 2, 4, 8]

///|
/// Back rank of each castling right's owner.
let castle_back_rank : Array[Int] = [0, 0, 7, 7]

///|
/// The standard opening position in FEN.
pub let start_fen : String = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"

///|
/// One entry of the internal undo stack.
struct HistoryEntry {
  mv : Move
  castling : Int
  ep : Square?
  half_moves : Int
  move_number : Int
  captured : Piece?
  captured_square : Square
}

///|
/// A complete chess game: board plus move history and status.
pub struct Chess {
  mut board : Array[Piece?]
  mut turn : Color
  mut castling : Int
  /// Start files of the king-side / queen-side rooks for each castling right
  /// (index order as `castle_bits`), or -1. Fixed for the whole game so that
  /// `undo` can always find the rook (Chess960).
  mut castle_rook : Array[Int]
  mut ep : Square?
  mut half_moves : Int
  mut move_number : Int
  history : Array[HistoryEntry]
  positions : Array[String]
  mut headers : Array[(String, String)]
}

///|
/// Index of a castling right (0 = White king-side, 1 = White queen-side,
/// 2 = Black king-side, 3 = Black queen-side).
fn castle_index(color : Color, kingside : Bool) -> Int {
  match color {
    White => if kingside { 0 } else { 1 }
    Black => if kingside { 2 } else { 3 }
  }
}

///|
/// File of `color`'s king on its back rank, or -1.
fn Chess::king_file_on_back_rank(self : Chess, color : Color) -> Int {
  let back = if color == White { 0 } else { 7 }
  let mut f = 0
  while f < 8 {
    match self.board[make_square(f, back)] {
      Some(p) => if p.kind == King && p.color == color { return f }
      None => ()
    }
    f = f + 1
  }
  -1
}

///|
/// Resolve a `K` / `Q` castling letter to the outermost rook file on that side.
fn Chess::resolve_castle_rook(
  self : Chess,
  color : Color,
  kingside : Bool,
) -> Int {
  let king_file = self.king_file_on_back_rank(color)
  if king_file < 0 {
    return -1
  }
  let back = if color == White { 0 } else { 7 }
  let mut best = -1
  let mut f = 0
  while f < 8 {
    match self.board[make_square(f, back)] {
      Some(p) =>
        if p.kind == Rook && p.color == color {
          if kingside {
            if f > king_file && f > best {
              best = f
            }
          } else if f < king_file && (best < 0 || f < best) {
            best = f
          }
        }
      None => ()
    }
    f = f + 1
  }
  best
}

///|
/// Record a resolved castling right (rook file + availability bit).
fn Chess::set_castle_right(
  self : Chess,
  color : Color,
  kingside : Bool,
  file : Int,
) -> Unit {
  if file >= 0 {
    let index = castle_index(color, kingside)
    self.castle_rook[index] = file
    self.castling = self.castling | castle_bits[index]
  }
}

///|
/// Castling letter for a rook file: `K`/`Q`/`k`/`q` when the rook sits on the
/// standard outer file, otherwise the file letter (upper case for White,
/// lower case for Black) as used by X-FEN / Shredder-FEN.
fn castle_char(file : Int, color : Color, kingside : Bool) -> String {
  let standard = if kingside { 7 } else { 0 }
  if file == standard {
    match (color, kingside) {
      (White, true) => "K"
      (White, false) => "Q"
      (Black, true) => "k"
      (Black, false) => "q"
    }
  } else {
    let base = if color == White { 'A'.to_int() } else { 'a'.to_int() }
    (base + file).unsafe_to_char().to_string()
  }
}

///|
/// Absolute difference of two integers.
fn abs_int(a : Int, b : Int) -> Int {
  if a > b {
    a - b
  } else {
    b - a
  }
}

///|
/// Parse a non-negative decimal integer, or `None`.
fn parse_uint(s : String) -> Int? {
  if s.length() == 0 {
    return None
  }
  let mut value = 0
  for ch in s {
    let d = ch.to_int() - '0'.to_int()
    if d < 0 || d > 9 {
      return None
    }
    value = value * 10 + d
  }
  Some(value)
}

///|
/// An empty game with the standard starting position.
pub fn Chess::new() -> Chess {
  let game : Chess = {
    board: empty_board(),
    turn: White,
    castling: 0,
    castle_rook: [-1, -1, -1, -1],
    ep: None,
    half_moves: 0,
    move_number: 1,
    history: [],
    positions: [],
    headers: [],
  }
  ignore(game.load_fen(start_fen))
  game
}

///|
/// A game loaded from a FEN string.
pub fn Chess::from_fen(fen : String) -> Chess? {
  let game = Chess::new()
  if game.load_fen(fen) {
    Some(game)
  } else {
    None
  }
}

///|
/// Clear the board and reset all state (no pieces on the board).
pub fn Chess::clear(self : Chess) -> Unit {
  self.board = empty_board()
  self.turn = White
  self.castling = 0
  self.castle_rook = [-1, -1, -1, -1]
  self.ep = None
  self.half_moves = 0
  self.move_number = 1
  self.history.clear()
  self.positions.clear()
  self.positions.push("empty")
}

///|
/// Reset to the standard starting position.
pub fn Chess::reset(self : Chess) -> Unit {
  ignore(self.load_fen(start_fen))
}

///|
/// Replace the current position with `fen`.
pub fn Chess::load_fen(self : Chess, fen : String) -> Bool {
  let tokens : Array[String] = []
  for t in fen.split(" ") {
    if !t.is_empty() {
      tokens.push(t.to_owned())
    }
  }
  if tokens.length() < 4 {
    return false
  }
  self.clear()
  // 1. Piece placement.
  let rows : Array[String] = []
  for r in tokens[0].split("/") {
    rows.push(r.to_owned())
  }
  if rows.length() != 8 {
    return false
  }
  let mut rank = 7
  for row in rows {
    let mut file = 0
    for ch in row.to_array() {
      if ch >= '1' && ch <= '8' {
        file = file + (ch.to_int() - '0'.to_int())
      } else {
        match PieceType::from_char(ch) {
          Some(kind) => {
            if file > 7 || rank < 0 {
              return false
            }
            let color = if ch.is_ascii_uppercase() { White } else { Black }
            self.board[make_square(file, rank)] = Some({ kind, color, })
            file = file + 1
          }
          None => return false
        }
      }
    }
    if file != 8 {
      return false
    }
    rank = rank - 1
  }
  // 2. Active color.
  match tokens[1] {
    "w" => self.turn = White
    "b" => self.turn = Black
    _ => return false
  }
  // 3. Castling availability (standard KQkq or Chess960 file letters).
  if tokens[2] != "-" {
    for ch in tokens[2].to_array() {
      match ch {
        'K' =>
          self.set_castle_right(
            White,
            true,
            self.resolve_castle_rook(White, true),
          )
        'Q' =>
          self.set_castle_right(
            White,
            false,
            self.resolve_castle_rook(White, false),
          )
        'k' =>
          self.set_castle_right(
            Black,
            true,
            self.resolve_castle_rook(Black, true),
          )
        'q' =>
          self.set_castle_right(
            Black,
            false,
            self.resolve_castle_rook(Black, false),
          )
        'A' | 'B' | 'C' | 'D' | 'E' | 'F' | 'G' | 'H' => {
          let file = ch.to_int() - 'A'.to_int()
          self.set_castle_right(
            White,
            file > self.king_file_on_back_rank(White),
            file,
          )
        }
        'a' | 'b' | 'c' | 'd' | 'e' | 'f' | 'g' | 'h' => {
          let file = ch.to_int() - 'a'.to_int()
          self.set_castle_right(
            Black,
            file > self.king_file_on_back_rank(Black),
            file,
          )
        }
        _ => return false
      }
    }
  }
  // 4. En passant target square.
  if tokens[3] != "-" {
    self.ep = parse_square(tokens[3])
  }
  // 5/6. Halfmove clock and fullmove number.
  if tokens.length() > 4 {
    match parse_uint(tokens[4]) {
      Some(n) => self.half_moves = n
      None => return false
    }
  }
  if tokens.length() > 5 {
    match parse_uint(tokens[5]) {
      Some(n) => self.move_number = n
      None => return false
    }
  }
  self.positions.push(self.position_key())
  true
}

///|
/// The FEN string for the current position.
pub fn Chess::fen(self : Chess) -> String {
  let mut placement = ""
  let mut rank = 7
  while rank >= 0 {
    let mut empty = 0
    let mut file = 0
    while file < 8 {
      match self.board[make_square(file, rank)] {
        Some(p) => {
          if empty > 0 {
            placement = placement + empty.to_string()
            empty = 0
          }
          let c = p.kind.to_char()
          if p.color == White {
            placement = placement + c.to_ascii_uppercase().to_string()
          } else {
            placement = placement + c.to_string()
          }
        }
        None => empty = empty + 1
      }
      file = file + 1
    }
    if empty > 0 {
      placement = placement + empty.to_string()
    }
    if rank > 0 {
      placement = placement + "/"
    }
    rank = rank - 1
  }
  let mut castling = ""
  if (self.castling & castle_bits[0]) != 0 {
    castling = castling + castle_char(self.castle_rook[0], White, true)
  }
  if (self.castling & castle_bits[1]) != 0 {
    castling = castling + castle_char(self.castle_rook[1], White, false)
  }
  if (self.castling & castle_bits[2]) != 0 {
    castling = castling + castle_char(self.castle_rook[2], Black, true)
  }
  if (self.castling & castle_bits[3]) != 0 {
    castling = castling + castle_char(self.castle_rook[3], Black, false)
  }
  if castling == "" {
    castling = "-"
  }
  let ep = match self.ep {
    Some(sq) => square_name(sq)
    None => "-"
  }
  let turn = match self.turn {
    White => "w"
    Black => "b"
  }
  "\{placement} \{turn} \{castling} \{ep} \{self.half_moves} \{self.move_number}"
}

///|
/// A compact position key used for threefold-repetition detection.
fn Chess::position_key(self : Chess) -> String {
  let mut key = ""
  let mut rank = 7
  while rank >= 0 {
    let mut file = 0
    while file < 8 {
      match self.board[make_square(file, rank)] {
        Some(p) => {
          let c = p.kind.to_char()
          let upper = if p.color == White { c.to_ascii_uppercase() } else { c }
          key = key + upper.to_string()
        }
        None => key = key + "."
      }
      file = file + 1
    }
    rank = rank - 1
  }
  let turn = match self.turn {
    White => "w"
    Black => "b"
  }
  let ep = match self.ep {
    Some(sq) => square_name(sq)
    None => "-"
  }
  "\{key} \{turn} \{self.castling} \{ep}"
}

///|
/// Clear castling rights whose rook home square was vacated or captured.
fn Chess::clear_castling_for(self : Chess, rights : Int, sq : Square) -> Int {
  let mut result = rights
  let mut i = 0
  while i < 4 {
    let file = self.castle_rook[i]
    if file >= 0 && sq == make_square(file, castle_back_rank[i]) {
      result = result & mask_keep[i]
    }
    i = i + 1
  }
  result
}

///|
/// Apply `m` to the board and push it onto the history.
pub fn Chess::make_move(self : Chess, m : Move) -> Unit {
  let us = m.color
  let move_piece : Piece = { kind: m.piece, color: us, }
  // Determine where a captured piece sits (en passant differs from normal).
  let is_ep = m.captured is Some(_) &&
    m.piece == Pawn &&
    self.board[m.to] is None
  let captured_square = if is_ep {
    if us == White {
      m.to - 16
    } else {
      m.to + 16
    }
  } else {
    m.to
  }
  let captured = if m.captured is Some(_) {
    self.board[captured_square]
  } else {
    None
  }
  self.history.push({
    mv: m,
    castling: self.castling,
    ep: self.ep,
    half_moves: self.half_moves,
    move_number: self.move_number,
    captured,
    captured_square,
  })
  let is_castle = m.piece == King &&
    (m.flags.contains("k") || m.flags.contains("q"))
  if is_castle {
    let kingside = m.flags.contains("k")
    let index = castle_index(us, kingside)
    let back = castle_back_rank[index]
    let rook_from = make_square(self.castle_rook[index], back)
    let rook_to_file = if kingside { 5 } else { 3 }
    let rook_to = make_square(rook_to_file, back)
    let rook = self.board[rook_from]
    self.board[m.from] = None
    self.board[rook_from] = None
    self.board[m.to] = Some(move_piece)
    self.board[rook_to] = rook
  } else {
    // Remove the captured piece first: for normal captures its square equals
    // `to`, and for en passant it is the square behind `to`.
    if m.captured is Some(_) {
      self.board[captured_square] = None
    }
    // Move the piece.
    self.board[m.to] = Some(move_piece)
    self.board[m.from] = None
    // Promotion.
    match m.promotion {
      Some(kind) => self.board[m.to] = Some({ kind, color: us, })
      None => ()
    }
  }
  // Update castling rights.
  if m.piece == King {
    if us == White {
      self.castling = self.castling & (castle_bits[2] | castle_bits[3])
    } else {
      self.castling = self.castling & (castle_bits[0] | castle_bits[1])
    }
  }
  self.castling = self.clear_castling_for(self.castling, m.from)
  self.castling = self.clear_castling_for(self.castling, m.to)
  // En passant target square.
  if m.piece == Pawn && abs_int(m.from, m.to) == 32 {
    self.ep = Some((m.from + m.to) / 2)
  } else {
    self.ep = None
  }
  // Halfmove clock.
  if m.piece == Pawn || m.captured is Some(_) {
    self.half_moves = 0
  } else {
    self.half_moves = self.half_moves + 1
  }
  // Fullmove number advances after black's move.
  if us == Black {
    self.move_number = self.move_number + 1
  }
  self.turn = us.opponent()
  self.positions.push(self.position_key())
}

///|
/// Undo the most recent move, returning it if there was one.
pub fn Chess::undo_move(self : Chess) -> Move? {
  match self.history.pop() {
    None => None
    Some(e) => {
      let m = e.mv
      ignore(self.positions.pop())
      self.turn = m.color
      self.castling = e.castling
      self.ep = e.ep
      self.half_moves = e.half_moves
      self.move_number = e.move_number
      let is_castle = m.piece == King &&
        (m.flags.contains("k") || m.flags.contains("q"))
      if is_castle {
        let kingside = m.flags.contains("k")
        let index = castle_index(m.color, kingside)
        let back = castle_back_rank[index]
        let rook_from = make_square(self.castle_rook[index], back)
        let rook_to_file = if kingside { 5 } else { 3 }
        let rook_to = make_square(rook_to_file, back)
        let rook = self.board[rook_to]
        let king = self.board[m.to]
        self.board[rook_to] = None
        self.board[m.to] = None
        self.board[rook_from] = rook
        self.board[m.from] = king
      } else {
        // Move the piece back.
        self.board[m.from] = self.board[m.to]
        self.board[m.to] = None
        // Restore a promoted pawn.
        if m.promotion is Some(_) {
          self.board[m.from] = Some({ kind: Pawn, color: m.color, })
        }
      }
      // Restore the captured piece.
      match e.captured {
        Some(p) => self.board[e.captured_square] = Some(p)
        None => ()
      }
      Some(m)
    }
  }
}

///|
/// The side to move.
pub fn Chess::turn_color(self : Chess) -> Color {
  self.turn
}

///|
/// Whether White is to move.
pub fn Chess::side_is_white(self : Chess) -> Bool {
  self.turn == White
}

///|
/// Piece on a square (by index), if any.
pub fn Chess::piece_on(self : Chess, sq : Square) -> Piece? {
  piece_at(self.board, sq)
}

///|
/// Piece on a named square such as `e4`, if any.
pub fn Chess::get(self : Chess, name : String) -> Piece? {
  match parse_square(name) {
    Some(sq) => piece_at(self.board, sq)
    None => None
  }
}

///|
/// Place a piece on a named square.
pub fn Chess::put(
  self : Chess,
  kind : PieceType,
  color : Color,
  name : String,
) -> Bool {
  match parse_square(name) {
    Some(sq) => {
      set_piece(self.board, sq, Some({ kind, color, }))
      true
    }
    None => false
  }
}

///|
/// Remove and return the piece on a named square.
pub fn Chess::remove(self : Chess, name : String) -> Piece? {
  match parse_square(name) {
    Some(sq) => {
      let p = piece_at(self.board, sq)
      set_piece(self.board, sq, None)
      p
    }
    None => None
  }
}

///|
/// The board as 8 rows of 8 squares, from rank 8 (index 0) to rank 1.
pub fn Chess::board(self : Chess) -> Array[Array[Piece?]] {
  let rows : Array[Array[Piece?]] = []
  let mut rank = 7
  while rank >= 0 {
    let row : Array[Piece?] = []
    let mut file = 0
    while file < 8 {
      row.push(self.board[make_square(file, rank)])
      file = file + 1
    }
    rows.push(row)
    rank = rank - 1
  }
  rows
}

///|
/// Whether the side to move is in check.
pub fn Chess::is_check(self : Chess) -> Bool {
  king_in_check(self.board, self.turn)
}

///|
/// The undo stack size (number of moves played).
pub fn Chess::move_count(self : Chess) -> Int {
  self.history.length()
}

///|
/// The move history as a list of moves.
pub fn Chess::history(self : Chess) -> Array[Move] {
  self.history.map(fn(e) { e.mv })
}

///|
/// Whether the position has occurred at least three times.
pub fn Chess::is_threefold_repetition(self : Chess) -> Bool {
  let current = self.position_key()
  let mut count = 0
  for k in self.positions {
    if k == current {
      count = count + 1
    }
  }
  count >= 3
}

///|
/// Whether neither side has enough material to force a mate.
pub fn Chess::is_insufficient_material(self : Chess) -> Bool {
  let mut num_pieces = 0
  let mut bishops = 0
  let mut bishop_parity = 0
  let mut knights = 0
  let mut sq = 0
  while sq < 128 {
    if on_board(sq) {
      match self.board[sq] {
        Some(p) => {
          if p.kind == Pawn || p.kind == Rook || p.kind == Queen {
            return false
          }
          if p.kind == Knight {
            knights = knights + 1
          }
          if p.kind == Bishop {
            bishops = bishops + 1
            bishop_parity = bishop_parity + (file_of(sq) + rank_of(sq)) % 2
          }
          num_pieces = num_pieces + 1
        }
        None => ()
      }
    }
    sq = sq + 1
  }
  if num_pieces == 2 {
    return true
  }
  if num_pieces == 3 && (bishops == 1 || knights == 1) {
    return true
  }
  if num_pieces == bishops + 2 &&
    (bishop_parity == 0 || bishop_parity == bishops) {
    return true
  }
  false
}

///|
/// A game header value, or `None`.
pub fn Chess::header(self : Chess, key : String) -> String? {
  for pair in self.headers {
    if pair.0 == key {
      return Some(pair.1)
    }
  }
  None
}

///|
/// Set a game header value.
pub fn Chess::set_header(self : Chess, key : String, value : String) -> Unit {
  let mut i = 0
  while i < self.headers.length() {
    if self.headers[i].0 == key {
      self.headers[i] = (key, value)
      return
    }
    i = i + 1
  }
  self.headers.push((key, value))
}

///|
/// Remove a game header.
pub fn Chess::remove_header(self : Chess, key : String) -> Unit {
  self.headers = self.headers.filter(fn(pair) { pair.0 != key })
}
