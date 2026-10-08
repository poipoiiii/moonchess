/// Browser chess demo driven from MoonBit.
///
/// The DOM lives in JS (see `ffi_js.mbt`); this module owns the game state,
/// applies moves, renders through the FFI, and lets the engine answer.
/// Interaction: click a piece of the side to move, then click a target square.

///|
/// Mutable application state.
struct App {
  game : @lib.Chess
  mut selected : Int
}

///|
let app : App = { game: @lib.Chess::new(), selected: -1, }

///|
/// Human-readable status line.
fn status_text(g : @lib.Chess) -> String {
  if g.is_checkmate() {
    "checkmate"
  } else if g.is_stalemate() {
    "stalemate"
  } else if g.is_draw() {
    "draw"
  } else {
    let side = if g.side_is_white() { "White" } else { "Black" }
    if g.is_check() {
      "\{side} to move — check"
    } else {
      "\{side} to move"
    }
  }
}

///|
/// Render the board and status through the FFI.
fn render() -> Unit {
  let g = app.game
  let mut cells = ""
  let mut rank = 7
  while rank >= 0 {
    let mut file = 0
    while file < 8 {
      match g.piece_on(@lib.make_square(file, rank)) {
        Some(p) => cells = cells + p.fen_char().to_string()
        None => cells = cells + "."
      }
      file = file + 1
    }
    rank = rank - 1
  }
  js_render(cells, status_text(g), app.selected)
}

///|
/// Let the engine play one move for the side to move.
fn engine_reply() -> Unit {
  let g = app.game
  if g.is_game_over() {
    render()
    return
  }
  let searcher = @lib.Searcher::new()
  let depth = js_engine_depth()
  match searcher.search(g, depth).best {
    Some(m) => g.make_move(m)
    None => ()
  }
  render()
}

///|
/// Handle a click on board cell `(row, col)` where row 0 is rank 8.
fn on_cell(row : Int, col : Int) -> Unit {
  let g = app.game
  if g.is_game_over() {
    return
  }
  let sq = @lib.make_square(col, 7 - row)
  match g.piece_on(sq) {
    Some(p) =>
      if p.is_white() == g.side_is_white() {
        app.selected = sq
        render()
        return
      }
    None => ()
  }
  if app.selected < 0 {
    return
  }
  let from = app.selected
  let promo = g.promotion_piece(from, sq)
  match g.play(@lib.square_name(from), @lib.square_name(sq), promo) {
    Some(_) => {
      app.selected = -1
      render()
      engine_reply()
    }
    None => {
      app.selected = -1
      render()
    }
  }
}

///|
/// Start a fresh game.
fn on_new_game() -> Unit {
  app.game.reset()
  app.selected = -1
  render()
}

///|
/// Undo the last full move (the player's move and the engine's reply).
fn on_undo() -> Unit {
  let g = app.game
  ignore(g.undo())
  ignore(g.undo())
  app.selected = -1
  render()
}

///|
fn main {
  js_dom_init()
  js_set_on_cell(on_cell)
  js_set_on_new(on_new_game)
  js_set_on_undo(on_undo)
  js_bind_buttons()
  render()
}
