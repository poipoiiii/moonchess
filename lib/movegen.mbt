/// Legal move generation, SAN notation, and turn-based game status.

///|
/// File letter for a file index `0..7`.
pub fn file_letter(file : Int) -> String {
  match "abcdefgh".get_char(file) {
    Some(c) => c.to_string()
    None => "?"
  }
}

///|
/// Rank digit for a rank index `0..7`.
pub fn rank_letter(rank : Int) -> String {
  match "12345678".get_char(rank) {
    Some(c) => c.to_string()
    None => "?"
  }
}

///|
/// Build a fresh move record with an empty SAN.
fn Chess::new_move(
  self : Chess,
  kind : PieceType,
  from : Square,
  to : Square,
  captured : PieceType?,
  promotion : PieceType?,
  flags : String,
) -> Move {
  {
    color: self.turn,
    from,
    to,
    piece: kind,
    promotion,
    captured,
    flags,
    san: "",
  }
}

///|
/// Generate pseudo-legal moves for the side to move.
fn Chess::pseudo_legal_moves(self : Chess) -> Array[Move] {
  let us = self.turn
  let moves : Array[Move] = []
  let mut from = 0
  while from < 128 {
    if on_board(from) {
      match self.board[from] {
        Some(piece) =>
          if piece.color == us {
            match piece.kind {
              Pawn => self.gen_pawn_moves(moves, from, us)
              Knight => self.gen_step_moves(moves, from, us, knight_offsets)
              Bishop => self.gen_slide_moves(moves, from, us, bishop_offsets)
              Rook => self.gen_slide_moves(moves, from, us, rook_offsets)
              Queen => {
                self.gen_slide_moves(moves, from, us, bishop_offsets)
                self.gen_slide_moves(moves, from, us, rook_offsets)
              }
              King => {
                self.gen_step_moves(moves, from, us, king_offsets)
                self.gen_castling_moves(moves, from, us)
              }
            }
          }
        None => ()
      }
    }
    from = from + 1
  }
  moves
}

///|
/// Non-sliding piece moves (knight / king).
fn Chess::gen_step_moves(
  self : Chess,
  moves : Array[Move],
  from : Square,
  us : Color,
  offsets : Array[Int],
) -> Unit {
  let kind = match self.board[from] {
    Some(p) => p.kind
    None => return
  }
  for i = 0; i < offsets.length(); i = i + 1 {
    let to = from + offsets[i]
    if on_board(to) {
      match self.board[to] {
        Some(p) =>
          if p.color != us {
            moves.push(self.new_move(kind, from, to, Some(p.kind), None, "c"))
          }
        None => moves.push(self.new_move(kind, from, to, None, None, "n"))
      }
    }
  }
}

///|
/// Sliding piece moves (bishop / rook / queen).
fn Chess::gen_slide_moves(
  self : Chess,
  moves : Array[Move],
  from : Square,
  us : Color,
  offsets : Array[Int],
) -> Unit {
  let kind = match self.board[from] {
    Some(p) => p.kind
    None => return
  }
  for i = 0; i < offsets.length(); i = i + 1 {
    let dir = offsets[i]
    let mut to = from + dir
    while on_board(to) {
      match self.board[to] {
        Some(p) => {
          if p.color != us {
            moves.push(self.new_move(kind, from, to, Some(p.kind), None, "c"))
          }
          break
        }
        None => {
          moves.push(self.new_move(kind, from, to, None, None, "n"))
          to = to + dir
        }
      }
    }
  }
}

///|
/// Add all four promotion choices to the move list.
fn Chess::add_promotions(
  self : Chess,
  moves : Array[Move],
  from : Square,
  to : Square,
  captured : PieceType?,
) -> Unit {
  let flags = if captured is Some(_) { "cp" } else { "np" }
  for kind in [Queen, Rook, Bishop, Knight] {
    moves.push(self.new_move(Pawn, from, to, captured, Some(kind), flags))
  }
}

///|
/// Pawn pushes, captures, and en passant.
fn Chess::gen_pawn_moves(
  self : Chess,
  moves : Array[Move],
  from : Square,
  us : Color,
) -> Unit {
  let dir = if us == White { 16 } else { -16 }
  let start_rank = if us == White { 1 } else { 6 }
  let promo_rank = if us == White { 7 } else { 0 }
  // Single and double pushes.
  let one = from + dir
  if on_board(one) && self.board[one] is None {
    if rank_of(one) == promo_rank {
      self.add_promotions(moves, from, one, None)
    } else {
      moves.push(self.new_move(Pawn, from, one, None, None, "n"))
      if rank_of(from) == start_rank {
        let two = from + 2 * dir
        if self.board[two] is None {
          moves.push(self.new_move(Pawn, from, two, None, None, "b"))
        }
      }
    }
  }
  // Diagonal captures (including en passant).
  let caps : Array[Int] = [from + dir - 1, from + dir + 1]
  for to in caps {
    if on_board(to) {
      match self.board[to] {
        Some(p) =>
          if p.color != us {
            if rank_of(to) == promo_rank {
              self.add_promotions(moves, from, to, Some(p.kind))
            } else {
              moves.push(self.new_move(Pawn, from, to, Some(p.kind), None, "c"))
            }
          }
        None =>
          match self.ep {
            Some(e) =>
              if e == to {
                let enemy_square = to - dir
                let valid = match self.board[enemy_square] {
                  Some(p) => p.kind == Pawn && p.color != us
                  None => false
                }
                if valid {
                  moves.push(
                    self.new_move(Pawn, from, to, Some(Pawn), None, "e"),
                  )
                }
              }
            None => ()
          }
      }
    }
  }
}

