/// Command-line front end for the moonchess library.

///|
/// Parse a small non-negative integer, falling back on invalid input.
fn parse_int_arg(s : String, fallback : Int) -> Int {
  if s.length() == 0 {
    return fallback
  }
  let mut value = 0
  for ch in s {
    let d = ch.to_int() - '0'.to_int()
    if d < 0 || d > 9 {
      return fallback
    }
    value = value * 10 + d
  }
  value
}

///|
/// Build a game from the optional FEN argument at `index`.
fn game_from(args : Array[String], index : Int) -> @lib.Chess {
  if args.length() > index {
    match @lib.Chess::from_fen(args[index]) {
      Some(game) => game
      None => {
        println("invalid FEN, falling back to the start position")
        @lib.Chess::new()
      }
    }
  } else {
    @lib.Chess::new()
  }
}

///|
/// Play a self-play game, printing one SAN move per line.
fn selfplay(depth : Int, max_plies : Int) -> Unit {
  let game = @lib.Chess::new()
  let mut played = 0
  while played < max_plies && !game.is_game_over() {
    match game.best_move(depth) {
      Some(m) => {
        println(m.san)
        game.make_move(m)
        played = played + 1
      }
      None => break
    }
  }
  println("---")
  println(game.fen())
  if game.is_checkmate() {
    println("checkmate")
  } else if game.is_stalemate() {
    println("stalemate")
  } else if game.is_draw() {
    println("draw")
  } else {
    println("stopped after \{played} plies")
  }
}

///|
/// Print usage information.
fn usage() -> Unit {
  println("moonchess - a chess library and engine for MoonBit")
  println("")
  println("Usage:")
  println(
    "  moonchess perft <depth>             perft node count from the start",
  )
  println(
    "  moonchess best <depth> [fen]        best move for the side to move",
  )
  println(
    "  moonchess think <depth> [fen]       iterative-deepening search with a TT",
  )
  println("  moonchess selfplay <depth> [plies]  print a self-play game in SAN")
  println("  moonchess fen [fen]                 validate and echo a FEN")
}

///|
fn main {
  let args = @env.args()
  if args.length() < 2 {
    usage()
    return
  }
  match args[1] {
    "perft" => {
      let depth = if args.length() > 2 { parse_int_arg(args[2], 3) } else { 3 }
      let game = @lib.Chess::new()
      println("perft(\{depth}) = \{game.perft(depth)}")
    }
    "best" => {
      let depth = if args.length() > 2 { parse_int_arg(args[2], 3) } else { 3 }
      let game = game_from(args, 3)
      let (best, score) = game.best_move_scored(depth)
      match best {
        Some(m) =>
          println("best: \{m.san} (score \{score} cp at depth \{depth})")
        None => println("no legal move (game over)")
      }
    }
    "think" => {
      let depth = if args.length() > 2 { parse_int_arg(args[2], 4) } else { 4 }
      let game = game_from(args, 3)
      let searcher = @lib.Searcher::new()
      let result = searcher.search(game, depth)
      match result.best {
        Some(m) =>
          println(
            "best: \{m.san} (score \{result.score} cp, depth \{result.depth}, nodes \{result.nodes})",
          )
        None => println("no legal move (game over)")
      }
    }
    "selfplay" => {
      let depth = if args.length() > 2 { parse_int_arg(args[2], 3) } else { 3 }
      let plies = if args.length() > 3 {
        parse_int_arg(args[3], 40)
      } else {
        40
      }
      selfplay(depth, plies)
    }
    "fen" => {
      let game = game_from(args, 2)
      println(game.fen())
    }
    _ => usage()
  }
}
