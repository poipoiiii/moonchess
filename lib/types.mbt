/// Core value types for the MoonBit chess library.
///
/// The public surface intentionally mirrors the TypeScript `chess.js` API so
/// that users coming from that ecosystem can map concepts one-to-one, while the
/// implementation is written from scratch in idiomatic MoonBit.

///|
/// Board square index in 0x88 form (see `square.mbt`).
pub type Square = Int

///|
/// Side to move and piece color.
pub enum Color {
  White
  Black
} derive(Eq, Debug)

///|
/// The opposite color.
pub fn Color::opponent(self : Color) -> Color {
  match self {
    White => Black
    Black => White
  }
}

///|
/// `'w'` or `'b'`.
pub fn Color::to_char(self : Color) -> Char {
  match self {
    White => 'w'
    Black => 'b'
  }
}

///|
/// `0` for white, `1` for black.
pub fn Color::index(self : Color) -> Int {
  match self {
    White => 0
    Black => 1
  }
}

///|
/// Piece kinds.
pub enum PieceType {
  Pawn
  Knight
  Bishop
  Rook
  Queen
  King
} derive(Eq, Debug)

///|
/// Lower-case FEN letter for the piece kind.
pub fn PieceType::to_char(self : PieceType) -> Char {
  match self {
    Pawn => 'p'
    Knight => 'n'
    Bishop => 'b'
    Rook => 'r'
    Queen => 'q'
    King => 'k'
  }
}

///|
/// Parse a piece kind from a FEN letter (case-insensitive).
pub fn PieceType::from_char(c : Char) -> PieceType? {
  match c {
    'p' | 'P' => Some(Pawn)
    'n' | 'N' => Some(Knight)
    'b' | 'B' => Some(Bishop)
    'r' | 'R' => Some(Rook)
    'q' | 'Q' => Some(Queen)
    'k' | 'K' => Some(King)
    _ => None
  }
}

///|
/// A colored piece.
pub struct Piece {
  kind : PieceType
  color : Color
} derive(Eq, Debug)

///|
/// Construct a piece.
pub fn Piece::new(kind : PieceType, color : Color) -> Piece {
  { kind, color, }
}

///|
/// Castling-rights bit flags.
pub let castle_white_king : Int = 1

///|
pub let castle_white_queen : Int = 2

///|
pub let castle_black_king : Int = 4

///|
pub let castle_black_queen : Int = 8

///|
/// A fully described chess move.
///
/// `flags` follows the chess.js convention:
/// - `n` normal
/// - `b` big pawn (double advance)
/// - `e` en passant capture
/// - `c` standard capture
/// - `p` promotion
/// - `k` kingside castling
/// - `q` queenside castling
pub struct Move {
  color : Color
  from : Square
  to : Square
  piece : PieceType
  promotion : PieceType?
  captured : PieceType?
  flags : String
  san : String
}