///|
/// Castling moves for the king on `from`, honouring Chess960 rook squares.
fn Chess::gen_castling_moves(
  self : Chess,
  moves : Array[Move],
  from : Square,
  us : Color,
) -> Unit {
  let back = if us == White { 0 } else { 7 }
  if rank_of(from) != back {
    return
  }
  self.try_castle(moves, from, us, back, true)
  self.try_castle(moves, from, us, back, false)
}

///|
/// Whether every square from `a` to `b` (inclusive) is empty, ignoring the
/// king and the castling rook themselves.
fn Chess::castle_path_clear(
  self : Chess,
  a : Int,
  b : Int,
  back : Int,
  king_sq : Square,
  rook_sq : Square,
) -> Bool {
  let lo = if a < b { a } else { b }
  let hi = if a < b { b } else { a }
  let mut f = lo
  while f <= hi {
    let sq = make_square(f, back)
    if sq != king_sq && sq != rook_sq {
      if self.board[sq] is Some(_) {
        return false
      }
    }
    f = f + 1
  }
  true
}

///|
/// Try one castling side: king and rook present, paths clear, and the king
/// neither in check nor passing through an attacked square.
fn Chess::try_castle(
  self : Chess,
  moves : Array[Move],
  from : Square,
  us : Color,
  back : Int,
  kingside : Bool,
) -> Unit {
  let index = castle_index(us, kingside)
  if (self.castling & castle_bits[index]) == 0 {
    return
  }
  let rook_file = self.castle_rook[index]
  if rook_file < 0 {
    return
  }
  let rook_sq = make_square(rook_file, back)
  match self.board[rook_sq] {
    Some(p) => if p.kind != Rook || p.color != us { return }
    None => return
  }
  let king_file = file_of(from)
  let king_to_file = if kingside { 6 } else { 2 }
  let rook_to_file = if kingside { 5 } else { 3 }
  // Squares strictly between king and rook must be empty.
  let lo = if king_file < rook_file { king_file } else { rook_file }
  let hi = if king_file < rook_file { rook_file } else { king_file }
  let mut f = lo + 1
  while f < hi {
    if self.board[make_square(f, back)] is Some(_) {
      return
    }
    f = f + 1
  }
  // King path and rook path must be clear.
  if !self.castle_path_clear(king_file, king_to_file, back, from, rook_sq) {
    return
  }
  if !self.castle_path_clear(rook_file, rook_to_file, back, from, rook_sq) {
    return
  }
  // The king may not start in check nor pass through an attacked square.
  let them = us.opponent()
  f = lo_of(king_file, king_to_file)
  while f <= hi_of(king_file, king_to_file) {
    if is_attacked(self.board, make_square(f, back), them) {
      return
    }
    f = f + 1
  }
  let flag = if kingside { "k" } else { "q" }
  moves.push(
    self.new_move(King, from, make_square(king_to_file, back), None, None, flag),
  )
}

///|
/// Smaller of two integers.
fn lo_of(a : Int, b : Int) -> Int {
  if a < b {
    a
  } else {
    b
  }
}

///|
/// Larger of two integers.
fn hi_of(a : Int, b : Int) -> Int {
  if a < b {
    b
  } else {
    a
  }
}

///|
/// SAN disambiguation prefix for a move.
fn get_disambiguator(m : Move, all_legal : Array[Move]) -> String {
  let mut ambiguities = 0
  let mut same_rank = 0
  let mut same_file = 0
  for x in all_legal {
    if x.piece == m.piece && x.to == m.to && x.from != m.from {
      ambiguities = ambiguities + 1
      if rank_of(x.from) == rank_of(m.from) {
        same_rank = same_rank + 1
      }
      if file_of(x.from) == file_of(m.from) {
        same_file = same_file + 1
      }
    }
  }
  if ambiguities == 0 {
    ""
  } else if same_rank > 0 && same_file > 0 {
    square_name(m.from)
  } else if same_file > 0 {
    rank_letter(rank_of(m.from))
  } else {
    file_letter(file_of(m.from))
  }
}

