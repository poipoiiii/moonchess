/// White-box tests for move generation, FEN, and game status.
///
/// These tests live in the same package as the implementation so they can build
/// `Piece` values and reach internal helpers directly.

///|
/// Recursive perft using the SAN-generating move list (reference path).
fn perft_ref(game : Chess, depth : Int) -> Int {
  if depth == 0 {
    return 1
  }
  let moves = game.moves()
  if depth == 1 {
    return moves.length()
  }
  let mut nodes = 0
  for m in moves {
    game.make_move(m)
    nodes = nodes + perft_ref(game, depth - 1)
    ignore(game.undo_move())
  }
  nodes
}

///|
test "start position fen round-trips" {
  let game = Chess::new()
  assert_eq(game.fen(), start_fen)
}

///|
test "twenty legal moves at the start" {
  let game = Chess::new()
  assert_eq(game.moves().length(), 20)
}

///|
test "perft from the start position" {
  let game = Chess::new()
  assert_eq(game.perft(1), 20)
  assert_eq(game.perft(2), 400)
  assert_eq(game.perft(3), 8902)
  assert_eq(game.perft(4), 197281)
}

///|
test "kiwipete perft" {
  let game = Chess::from_fen(
    "r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1",
  ).unwrap()
  assert_eq(game.perft(1), 48)
  assert_eq(game.perft(2), 2039)
  assert_eq(game.perft(3), 97862)
}

///|
test "fast and SAN move generators agree" {
  let game = Chess::new()
  for depth = 1; depth <= 3; depth = depth + 1 {
    assert_eq(game.perft(depth), perft_ref(game, depth))
  }
}

///|
test "basic SAN sequence" {
  let game = Chess::new()
  let m1 = game.move_by_san("e4").unwrap()
  assert_eq(m1.san, "e4")
  ignore(game.move_by_san("e5"))
  let m3 = game.move_by_san("Nf3").unwrap()
  assert_eq(m3.san, "Nf3")
  assert_eq(game.move_count(), 3)
}

///|
test "fool's mate is checkmate" {
  let game = Chess::new()
  ignore(game.move_by_san("f3"))
  ignore(game.move_by_san("e5"))
  ignore(game.move_by_san("g4"))
  let mate = game.move_by_san("Qh4#").unwrap()
  assert_eq(mate.san, "Qh4#")
  assert_true(game.is_check())
  assert_true(game.is_checkmate())
  assert_true(game.is_game_over())
}

///|
test "kingside castling moves the rook" {
  let game = Chess::from_fen("r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1").unwrap()
  let m = game.play("e1", "g1", None).unwrap()
  assert_eq(m.san, "O-O")
  assert_eq(game.get("g1"), Some({ kind: King, color: White, }))
  assert_eq(game.get("f1"), Some({ kind: Rook, color: White, }))
}

///|
test "queenside castling moves the rook" {
  let game = Chess::from_fen("r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1").unwrap()
  let m = game.play("e1", "c1", None).unwrap()
  assert_eq(m.san, "O-O-O")
  assert_eq(game.get("c1"), Some({ kind: King, color: White, }))
  assert_eq(game.get("d1"), Some({ kind: Rook, color: White, }))
}

///|
test "en passant captures the passing pawn" {
  let game = Chess::from_fen("4k3/8/8/3pP3/8/8/8/4K3 w - d6 0 1").unwrap()
  let m = game.play("e5", "d6", None).unwrap()
  assert_eq(m.san, "exd6")
  assert_eq(game.get("d5"), None)
  assert_eq(game.get("d6"), Some({ kind: Pawn, color: White, }))
}

///|
test "double pawn push records the en passant square" {
  let game = Chess::new()
  ignore(game.move_by_san("e4"))
  assert_true(game.fen().contains(" e3 "))
}

///|
test "promotion produces a queen" {
  let game = Chess::from_fen("4k3/P7/8/8/8/8/8/4K3 w - - 0 1").unwrap()
  let m = game.play("a7", "a8", Some(Queen)).unwrap()
  assert_eq(m.san, "a8=Q+")
  assert_eq(game.get("a8"), Some({ kind: Queen, color: White, }))
}

///|
test "undo restores the previous position" {
  let game = Chess::new()
  let before = game.fen()
  ignore(game.move_by_san("e4"))
  ignore(game.undo())
  assert_eq(game.fen(), before)
  assert_eq(game.move_count(), 0)
}

///|
test "kings only is insufficient material" {
  let game = Chess::from_fen("4k3/8/8/8/8/8/8/4K3 w - - 0 1").unwrap()
  assert_true(game.is_insufficient_material())
  assert_true(game.is_draw())
}

///|
test "square helpers round-trip" {
  for file = 0; file < 8; file = file + 1 {
    for rank = 0; rank < 8; rank = rank + 1 {
      let sq = make_square(file, rank)
      let name = square_name(sq)
      assert_eq(parse_square(name).unwrap(), sq)
    }
  }
}

///|
test "pgn round trip preserves the position" {
  let game = Chess::new()
  ignore(game.move_by_san("e4"))
  ignore(game.move_by_san("e5"))
  ignore(game.move_by_san("Nf3"))
  ignore(game.move_by_san("Nc6"))
  ignore(game.move_by_san("Bb5"))
  let text = game.pgn()
  let reloaded = Chess::new()
  assert_true(reloaded.load_pgn(text))
  assert_eq(reloaded.move_count(), 5)
  assert_eq(reloaded.fen(), game.fen())
}

///|
test "pgn parser skips comments variations and nags" {
  let pgn = "[Event \"Test\"]\n\n1. e4 {best by test} e5 (1... c5 2. Nf3) 2. Nf3 $1 Nc6 1/2-1/2\n"
  let game = Chess::new()
  assert_true(game.load_pgn(pgn))
  assert_eq(game.move_count(), 4)
  assert_eq(game.header("Event"), Some("Test"))
  assert_eq(game.header("Result"), Some("1/2-1/2"))
}

///|
test "pgn accepts inline move numbers" {
  let game = Chess::new()
  assert_true(game.load_pgn("1.e4 e5 2.Nf3 Nc6"))
  assert_eq(game.move_count(), 4)
}

///|
test "pgn accepts san without a check suffix" {
  let game = Chess::new()
  assert_true(game.load_pgn("1. f3 e5 2. g4 Qh4"))
  assert_true(game.is_checkmate())
}

///|
test "pgn emits the seven tag roster" {
  let game = Chess::new()
  ignore(game.move_by_san("d4"))
  let text = game.pgn()
  assert_true(text.contains("[Event "))
  assert_true(text.contains("[Result \"*\"]"))
  assert_true(text.contains("1. d4 *"))
}
