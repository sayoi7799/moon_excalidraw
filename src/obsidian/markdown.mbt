// Reads the `.excalidraw.md` files that the Obsidian Excalidraw plugin writes.
// Only the layout of the file is followed, as the plugin documents it and as
// its files show; none of the plugin's code is used. The layout:
//
//   ---                                 front matter, `excalidraw-plugin: parsed|raw`
//   ---
//   # Excalidraw Data
//   ## Text Elements                    each text, then ` ^` and an 8 character id
//   ## Element Links                    `id: [[link]]`
//   ## Embedded Files                   `fileId: [[path in the vault]]`
//   %%
//   ## Drawing
//   ```compressed-json                  or ```json, plain and tab-indented
//   <LZ-String Base64 of the scene JSON, in 256 character pieces>
//   ```
//   %%

///|
pub suberror MarkdownError {
  Message(String)
}

///|
pub impl Show for MarkdownError with fn output(self, logger) {
  match self {
    Message(message) => logger.write_string(message)
  }
}

///|
/// What was read from the file.
pub(all) struct Extracted {
  /// The scene, as the text of an `.excalidraw` file.
  json : String
  /// `## Text Elements`: the text written for each element id.
  texts : Map[String, String]
  /// `## Embedded Files`: the vault link written for each file id.
  embedded : Map[String, String]
  /// The front matter says the texts were saved with their links resolved.
  parsed_mode : Bool
}

///|
/// Whether `text` is an Obsidian Excalidraw file rather than the JSON of an
/// `.excalidraw` file. JSON starts with `{`; the Markdown file has its front
/// matter or one of its headings.
pub fn looks_like_markdown(text : StringView) -> Bool {
  let head = text.trim_start(chars=" \t\r\n")
  if head.has_prefix("{") {
    return false
  }
  head.has_prefix("---") ||
  text.contains("# Excalidraw Data") ||
  text.contains("## Drawing") ||
  text.contains("```compressed-json")
}

///|
fn lines_of(text : StringView) -> Array[String] {
  let unified = text.to_owned().replace_all(old="\r\n", new="\n")
  unified.split("\n").map(fn(l) { l.to_owned() }).collect()
}

///|
fn is_heading(line : String, name : String) -> Bool {
  let l = line.trim_end(chars=" \t")
  l == "## " + name || l == "# " + name
}

///|
/// The index of the first line at or after `from` that is a heading called
/// `name`.
fn find_heading(lines : Array[String], name : String, from : Int32) -> Int32? {
  for i in from..<lines.length() {
    if is_heading(lines[i], name) {
      return Some(i)
    }
  }
  None
}

///|
/// The lines of a section: after its heading, up to the next `##` heading or
/// `%%` line.
fn section(lines : Array[String], name : String) -> Array[String] {
  let out = []
  match find_heading(lines, name, 0) {
    None => ()
    Some(start) => {
      let mut i = start + 1
      while i < lines.length() {
        let l = lines[i]
        if l.has_prefix("## ") ||
          l.has_prefix("# ") ||
          l.trim_end(chars=" \t") == "%%" {
          break
        }
        out.push(l)
        i += 1
      }
    }
  }
  out
}

///|
fn front_matter_parsed(lines : Array[String]) -> Bool {
  if lines.length() == 0 || lines[0].trim_end(chars=" \t") != "---" {
    return false
  }
  for i in 1..<lines.length() {
    let l = lines[i].trim_end(chars=" \t")
    if l == "---" {
      break
    }
    if l.has_prefix("excalidraw-plugin:") {
      return l
        .trim_start(chars="excalidraw-plugin:")
        .trim(chars=" \t")
        .to_owned() ==
        "parsed"
    }
  }
  false
}

///|
const LINK_MARK : String = "%%***>>>text element-link:"

///|
/// `## Text Elements`. An entry is any number of lines ending in ` ^` and
/// eight characters; the id is those eight characters.
fn read_texts(lines : Array[String]) -> Map[String, String] {
  let texts : Map[String, String] = Map([])
  let pending = []
  for line in section(lines, "Text Elements") {
    let l = line.trim_end(chars=" \t").to_owned()
    let n = l.length()
    if n >= 10 && l[n - 10] == ' ' && l[n - 9] == '^' {
      pending.push(l.clamped_view(end=n - 10).to_owned())
      let id = l.clamped_view(start=n - 8).to_owned()
      let mut text = pending.join("\n")
      // A link to the text element is written in front of the text.
      if text.has_prefix(LINK_MARK) {
        match text.find("<<<***%%") {
          Some(i) =>
            text = text
              .clamped_view(start=i + 8)
              .to_owned()
              .trim_start(chars="\n")
              .to_owned()
          None => ()
        }
      }
      texts[id] = text
      pending.clear()
    } else if l != "" || pending.length() > 0 {
      pending.push(l)
    }
  }
  texts
}

