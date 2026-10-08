/// A small chess engine: static evaluation, negamax with alpha-beta pruning,
/// quiescence search, and a root search that returns the best move.

///|
/// Value of each piece kind in centipawns.
pub fn material_value(kind : PieceType) -> Int {
  match kind {
    Pawn => 100
    Knight => 320
    Bishop => 330
    Rook => 500
    Queen => 900
    King => 20000
  }
}

///|
/// Score used for a checkmate in `negamax`.
let mate_score : Int = 1_000_000

///|
/// A large "infinity" bound.
let infinity : Int = 1_000_000_000

///|
/// Pawn piece-square table (from rank 8 down to rank 1).
let pawn_table : Array[Int] = [
  0, 0, 0, 0, 0, 0, 0, 0, 50, 50, 50, 50, 50, 50, 50, 50, 10, 10, 20, 30, 30, 20,
  10, 10, 5, 5, 10, 25, 25, 10, 5, 5, 0, 0, 0, 20, 20, 0, 0, 0, 5, -5, -10, 0, 0,
  -10, -5, 5, 5, 10, 10, -20, -20, 10, 10, 5, 0, 0, 0, 0, 0, 0, 0, 0,
]

///|
/// Knight piece-square table.
let knight_table : Array[Int] = [
  -50, -40, -30, -30, -30, -30, -40, -50, -40, -20, 0, 0, 0, 0, -20, -40, -30, 0,
  10, 15, 15, 10, 0, -30, -30, 5, 15, 20, 20, 15, 5, -30, -30, 0, 15, 20, 20, 15,
  0, -30, -30, 5, 10, 15, 15, 10, 5, -30, -40, -20, 0, 5, 5, 0, -20, -40, -50, -40,
  -30, -30, -30, -30, -40, -50,
]

///|
/// Bishop piece-square table.
let bishop_table : Array[Int] = [
  -20, -10, -10, -10, -10, -10, -10, -20, -10, 0, 0, 0, 0, 0, 0, -10, -10, 0, 5,
  10, 10, 5, 0, -10, -10, 5, 5, 10, 10, 5, 5, -10, -10, 0, 10, 10, 10, 10, 0, -10,
  -10, 10, 10, 10, 10, 10, 10, -10, -10, 5, 0, 0, 0, 0, 5, -10, -20, -10, -10, -10,
  -10, -10, -10, -20,
]

///|
/// Rook piece-square table.
let rook_table : Array[Int] = [
  0, 0, 0, 0, 0, 0, 0, 0, 5, 10, 10, 10, 10, 10, 10, 5, -5, 0, 0, 0, 0, 0, 0, -5,
  -5, 0, 0, 0, 0, 0, 0, -5, -5, 0, 0, 0, 0, 0, 0, -5, -5, 0, 0, 0, 0, 0, 0, -5, -5,
  0, 0, 0, 0, 0, 0, -5, 0, 0, 5, 5, 0, 0, 0, 0,
]

///|
/// Queen piece-square table.
let queen_table : Array[Int] = [
  -20, -10, -10, -5, -5, -10, -10, -20, -10, 0, 0, 0, 0, 0, 0, -10, -10, 0, 5, 5,
  5, 5, 0, -10, -5, 0, 5, 5, 5, 5, 0, -5, 0, 0, 5, 5, 5, 5, 0, -5, -10, 5, 5, 5,
  5, 5, 0, -10, -10, 0, 5, 0, 0, 0, 0, -10, -20, -10, -10, -5, -5, -10, -10, -20,
]

///|
/// King piece-square table (middlegame).
let king_table : Array[Int] = [
  -30, -40, -40, -50, -50, -40, -40, -30, -30, -40, -40, -50, -50, -40, -40, -30,
  -30, -40, -40, -50, -50, -40, -40, -30, -30, -40, -40, -50, -50, -40, -40, -30,
  -20, -30, -30, -40, -40, -30, -30, -20, -10, -20, -20, -20, -20, -20, -20, -10,
  20, 20, 0, 0, 0, 0, 20, 20, 20, 30, 10, 0, 0, 10, 30, 20,
]

///|
/// Piece-square bonus for a piece of `color` on `sq`.
fn pst(kind : PieceType, color : Color, sq : Square) -> Int {
  let file = file_of(sq)
  let rank = rank_of(sq)
  let index = if color == White {
    (7 - rank) * 8 + file
  } else {
    rank * 8 + file
  }
  match kind {
    Pawn => pawn_table[index]
    Knight => knight_table[index]
    Bishop => bishop_table[index]
    Rook => rook_table[index]
    Queen => queen_table[index]
    King => king_table[index]
  }
}

