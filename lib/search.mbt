/// Zobrist hashing and a transposition-table search with iterative deepening.

///|
/// splitmix64 step: advances the state and returns a pseudo-random value.
fn splitmix64(state : UInt64) -> (UInt64, UInt64) {
  let next = state + 0x9E3779B97F4A7C15UL
  let mut x = next
  x = (x ^ (x >> 30)) * 0xBF58476D1CE4E5B9UL
  x = (x ^ (x >> 27)) * 0x94D049BB133111EBUL
  x = x ^ (x >> 31)
  (next, x)
}

///|
/// Fill `count` deterministic pseudo-random keys starting from `state`.
fn make_keys(count : Int, state : UInt64) -> Array[UInt64] {
  let out : Array[UInt64] = []
  let mut s = state
  let mut i = 0
  while i < count {
    let (next, value) = splitmix64(s)
    s = next
    out.push(value)
    i = i + 1
  }
  out
}

///|
/// Keys indexed by `(kind * 2 + color) * 128 + square`.
let zobrist_pieces : Array[UInt64] = make_keys(1536, 0x123456789ABCDEFUL)

///|
/// Key XOR-ed in when black is to move.
let zobrist_turn : UInt64 = splitmix64(0xDEADBEEF12345678UL).1

///|
/// Keys indexed by the 4-bit castling-rights mask.
let zobrist_castling : Array[UInt64] = make_keys(16, 0xFEDCBA9876543210UL)

///|
/// Keys indexed by the en-passant file.
let zobrist_ep_file : Array[UInt64] = make_keys(8, 0x0F1E2D3C4B5A6978UL)

///|
/// A 64-bit Zobrist hash of the current position.
pub fn Chess::hash(self : Chess) -> UInt64 {
  let mut h : UInt64 = 0UL
  let mut sq = 0
  while sq < 128 {
    if on_board(sq) {
      match self.board[sq] {
        Some(p) =>
          h = h ^
            zobrist_pieces[(p.kind.index() * 2 + p.color.index()) * 128 + sq]
        None => ()
      }
    }
    sq = sq + 1
  }
  if self.turn == Black {
    h = h ^ zobrist_turn
  }
  h = h ^ zobrist_castling[self.castling & 15]
  match self.ep {
    Some(sq) => h = h ^ zobrist_ep_file[file_of(sq)]
    None => ()
  }
  h
}

///|
/// Number of transposition-table slots (a power of two).
let tt_bits : Int = 16

///|
let tt_size : Int = 1 << tt_bits

///|
let tt_size_u : UInt64 = 65536UL

///|
/// Bound type stored in a transposition-table entry.
let flag_exact : Int = 0

///|
let flag_lower : Int = 1

///|
let flag_upper : Int = 2

///|
/// One transposition-table slot.
struct TTEntry {
  key : UInt64
  depth : Int
  score : Int
  flag : Int
  best_from : Int
}

///|
/// A search engine with a transposition table.
pub struct Searcher {
  tt : Array[TTEntry]
  mut nodes : Int
}

///|
/// Result of a search.
pub struct SearchResult {
  best : Move?
  score : Int
  depth : Int
  nodes : Int
}

///|
/// Create a searcher with an empty transposition table.
pub fn Searcher::new() -> Searcher {
  let empty : TTEntry = {
    key: 0UL,
    depth: 0,
    score: 0,
    flag: flag_exact,
    best_from: -1,
  }
  { tt: Array::make(tt_size, empty), nodes: 0, }
}

