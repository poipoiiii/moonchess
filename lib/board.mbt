/// Low-level 0x88 board storage and attack detection.
///
/// The board is a flat `Array[Piece?]` of length 128. Empty squares hold
/// `None`. All indexing uses the 0x88 scheme from `square.mbt`.

///|
/// Knight move offsets in 0x88.
pub let knight_offsets : Array[Int] = [-18, -33, -31, -14, 18, 33, 31, 14]

///|
/// Diagonal sliding offsets.
pub let bishop_offsets : Array[Int] = [-17, -15, 17, 15]

///|
/// Orthogonal sliding offsets.
pub let rook_offsets : Array[Int] = [-16, -1, 1, 16]

///|
/// King / single-step offsets.
pub let king_offsets : Array[Int] = [-17, -16, -15, -1, 1, 15, 16, 17]

///|
/// A fresh, empty board.
pub fn empty_board() -> Array[Piece?] {
  let board : Array[Piece?] = Array::make(128, None)
  board
}

///|
/// Shallow clone of a board (pieces are immutable values).
pub fn clone_board(board : Array[Piece?]) -> Array[Piece?] {
  board.copy()
}

///|
/// Piece on a square, if any.
pub fn piece_at(board : Array[Piece?], sq : Square) -> Piece? {
  if on_board(sq) {
    board[sq]
  } else {
    None
  }
}

///|
/// Place (or clear) a piece on a square.
pub fn set_piece(board : Array[Piece?], sq : Square, piece : Piece?) -> Unit {
  if on_board(sq) {
    board[sq] = piece
  }
}

///|
/// Whether a square holds a piece of the given kind and color.
pub fn has_piece(
  board : Array[Piece?],
  sq : Square,
  kind : PieceType,
  color : Color,
) -> Bool {
  if !on_board(sq) {
    return false
  }
  match board[sq] {
    Some(p) => p.kind == kind && p.color == color
    None => false
  }
}

///|
/// Whether a square holds a pawn of the given color.
pub fn has_pawn(board : Array[Piece?], sq : Square, color : Color) -> Bool {
  has_piece(board, sq, Pawn, color)
}

///|
/// Find the king square of a color, or `None` if absent.
pub fn king_square(board : Array[Piece?], color : Color) -> Square? {
  let mut sq = 0
  while sq < 128 {
    if on_board(sq) {
      match board[sq] {
        Some(p) => if p.kind == King && p.color == color { return Some(sq) }
        None => ()
      }
    }
    sq = sq + 1
  }
  None
}

///|
/// Whether `sq` is attacked by any piece of `by_color`.
pub fn is_attacked(
  board : Array[Piece?],
  sq : Square,
  by_color : Color,
) -> Bool {
  // Pawn attacks: a white pawn attacks upward, so it sits one rank below.
  match by_color {
    White =>
      if has_pawn(board, sq - 15, White) || has_pawn(board, sq - 17, White) {
        return true
      }
    Black =>
      if has_pawn(board, sq + 15, Black) || has_pawn(board, sq + 17, Black) {
        return true
      }
  }
  // Knight attacks.
  for i = 0; i < knight_offsets.length(); i = i + 1 {
    if has_piece(board, sq + knight_offsets[i], Knight, by_color) {
      return true
    }
  }
  // King attacks.
  for i = 0; i < king_offsets.length(); i = i + 1 {
    if has_piece(board, sq + king_offsets[i], King, by_color) {
      return true
    }
  }
  // Orthogonal sliders (rook / queen).
  for i = 0; i < rook_offsets.length(); i = i + 1 {
    let dir = rook_offsets[i]
    let mut target = sq + dir
    while on_board(target) {
      match board[target] {
        Some(p) => {
          if p.color == by_color && (p.kind == Rook || p.kind == Queen) {
            return true
          }
          break
        }
        None => target = target + dir
      }
    }
  }
  // Diagonal sliders (bishop / queen).
  for i = 0; i < bishop_offsets.length(); i = i + 1 {
    let dir = bishop_offsets[i]
    let mut target = sq + dir
    while on_board(target) {
      match board[target] {
        Some(p) => {
          if p.color == by_color && (p.kind == Bishop || p.kind == Queen) {
            return true
          }
          break
        }
        None => target = target + dir
      }
    }
  }
  false
}

///|
/// Whether `color`'s king is currently in check.
pub fn king_in_check(board : Array[Piece?], color : Color) -> Bool {
  match king_square(board, color) {
    Some(sq) => is_attacked(board, sq, color.opponent())
    None => false
  }
}
