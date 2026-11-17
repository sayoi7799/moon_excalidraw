// The entry point of the demo page: one function that turns the text of an
// .excalidraw file into JSON, so the page can call this library from JavaScript
// without sharing any MoonBit types.

///|
/// 7px per code point: the metric the test fixtures use, so the page can give
/// the official export the same one and compare the two byte for byte.
fn fixed_width(text : String, _font : String) -> Double {
  let mut n = 0
  for _ in text {
    n += 1
  }
  n.to_double() * 7.0
}

///|
fn failure(message : String) -> String {
  Json::object({ "ok": Json::boolean(false), "error": Json::string(message) })
  |> Json::stringify
}

///|
/// Renders `text`. `fonts` is "none" or "url". The result is a JSON string:
/// `{"ok":true,"svg":...,"warnings":[...]}` or `{"ok":false,"error":...}`.
pub fn render(text : String, fonts : String) -> String {
  let mode : @export.FontMode = if fonts == "url" { Url } else { None }
  let scene = @model.parse_scene(text) catch {
    err => return failure(err.to_string())
  }
  let result = @export.export_to_svg(
    scene,
    fonts=mode,
    measure_text=fixed_width,
  ) catch {
    err => return failure(err.to_string())
  }
  let warnings = result.warnings.map(fn(w) { Json::string(w.message) })
  Json::object({
    "ok": Json::boolean(true),
    "svg": Json::string(result.svg),
    "warnings": Json::array(warnings),
  })
  |> Json::stringify
}