///|
/// `## Embedded Files`: `fileId: [[path]]`, also written `![[path]]`.
fn read_embedded(lines : Array[String]) -> Map[String, String] {
  let files : Map[String, String] = Map([])
  for line in section(lines, "Embedded Files") {
    match line.find(":") {
      Some(colon) => {
        let id = line.clamped_view(end=colon).trim(chars=" \t").to_owned()
        let rest = line
          .clamped_view(start=colon + 1)
          .trim(chars=" \t")
          .to_owned()
        let link = rest.trim_start(chars="!").to_owned()
        if id != "" && link.has_prefix("[[") && link.has_suffix("]]") {
          files[id] = link
            .clamped_view(start=2, end=link.length() - 2)
            .to_owned()
        }
      }
      None => ()
    }
  }
  files
}

///|
fn is_base64_text(s : String) -> Bool {
  for i in 0..<s.length() {
    let c = s[i].to_int()
    let ok = (c >= 'A'.to_int() && c <= 'Z'.to_int()) ||
      (c >= 'a'.to_int() && c <= 'z'.to_int()) ||
      (c >= '0'.to_int() && c <= '9'.to_int()) ||
      c == '+'.to_int() ||
      c == '/'.to_int() ||
      c == '='.to_int()
    if !ok {
      return false
    }
  }
  true
}

///|
/// The drawing: the lines under `## Drawing`, which hold either a
/// `compressed-json` or a `json` fence, or, in files that were edited by hand,
/// the data on its own.
fn read_drawing(lines : Array[String]) -> String raise MarkdownError {
  let start = match find_heading(lines, "Drawing", 0) {
    Some(i) => i
    None =>
      raise Message(
        "no \"## Drawing\" section: this is not a file of the Obsidian Excalidraw plugin",
      )
  }
  let mut i = start + 1
  let mut compressed = false
  let mut fenced = false
  // Skip to the fence; the plugin accepts prose between the heading and it.
  while i < lines.length() {
    let l = lines[i].trim_end(chars=" \t")
    if l.has_prefix("```compressed-json") {
      compressed = true
      fenced = true
      i += 1
      break
    }
    if l.has_prefix("```json") {
      fenced = true
      i += 1
      break
    }
    if l.has_prefix("```") {
      break
    }
    if l.has_prefix("{") && !fenced {
      break
    }
    i += 1
  }
  if !fenced && i >= lines.length() {
    // No fence at all: the data is on the first line that has something on it.
    i = start + 1
    while i < lines.length() && lines[i].trim_end(chars=" \t") == "" {
      i += 1
    }
  }
  let body = []
  while i < lines.length() {
    let l = lines[i]
    if l.has_prefix("```") || (!fenced && l.trim_end(chars=" \t") == "%%") {
      break
    }
    body.push(l)
    i += 1
  }
  if !fenced && body.length() == 0 {
    raise Message("the \"## Drawing\" section has no drawing in it")
  }
  let text = body.join(if compressed { "" } else { "\n" })
  let payload = if compressed ||
    (!fenced && !text.trim_start(chars=" \t").has_prefix("{")) {
    // Newlines and carriage returns are the only characters the plugin removes.
    let packed = text
      .replace_all(old="\n", new="")
      .replace_all(old="\r", new="")
    if !is_base64_text(packed) {
      raise Message("the compressed drawing is not Base64 text")
    }
    match decompress_from_base64(packed) {
      Some(json) => json
      None => raise Message("the compressed drawing is damaged")
    }
  } else {
    text
  }
  // Nothing after the last closing brace belongs to the scene.
  match payload.rev_find("}") {
    Some(i) => payload.clamped_view(end=i + 1).to_owned()
    None => raise Message("the drawing does not contain a scene")
  }
}

///|
/// Reads an `.excalidraw.md` file.
pub fn extract(text : StringView) -> Extracted raise MarkdownError {
  let lines = lines_of(text)
  {
    json: read_drawing(lines),
    texts: read_texts(lines),
    embedded: read_embedded(lines),
    parsed_mode: front_matter_parsed(lines),
  }
}
