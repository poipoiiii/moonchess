/// 0x88 board geometry helpers.
///
/// A square is encoded as `rank * 16 + file`, with both `file` and `rank` in
/// `0..7`. Because one nibble is "wasted", a square is on the board iff
/// `(sq & 0x88) == 0`, which turns off-board detection into a single bitwise
/// mask. This is the same trick used by `chess.js`.

///|
/// Build a 0x88 square from file and rank (both `0..7`).
pub fn make_square(file : Int, rank : Int) -> Square {
  rank * 16 + file
}

///|
/// File (column) of a square, `0` = `'a'`.
pub fn file_of(sq : Square) -> Int {
  sq & 0x7
}

///|
/// Rank (row) of a square, `0` = rank 1.
pub fn rank_of(sq : Square) -> Int {
  sq >> 4
}

///|
/// Whether the square index is on the board.
pub fn on_board(sq : Square) -> Bool {
  (sq & 0x88) == 0
}

///|
let file_chars : String = "abcdefgh"

///|
let rank_chars : String = "12345678"

///|
/// Algebraic name of a square, e.g. `e4`.
pub fn square_name(sq : Square) -> String {
  match (file_chars.get_char(file_of(sq)), rank_chars.get_char(rank_of(sq))) {
    (Some(f), Some(r)) => "\{f}\{r}"
    _ => "??"
  }
}

///|
/// Parse an algebraic square name such as `e4`, returning `None` if invalid.
pub fn parse_square(name : String) -> Square? {
  if name.char_length() != 2 {
    return None
  }
  let cs = name.to_array()
  let file = cs[0].to_int() - 'a'.to_int()
  let rank = cs[1].to_int() - '1'.to_int()
  if file < 0 || file > 7 || rank < 0 || rank > 7 {
    return None
  }
  Some(make_square(file, rank))
}
