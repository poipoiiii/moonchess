/// A small opening book keyed by the SAN history.
///
/// The book is stored as a list of common opening *lines* (sequences of SAN
/// moves). To choose a move, the current game history is matched against line
/// prefixes and the first legal continuation is played.

///|
/// Common opening lines (SAN). Kept intentionally small but varied.
let opening_lines : Array[Array[String]] = [
  ["e4", "e5", "Nf3", "Nc6", "Bb5", "a6"],
  ["e4", "e5", "Nf3", "Nc6", "Bc4", "Bc5"],
  ["e4", "e5", "Nf3", "Nf6"],
  ["e4", "e5", "Nc3", "Nf6"],
  ["e4", "c5", "Nf3", "d6", "d4", "cxd4"],
  ["e4", "e6", "d4", "d5"],
  ["e4", "c6", "d4", "d5"],
  ["e4", "d5", "exd5", "Qxd5"],
  ["e4", "Nf6", "e5", "Nd5"],
  ["d4", "d5", "c4", "e6"],
  ["d4", "d5", "c4", "c6"],
  ["d4", "Nf6", "c4", "g6", "Nc3", "Bg7"],
  ["d4", "Nf6", "c4", "e6", "Nc3", "Bb4"],
  ["c4", "e5", "Nc3", "Nf6"],
  ["Nf3", "d5", "d4", "Nf6"],
]

///|
/// Play a book move for the current position, if one is known.
///
/// Returns the applied move, or `None` when the history is not in the book or
/// no book continuation is legal here.
pub fn Chess::book_move(self : Chess) -> Move? {
  let played : Array[String] = self.history().map(fn(m) { m.san })
  let candidates : Array[String] = []
  for line in opening_lines {
    if line.length() > played.length() {
      let mut matches = true
      let mut i = 0
      while i < played.length() {
        if line[i] != played[i] {
          matches = false
          break
        }
        i = i + 1
      }
      if matches {
        candidates.push(line[played.length()])
      }
    }
  }
  for candidate in candidates {
    if self.move_by_san(candidate) is Some(m) {
      return Some(m)
    }
  }
  None
}

///|
/// Number of opening lines in the book.
pub fn book_size() -> Int {
  opening_lines.length()
}
