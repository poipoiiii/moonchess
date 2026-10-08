/// Wasm stubs for the browser FFI: the web demo targets JS, so these are
/// no-ops when the package is compiled for wasm.

///|
pub fn js_dom_init() -> Unit {
  ()
}

///|
pub fn js_set_on_cell(cb : (Int, Int) -> Unit) -> Unit {
  ignore(cb)
}

///|
pub fn js_set_on_new(cb : () -> Unit) -> Unit {
  ignore(cb)
}

///|
pub fn js_set_on_undo(cb : () -> Unit) -> Unit {
  ignore(cb)
}

///|
pub fn js_bind_buttons() -> Unit {
  ()
}

///|
pub fn js_render(cells : String, status : String, selected : Int) -> Unit {
  ignore((cells, status, selected))
}

///|
pub fn js_engine_depth() -> Int {
  3
}
