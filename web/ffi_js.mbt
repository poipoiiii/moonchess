/// Browser FFI for the JS target. The DOM lives entirely in JS; MoonBit only
/// passes primitives and callbacks across the boundary.
///
/// The board is a grid of 64 background squares; pieces live on an absolutely
/// positioned layer above it so their `transform` can be animated when they
/// move.

///|
/// Build the 8x8 board grid (each cell holds an empty marker element) and clear
/// the piece layer.
pub extern "js" fn js_dom_init() -> Unit =
  #| function() {
  #|   const g = (globalThis.__mc = globalThis.__mc || {});
  #|   const board = document.getElementById('board');
  #|   board.innerHTML = '';
  #|   for (let rr = 0; rr < 8; rr++) {
  #|     for (let cc = 0; cc < 8; cc++) {
  #|       const d = document.createElement('div');
  #|       d.style.background = ((rr + cc) % 2 === 0) ? '#f0d9b5' : '#b58863';
  #|       d.addEventListener('click', () => { if (g.onCellClick) g.onCellClick(rr, cc); });
  #|       const mark = document.createElement('div');
  #|       mark.className = 'mark';
  #|       d.appendChild(mark);
  #|       board.appendChild(d);
  #|     }
  #|   }
  #|   const layer = document.getElementById('pieces');
  #|   if (layer) layer.innerHTML = '';
  #| }

///|
/// Register the cell-click callback.
pub extern "js" fn js_set_on_cell(cb : (Int, Int) -> Unit) -> Unit =
  #| function(cb) { (globalThis.__mc = globalThis.__mc || {}).onCellClick = cb; }

///|
/// Register the "new game" callback.
pub extern "js" fn js_set_on_new(cb : () -> Unit) -> Unit =
  #| function(cb) { (globalThis.__mc = globalThis.__mc || {}).onNewGame = cb; }

///|
/// Register the "undo" callback.
pub extern "js" fn js_set_on_undo(cb : () -> Unit) -> Unit =
  #| function(cb) { (globalThis.__mc = globalThis.__mc || {}).onUndo = cb; }

///|
/// Wire the toolbar buttons to the registered callbacks.
pub extern "js" fn js_bind_buttons() -> Unit =
  #| function() {
  #|   const g = globalThis.__mc;
  #|   const n = document.getElementById('newGame');
  #|   const u = document.getElementById('undo');
  #|   if (n) n.addEventListener('click', () => { if (g.onNewGame) g.onNewGame(); });
  #|   if (u) u.addEventListener('click', () => { if (g.onUndo) g.onUndo(); });
  #| }

///|
/// Render the position.
///
/// * `cells`    - 64 chars, row-major from rank 8 ('.' = empty).
/// * `status`   - status line text.
/// * `selected` - selected square (0x88), or -1.
/// * `targets`  - comma-separated destination squares (0x88) for the selection.
/// * `from`/`to`- the last move (0x88), or -1.
/// * `animate`  - slide the moved piece from `from` to `to` when true.
pub extern "js" fn js_render(
  cells : String,
  status : String,
  selected : Int,
  targets : String,
  from : Int,
  to : Int,
  animate : Bool,
) -> Unit =
  #| function(cells, status, selected, targets, from, to, animate) {
  #|   const CELL = 60;
  #|   const sym = { K:'♔', Q:'♕', R:'♖', B:'♗', N:'♘', P:'♙',
  #|                 k:'♚', q:'♛', r:'♜', b:'♝', n:'♞', p:'♟' };
  #|   const board = document.getElementById('board');
  #|   const sqOf = (i) => { const r = (i / 8) | 0; const c = i % 8; return (7 - r) * 16 + c; };
  #|   const targetSet = {};
  #|   if (targets) { targets.split(',').forEach((t) => { if (t) targetSet[parseInt(t, 10)] = true; }); }
  #|   for (let i = 0; i < 64; i++) {
  #|     let cls = 'mark';
  #|     const sq = sqOf(i);
  #|     if (sq === selected) cls += ' sel';
  #|     if (targetSet[sq]) cls += (cells[i] === '.') ? ' dot' : ' ring';
  #|     board.children[i].firstChild.className = cls;
  #|   }
  #|   const layer = document.getElementById('pieces');
  #|   const xOf = (sq) => (sq & 7) * CELL;
  #|   const yOf = (sq) => (7 - (sq >> 4)) * CELL;
  #|   layer.innerHTML = '';
  #|   const moved = (animate && to >= 0) ? to : -1;
  #|   for (let i = 0; i < 64; i++) {
  #|     const ch = cells[i];
  #|     if (ch === '.') continue;
  #|     const sq = sqOf(i);
  #|     const el = document.createElement('div');
  #|     el.className = 'p';
  #|     el.textContent = sym[ch] || '';
  #|     const start = (sq === moved && from >= 0) ? from : sq;
  #|     el.style.transform = 'translate(' + xOf(start) + 'px,' + yOf(start) + 'px)';
  #|     layer.appendChild(el);
  #|     if (sq === moved && from >= 0) {
  #|       void layer.offsetHeight; /* flush layout so the transition runs */
  #|       el.style.transition = 'transform .18s ease-out';
  #|       el.style.transform = 'translate(' + xOf(sq) + 'px,' + yOf(sq) + 'px)';
  #|     }
  #|   }
  #|   const s = document.getElementById('status');
  #|   if (s) s.textContent = status;
  #| }

///|
/// Read the engine strength selected in the toolbar.
pub extern "js" fn js_engine_depth() -> Int =
  #| function() {
  #|   const el = document.getElementById('depth');
  #|   const v = el ? parseInt(el.value, 10) : 3;
  #|   return isNaN(v) ? 3 : v;
  #| }

///|
/// Defer `cb` by `ms` milliseconds (used to let the move animation finish
/// before the engine replies).
pub extern "js" fn js_defer(cb : () -> Unit, ms : Int) -> Unit =
  #| function(cb, ms) { setTimeout(cb, ms); }