///|
/// Build the SAN string for a move that is already known to be legal.
fn Chess::san_for(self : Chess, m : Move, all_legal : Array[Move]) -> String {
  let mut out = ""
  if m.flags.contains("k") {
    out = "O-O"
  } else if m.flags.contains("q") {
    out = "O-O-O"
  } else {
    let disambig = get_disambiguator(m, all_legal)
    if m.piece != Pawn {
      out = out + m.piece.to_char().to_ascii_uppercase().to_string() + disambig
    }
    if m.captured is Some(_) {
      if m.piece == Pawn {
        out = out + file_letter(file_of(m.from))
      }
      out = out + "x"
    }
    out = out + square_name(m.to)
    match m.promotion {
      Some(k) => out = out + "=" + k.to_char().to_ascii_uppercase().to_string()
      None => ()
    }
  }
  // Check / checkmate suffix.
  self.make_move(m)
  let checking = king_in_check(self.board, m.color.opponent())
  let mut suffix = ""
  if checking {
    if self.legal_moves_raw().length() == 0 {
      suffix = "#"
    } else {
      suffix = "+"
    }
  }
  ignore(self.undo_move())
  out + suffix
}

///|
/// Copy a move with a computed SAN string.
fn Chess::fill_san(self : Chess, m : Move, all_legal : Array[Move]) -> Move {
  let san = self.san_for(m, all_legal)
  {
    color: m.color,
    from: m.from,
    to: m.to,
    piece: m.piece,
    promotion: m.promotion,
    captured: m.captured,
    flags: m.flags,
    san,
  }
}

///|
/// Legal moves without SAN (fast path).
fn Chess::legal_moves_raw(self : Chess) -> Array[Move] {
  let pseudo = self.pseudo_legal_moves()
  let legal : Array[Move] = []
  for m in pseudo {
    self.make_move(m)
    if !king_in_check(self.board, m.color) {
      legal.push(m)
    }
    ignore(self.undo_move())
  }
  legal
}

///|
/// All legal moves for the side to move, with SAN filled in.
pub fn Chess::moves(self : Chess) -> Array[Move] {
  let legal = self.legal_moves_raw()
  let result : Array[Move] = []
  for m in legal {
    result.push(self.fill_san(m, legal))
  }
  result
}

///|
/// Count leaf nodes of the legal move tree to a given depth (perft).
pub fn Chess::perft(self : Chess, depth : Int) -> Int {
  let moves = self.legal_moves_raw()
  if depth <= 1 {
    return moves.length()
  }
  let mut nodes = 0
  for m in moves {
    self.make_move(m)
    nodes = nodes + self.perft(depth - 1)
    ignore(self.undo_move())
  }
  nodes
}

///|
/// Perft split by each legal root move, returned as `(SAN, node count)`.
pub fn Chess::perft_divide(self : Chess, depth : Int) -> Array[(String, Int)] {
  let moves = self.moves()
  let out : Array[(String, Int)] = []
  for m in moves {
    self.make_move(m)
    let nodes = if depth <= 1 { 1 } else { self.perft(depth - 1) }
    ignore(self.undo_move())
    out.push((m.san, nodes))
  }
  out
}

///|
/// Whether the side to move has any legal move.
pub fn Chess::has_legal_move(self : Chess) -> Bool {
  self.legal_moves_raw().length() > 0
}

///|
/// Whether the side to move is checkmated.
pub fn Chess::is_checkmate(self : Chess) -> Bool {
  self.is_check() && self.legal_moves_raw().length() == 0
}

///|
/// Whether the side to move is stalemated.
pub fn Chess::is_stalemate(self : Chess) -> Bool {
  !self.is_check() && self.legal_moves_raw().length() == 0
}

///|
/// Whether the game is drawn (50-move rule, stalemate, material, repetition).
pub fn Chess::is_draw(self : Chess) -> Bool {
  self.half_moves >= 100 ||
  self.is_stalemate() ||
  self.is_insufficient_material() ||
  self.is_threefold_repetition()
}

///|
/// Whether the game is over (checkmate or draw).
pub fn Chess::is_game_over(self : Chess) -> Bool {
  self.is_checkmate() || self.is_draw()
}

///|
/// Play a move given as SAN (e.g. `Nf3`, `exd5`, `e8=Q+`).
pub fn Chess::move_by_san(self : Chess, san : String) -> Move? {
  for m in self.moves() {
    if m.san == san {
      self.make_move(m)
      return Some(m)
    }
  }
  None
}

///|
/// Play a move given source/target squares and an optional promotion piece.
pub fn Chess::play(
  self : Chess,
  from : String,
  to : String,
  promotion : PieceType?,
) -> Move? {
  match (parse_square(from), parse_square(to)) {
    (Some(fs), Some(ts)) => {
      for m in self.moves() {
        if m.from == fs && m.to == ts {
          let matches = match (promotion, m.promotion) {
            (Some(p), Some(q)) => p == q
            (None, None) => true
            _ => false
          }
          if matches {
            self.make_move(m)
            return Some(m)
          }
        }
      }
      None
    }
    _ => None
  }
}

///|
/// The promotion piece for a pawn move from `from` to `to` (a queen here).
pub fn Chess::promotion_piece(
  self : Chess,
  from : Square,
  to : Square,
) -> PieceType? {
  match self.board[from] {
    Some(p) =>
      if p.kind == Pawn && (rank_of(to) == 7 || rank_of(to) == 0) {
        Some(Queen)
      } else {
        None
      }
    None => None
  }
}

///|
/// Undo the most recent move.
pub fn Chess::undo(self : Chess) -> Move? {
  self.undo_move()
}
