// Reads the JSON. Unknown fields are ignored and missing ones take their
// defaults in restore.mbt; a field of the wrong type is an error naming the
// element, so a damaged file doesn't render as something else.

///|
priv struct Fields {
  id : String
  map : Map[String, Json]
}

///|
fn Fields::bad(self : Fields, key : String, want : String) -> ParseError {
  InvalidElement(self.id, "field \"\{key}\" should be \{want}")
}

///|
/// JSON `null` behaves like a missing field: restore reads fields with `??`.
fn Fields::get(self : Fields, key : String) -> Json? {
  match self.map.get(key) {
    Some(Null) | None => None
    other => other
  }
}

///|
fn Fields::number(self : Fields, key : String) -> Double? raise ParseError {
  match self.get(key) {
    None => None
    Some(Number(v, ..)) => Some(v)
    Some(_) => raise self.bad(key, "a number")
  }
}

///|
fn Fields::string(self : Fields, key : String) -> String? raise ParseError {
  match self.get(key) {
    None => None
    Some(String(v)) => Some(v)
    Some(_) => raise self.bad(key, "a string")
  }
}

///|
fn Fields::boolean(self : Fields, key : String) -> Bool? raise ParseError {
  match self.get(key) {
    None => None
    Some(True) => Some(true)
    Some(False) => Some(false)
    Some(_) => raise self.bad(key, "a boolean")
  }
}

///|
fn Fields::points(
  self : Fields,
  key : String,
) -> Array[(Double, Double)] raise ParseError {
  guard self.get(key) is Some(Array(items)) else {
    raise self.bad(key, "an array of points")
  }
  items.map(fn(item) raise ParseError {
    guard item is Array(p) &&
      p.length() >= 2 &&
      p[0] is Number(x, ..) &&
      p[1] is Number(y, ..) else {
      raise self.bad(key, "an array of points")
    }
    (x, y)
  })
}

///|
fn parse_files(root : Map[String, Json]) -> Map[String, FileData] {
  let files = {}
  if root.get("files") is Some(Object(entries)) {
    for key, value in entries {
      if value is Object(f) &&
        f.get("mimeType") is Some(String(mime_type)) &&
        f.get("dataURL") is Some(String(data_url)) {
        let id = if f.get("id") is Some(String(id)) { id } else { key }
        files[key] = { id, mime_type, data_url, }
      }
    }
  }
  files
}

///|
/// Reads a `.excalidraw` file. Elements marked `isDeleted` are dropped here, as
/// the official editor does before it calls `exportToSvg`.
pub fn parse_scene(text : StringView) -> Scene raise ParseError {
  let text = if text.has_prefix("\u{FEFF}") {
    text.view(start_offset=1)
  } else {
    text
  }
  let json = @json.parse(text) catch { e => raise InvalidJson(e.to_string()) }
  guard json is Object(root) else {
    raise NotAScene("the top level should be an object")
  }
  if root.get("type") is Some(String(t)) && t != "excalidraw" {
    raise NotAScene("type is \"\{t}\", not \"excalidraw\"")
  }
  let items = match root.get("elements") {
    None | Some(Null) => []
    Some(Array(items)) => items
    Some(_) => raise NotAScene("\"elements\" should be an array")
  }
  let elements = []
  for i, item in items {
    guard item is Object(map) else {
      raise InvalidElement("#\{i}", "an element should be an object")
    }
    if map.get("isDeleted") is Some(True) {
      continue
    }
    let id = if map.get("id") is Some(String(id)) { id } else { "#\{i}" }
    match restore_element({ id, map, }) {
      Some(element) => elements.push(element)
      None => ()
    }
  }
  let app_state = if root.get("appState") is Some(Object(a)) { a } else { {} }
  {
    version: if root.get("version") is Some(Number(v, ..)) {
      Some(v)
    } else {
      None
    },
    elements,
    export_background: !(app_state.get("exportBackground") is Some(False)),
    view_background_color: if app_state.get("viewBackgroundColor")
      is Some(String(c)) {
      c
    } else {
      "#ffffff"
    },
    files: parse_files(root),
  }
}