///|
/// Static evaluation in centipawns, from White's point of view.
pub fn Chess::evaluate(self : Chess) -> Int {
  let mut score = 0
  let mut sq = 0
  while sq < 128 {
    if on_board(sq) {
      match self.board[sq] {
        Some(p) => {
          let v = material_value(p.kind) + pst(p.kind, p.color, sq)
          if p.color == White {
            score = score + v
          } else {
            score = score - v
          }
        }
        None => ()
      }
    }
    sq = sq + 1
  }
  score
}

///|
/// Heuristic ordering score for a move (higher is tried first).
fn move_score(m : Move) -> Int {
  let mut score = 0
  match m.captured {
    Some(k) => score = score + material_value(k) * 10 - material_value(m.piece)
    None => ()
  }
  match m.promotion {
    Some(k) => score = score + material_value(k)
    None => ()
  }
  score
}

///|
/// Return a copy of `moves` sorted by descending heuristic score.
fn order_moves(moves : Array[Move]) -> Array[Move] {
  let result = moves.copy()
  let n = result.length()
  let mut i = 1
  while i < n {
    let key = result[i]
    let key_score = move_score(key)
    let mut j = i - 1
    while j >= 0 && move_score(result[j]) < key_score {
      result[j + 1] = result[j]
      j = j - 1
    }
    result[j + 1] = key
    i = i + 1
  }
  result
}

///|
/// Static evaluation from the side-to-move point of view.
fn Chess::evaluate_relative(self : Chess) -> Int {
  let score = self.evaluate()
  if self.turn == White {
    score
  } else {
    -score
  }
}

///|
/// Quiescence search: extend only capture moves to avoid the horizon effect.
fn Chess::quiesce(self : Chess, alpha : Int, beta : Int) -> Int {
  let stand = self.evaluate_relative()
  if stand >= beta {
    return beta
  }
  let mut a = if stand > alpha { stand } else { alpha }
  let captures = self.legal_moves_raw().filter(fn(m) { m.captured is Some(_) })
  for m in order_moves(captures) {
    self.make_move(m)
    let score = -self.quiesce(-beta, -a)
    ignore(self.undo_move())
    if score >= beta {
      return beta
    }
    if score > a {
      a = score
    }
  }
  a
}

///|
/// Negamax with alpha-beta pruning. Returns a score from the side-to-move POV.
fn Chess::negamax(
  self : Chess,
  depth : Int,
  alpha : Int,
  beta : Int,
  ply : Int,
) -> Int {
  let moves = self.legal_moves_raw()
  if moves.length() == 0 {
    if self.is_check() {
      return -mate_score + ply
    }
    return 0
  }
  if depth == 0 {
    return self.quiesce(alpha, beta)
  }
  let mut a = alpha
  for m in order_moves(moves) {
    self.make_move(m)
    let score = -self.negamax(depth - 1, -beta, -a, ply + 1)
    ignore(self.undo_move())
    if score >= beta {
      return beta
    }
    if score > a {
      a = score
    }
  }
  a
}

///|
/// Search to `depth` plies and return the best move, or `None` if the game is over.
pub fn Chess::best_move(self : Chess, depth : Int) -> Move? {
  let moves = self.moves()
  if moves.length() == 0 {
    return None
  }
  let mut best : Move? = None
  let mut best_score = -infinity
  let mut alpha = -infinity
  for m in order_moves(moves) {
    self.make_move(m)
    let score = -self.negamax(depth - 1, -infinity, -alpha, 1)
    ignore(self.undo_move())
    if score > best_score {
      best_score = score
      best = Some(m)
      if score > alpha {
        alpha = score
      }
    }
  }
  best
}

///|
/// Like `best_move`, but also returns the score from the mover's point of view.
pub fn Chess::best_move_scored(self : Chess, depth : Int) -> (Move?, Int) {
  let moves = self.moves()
  if moves.length() == 0 {
    return (None, 0)
  }
  let mut best : Move? = None
  let mut best_score = -infinity
  let mut alpha = -infinity
  for m in order_moves(moves) {
    self.make_move(m)
    let score = -self.negamax(depth - 1, -infinity, -alpha, 1)
    ignore(self.undo_move())
    if score > best_score {
      best_score = score
      best = Some(m)
      if score > alpha {
        alpha = score
      }
    }
  }
  (best, best_score)
}
