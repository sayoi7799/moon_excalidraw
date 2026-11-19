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
  let files : Map[String, FileData] = Map([])
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
    text.clamped_view(start=1)
  } else {
    text
  }
  // An Obsidian Excalidraw file keeps the scene inside Markdown.
  let mut texts : Map[String, String] = Map([])
  let mut embedded : Map[String, String] = Map([])
  let mut parsed_mode = false
  let mut scene_text : String = text.to_owned()
  if @obsidian.looks_like_markdown(text) {
    let found = @obsidian.extract(text) catch {
      @obsidian.Message(message) => raise InvalidMarkdown(message)
    }
    scene_text = found.json
    texts = found.texts
    embedded = found.embedded
    parsed_mode = found.parsed_mode
  }
  let json = @json.parse(scene_text) catch {
    e => raise InvalidJson(e.to_string())
  }
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
  let filled = []
  let differing = []
  for i, item in items {
    guard item is Object(map) else {
      raise InvalidElement("#\{i}", "an element should be an object")
    }
    if map.get("isDeleted") is Some(True) {
      continue
    }
    let id = if map.get("id") is Some(String(id)) { id } else { "#\{i}" }
    if texts.length() > 0 && map.get("type") is Some(String("text")) {
      reconcile_text(map, id, texts, parsed_mode, filled, differing)
    }
    match restore_element({ id, map, }) {
      Some(element) => elements.push(element)
      None => ()
    }
  }
  let files = parse_files(root)
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
    files,
    notes: file_notes(elements, files, embedded, filled, differing, parsed_mode),
  }
}

///|
/// A text element of an Obsidian file is stored twice: in the drawing, as it was
/// last shown, and in the Text Elements section, as it was typed. The drawing
/// wins, because the plugin wraps lines with the browser's font measurements
/// and that can't be repeated here. The section only fills in a text that the
/// drawing left empty.
fn reconcile_text(
  map : Map[String, Json],
  id : String,
  texts : Map[String, String],
  parsed_mode : Bool,
  filled : Array[String],
  differing : Array[String],
) -> Unit {
  guard texts.get(id) is Some(written) else { return }
  let shown = if map.get("originalText") is Some(String(s)) {
    s
  } else if map.get("text") is Some(String(s)) {
    s
  } else {
    ""
  }
  if shown == "" {
    if written != "" {
      map["text"] = Json::string(written)
      map["originalText"] = Json::string(written)
      filled.push(id)
    }
  } else if written != shown && !parsed_mode {
    // With links resolved the two differ by design, so only the raw mode is checked.
    differing.push(id)
  }
}

///|
fn file_notes(
  elements : Array[Element],
  files : Map[String, FileData],
  embedded : Map[String, String],
  filled : Array[String],
  differing : Array[String],
  parsed_mode : Bool,
) -> Array[String] {
  let notes = []
  if filled.length() > 0 {
    notes.push(
      "text of \{filled.length()} element(s) was empty in the drawing and is read from the Text Elements section (\{filled.join(", ")})",
    )
  }
  if differing.length() > 0 && !parsed_mode {
    notes.push(
      "the Text Elements section differs from the drawing for \{differing.length()} element(s) (\{differing.join(", ")}); the drawing as last saved is shown",
    )
  }
  let vault = []
  for e in elements {
    if e.kind is Image({ file_id: Some(f), .. }) &&
      !files.contains(f) &&
      embedded.get(f) is Some(path) {
      vault.push("[[\{path}]]")
    }
  }
  if vault.length() > 0 {
    notes.push(
      "\{vault.length()} image(s) are files in the Obsidian vault, which isn't available, so they are not drawn: \{vault.join(", ")}",
    )
  }
  notes
}
