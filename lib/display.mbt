/// Human-readable board rendering.

///|
/// Unicode symbol for a piece.
fn piece_symbol(p : Piece) -> String {
  match (p.color, p.kind) {
    (White, King) => "♔"
    (White, Queen) => "♕"
    (White, Rook) => "♖"
    (White, Bishop) => "♗"
    (White, Knight) => "♘"
    (White, Pawn) => "♙"
    (Black, King) => "♚"
    (Black, Queen) => "♛"
    (Black, Rook) => "♜"
    (Black, Bishop) => "♝"
    (Black, Knight) => "♞"
    (Black, Pawn) => "♟"
  }
}

///|
/// ASCII letter for a piece: upper case for white, lower case for black.
fn piece_letter(p : Piece) -> String {
  let c = p.kind.to_char()
  if p.color == White {
    c.to_ascii_uppercase().to_string()
  } else {
    c.to_string()
  }
}

///|
/// Render the board as text. When `unicode` is true, chess symbols are used;
/// otherwise plain letters (`KQRBNP` / `kqrbnp`) are printed.
pub fn Chess::display(self : Chess, unicode? : Bool = true) -> String {
  let mut out = ""
  let mut rank = 7
  while rank >= 0 {
    out = out + "\{rank + 1} "
    let mut file = 0
    while file < 8 {
      match self.board[make_square(file, rank)] {
        Some(p) =>
          if unicode {
            out = out + piece_symbol(p) + " "
          } else {
            out = out + piece_letter(p) + " "
          }
        None => out = out + ". "
      }
      file = file + 1
    }
    out = out + "\n"
    rank = rank - 1
  }
  out + "  a b c d e f g h\n"
}
