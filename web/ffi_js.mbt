/// Browser FFI for the JS target. The DOM lives entirely in JS; MoonBit only
/// passes primitives and callbacks across the boundary.

///|
/// Build the 8x8 board grid, wiring each cell's click to `onCellClick`.
pub extern "js" fn js_dom_init() -> Unit =
  #| function() {
  #|   const g = (globalThis.__mc = globalThis.__mc || {});
  #|   const board = document.getElementById('board');
  #|   board.innerHTML = '';
  #|   board.style.display = 'grid';
  #|   board.style.gridTemplateColumns = 'repeat(8, 60px)';
  #|   board.style.width = 'max-content';
  #|   board.style.border = '2px solid #333';
  #|   for (let rr = 0; rr < 8; rr++) {
  #|     for (let cc = 0; cc < 8; cc++) {
  #|       const d = document.createElement('div');
  #|       d.style.width = '60px';
  #|       d.style.height = '60px';
  #|       d.style.display = 'flex';
  #|       d.style.alignItems = 'center';
  #|       d.style.justifyContent = 'center';
  #|       d.style.fontSize = '40px';
  #|       d.style.cursor = 'pointer';
  #|       d.style.boxSizing = 'border-box';
  #|       d.style.background = ((rr + cc) % 2 === 0) ? '#f0d9b5' : '#b58863';
  #|       d.addEventListener('click', () => { if (g.onCellClick) g.onCellClick(rr, cc); });
  #|       board.appendChild(d);
  #|     }
  #|   }
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
/// Render 64 board cells (row-major from rank 8), the status line and the
/// currently selected square (0x88 index, or -1).
pub extern "js" fn js_render(
  cells : String,
  status : String,
  selected : Int,
) -> Unit =
  #| function(cells, status, selected) {
  #|   const sym = { K:'♔', Q:'♕', R:'♖', B:'♗', N:'♘', P:'♙',
  #|                 k:'♚', q:'♛', r:'♜', b:'♝', n:'♞', p:'♟' };
  #|   const board = document.getElementById('board');
  #|   const selRow = selected >= 0 ? 7 - (selected >> 4) : -1;
  #|   const selCol = selected >= 0 ? (selected & 7) : -1;
  #|   const selIndex = selRow * 8 + selCol;
  #|   for (let i = 0; i < 64; i++) {
  #|     const el = board.children[i];
  #|     el.textContent = sym[cells[i]] || '';
  #|     el.style.outline = (i === selIndex) ? '3px solid #d33' : 'none';
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
