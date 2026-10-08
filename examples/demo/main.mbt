/// Runnable demo for the moonchess library.
///
/// Run with: moon run examples/demo

///|
fn main {
  let game = @lib.Chess::new()
  println("=== Start position ===")
  println(game.display())
  // Play the Scholar's mate.
  for san in ["e4", "e5", "Bc4", "Nc6", "Qh5", "Nf6", "Qxf7#"] {
    match game.move_by_san(san) {
      Some(m) => println("played \{m.san}")
      None => println("illegal move: \{san}")
    }
  }
  println("")
  println("=== After 4. Qxf7# ===")
  println(game.display())
  println("checkmate = \{game.is_checkmate()}")
  println("")
  println("=== PGN ===")
  println(game.pgn())
  println("=== perft ===")
  let start = @lib.Chess::new()
  println("perft(3) from start = \{start.perft(3)}")
  println("")
  println("=== engine ===")
  match @lib.Chess::from_fen("6k1/5ppp/8/8/8/8/5PPP/R5K1 w - - 0 1") {
    Some(position) => {
      let searcher = @lib.Searcher::new()
      let result = searcher.search(position, 3)
      match result.best {
        Some(m) =>
          println(
            "mate in one: \{m.san} (score \{result.score}, nodes \{result.nodes})",
          )
        None => println("no legal move")
      }
    }
    None => println("invalid FEN")
  }
}