///|
/// Order moves, prioritising the transposition-table move and captures.
fn order_moves_tt(moves : Array[Move], tt_from : Int) -> Array[Move] {
  let result = moves.copy()
  let n = result.length()
  let mut i = 1
  while i < n {
    let key = result[i]
    let key_score = move_score(key) +
      (if key.from == tt_from { 100000 } else { 0 })
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
/// Probe the transposition table, returning `(hit, entry)`.
fn Searcher::probe(self : Searcher, key : UInt64) -> TTEntry? {
  let entry = self.tt[(key % tt_size_u).to_int()]
  if entry.key == key && entry.depth > 0 {
    Some(entry)
  } else {
    None
  }
}

///|
/// Store an entry in the transposition table.
fn Searcher::store(
  self : Searcher,
  key : UInt64,
  depth : Int,
  score : Int,
  flag : Int,
  best_from : Int,
) -> Unit {
  let index = (key % tt_size_u).to_int()
  self.tt[index] = { key, depth, score, flag, best_from, }
}

///|
/// Negamax with alpha-beta pruning and transposition-table cutoffs.
fn Searcher::negamax(
  self : Searcher,
  game : Chess,
  depth : Int,
  alpha : Int,
  beta : Int,
  ply : Int,
) -> Int {
  self.nodes = self.nodes + 1
  let moves = game.legal_moves_raw()
  if moves.length() == 0 {
    if game.is_check() {
      return -mate_score + ply
    }
    return 0
  }
  if depth == 0 {
    return game.quiesce(alpha, beta)
  }
  let key = game.hash()
  let mut alpha = alpha
  let mut beta = beta
  let mut tt_from = -1
  match self.probe(key) {
    Some(entry) => {
      tt_from = entry.best_from
      if entry.depth >= depth {
        if entry.flag == flag_exact {
          return entry.score
        } else if entry.flag == flag_lower && entry.score > alpha {
          alpha = entry.score
        } else if entry.flag == flag_upper && entry.score < beta {
          beta = entry.score
        }
        if alpha >= beta {
          return entry.score
        }
      }
    }
    None => ()
  }
  let original_alpha = alpha
  let mut best = -infinity
  let mut best_from = -1
  for m in order_moves_tt(moves, tt_from) {
    game.make_move(m)
    let score = -self.negamax(game, depth - 1, -beta, -alpha, ply + 1)
    ignore(game.undo_move())
    if score > best {
      best = score
      best_from = m.from
    }
    if score > alpha {
      alpha = score
    }
    if alpha >= beta {
      break
    }
  }
  let flag = if best <= original_alpha {
    flag_upper
  } else if best >= beta {
    flag_lower
  } else {
    flag_exact
  }
  self.store(key, depth, best, flag, best_from)
  best
}

///|
/// Current time in milliseconds.
fn now_ms() -> Int {
  @env.now().to_int()
}

///|
/// Whether the optional deadline has passed.
fn timer_expired(deadline : Int?) -> Bool {
  match deadline {
    Some(d) => now_ms() >= d
    None => false
  }
}

///|
/// Shared iterative-deepening driver with an optional deadline.
fn Searcher::iterative(
  self : Searcher,
  game : Chess,
  max_depth : Int,
  deadline : Int?,
) -> SearchResult {
  let root_moves = game.moves()
  if root_moves.length() == 0 {
    return { best: None, score: 0, depth: 0, nodes: self.nodes, }
  }
  let mut best : Move? = None
  let mut best_score = 0
  let mut reached = 0
  let mut stop = false
  let mut depth = 1
  while depth <= max_depth && !stop {
    let tt_from = match best {
      Some(m) => m.from
      None => -1
    }
    let mut local_best = root_moves[0]
    let mut local_score = -infinity
    let mut alpha = -infinity
    let mut aborted = false
    for m in order_moves_tt(root_moves, tt_from) {
      if timer_expired(deadline) {
        aborted = true
        break
      }
      game.make_move(m)
      let score = -self.negamax(game, depth - 1, -infinity, -alpha, 1)
      ignore(game.undo_move())
      if score > local_score {
        local_score = score
        local_best = m
        if score > alpha {
          alpha = score
        }
      }
    }
    if aborted {
      stop = true
    } else {
      best = Some(local_best)
      best_score = local_score
      reached = depth
      if best_score > mate_score - 1000 || best_score < -(mate_score - 1000) {
        stop = true
      }
    }
    depth = depth + 1
  }
  { best, score: best_score, depth: reached, nodes: self.nodes, }
}

///|
/// Iterative-deepening root search up to `max_depth`.
pub fn Searcher::search(
  self : Searcher,
  game : Chess,
  max_depth : Int,
) -> SearchResult {
  self.iterative(game, max_depth, None)
}

///|
/// Iterative-deepening search bounded by a time budget in milliseconds.
pub fn Searcher::search_timed(
  self : Searcher,
  game : Chess,
  max_depth : Int,
  time_ms : Int,
) -> SearchResult {
  self.iterative(game, max_depth, Some(now_ms() + time_ms))
}
