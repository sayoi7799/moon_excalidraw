// Builds a small static site from a set of Excalidraw files: one page that shows
// every diagram, the SVG of each, and a copy of each source file. It does no file
// access itself; the command that calls it reads the folder and writes the result.

///|
pub(all) struct Diagram {
  /// The file name, such as `architecture.excalidraw`.
  name : String
  /// The file's text.
  source : String
}

///|
pub(all) struct SiteFile {
  /// Where the file goes, relative to the site's folder, with `/` separators.
  path : String
  content : String
}

///|
/// A diagram that couldn't be rendered, and why.
pub(all) struct Failure {
  name : String
  message : String
}

///|
pub(all) struct SiteResult {
  files : Array[SiteFile]
  failures : Array[Failure]
}

///|
/// Characters that can't be in a file name on every system.
fn is_unsafe_in_file_name(c : Char) -> Bool {
  match c {
    '/' | '\\' | ':' | '*' | '?' | '"' | '<' | '>' | '|' => true
    _ => c.to_int() < 32
  }
}

///|
fn safe_file_name(name : String) -> String {
  let out = StringBuilder()
  for c in name {
    out.write_char(if is_unsafe_in_file_name(c) { '-' } else { c })
  }
  out.to_string()
}

///|
/// The name without `.excalidraw` or `.json`.
fn stem_of(name : String) -> String {
  if name.has_suffix(".excalidraw") {
    name.clamped_view(end=name.length() - ".excalidraw".length()).to_owned()
  } else if name.has_suffix(".json") {
    name.clamped_view(end=name.length() - ".json".length()).to_owned()
  } else {
    name
  }
}

///|
fn escape_html(s : String) -> String {
  let out = StringBuilder()
  for c in s {
    match c {
      '&' => out.write_string("&amp;")
      '<' => out.write_string("&lt;")
      '>' => out.write_string("&gt;")
      '"' => out.write_string("&quot;")
      _ => out.write_char(c)
    }
  }
  out.to_string()
}

///|
fn is_unreserved(c : Char) -> Bool {
  (c >= 'a' && c <= 'z') ||
  (c >= 'A' && c <= 'Z') ||
  (c >= '0' && c <= '9') ||
  c == '-' ||
  c == '.' ||
  c == '_' ||
  c == '~'
}

///|
/// A path segment for a URL: everything but letters, digits and `-._~` is written
/// as the percent-encoded bytes of its UTF-8 form.
fn url_segment(s : StringView) -> String {
  let hex = "0123456789ABCDEF".to_array()
  let out = StringBuilder()
  for c in s {
    if is_unreserved(c) {
      out.write_char(c)
    } else {
      let bytes = @utf8.encode(c.to_string())
      for b in bytes {
        out.write_char('%')
        out.write_char(hex[b.to_int() >> 4])
        out.write_char(hex[b.to_int() & 15])
      }
    }
  }
  out.to_string()
}

///|
/// The `W H` of `viewBox="0 0 W H"`, which gives the diagram its shape on the page.
fn aspect_ratio(svg : String) -> String? {
  let marker = "viewBox=\"0 0 "
  guard svg.find(marker) is Some(start) else { return None }
  let rest = svg.clamped_view(start=start + marker.length())
  guard rest.find("\"") is Some(end) else { return None }
  let parts = rest.clamped_view(end~).to_owned().split(" ").collect()
  if parts.length() == 2 {
    Some("\{parts[0]} / \{parts[1]}")
  } else {
    None
  }
}

///|
priv struct Built {
  name : String
  svg_path : String
  source_path : String
  ratio : String?
  warnings : Array[String]
}

///|
/// A path that no earlier diagram took.
fn unique_path(
  taken : Map[String, Bool],
  dir : String,
  stem : String,
  ext : String,
) -> String {
  let mut path = "\{dir}/\{stem}\{ext}"
  let mut n = 2
  while taken.contains(path) {
    path = "\{dir}/\{stem}-\{n}\{ext}"
    n += 1
  }
  taken[path] = true
  path
}

///|
fn card(b : Built) -> String {
  let name = escape_html(b.name)
  let svg_url = b.svg_path.split("/").map(url_segment).collect().join("/")
  let src_url = b.source_path.split("/").map(url_segment).collect().join("/")
  let style = match b.ratio {
    Some(r) => " style=\"aspect-ratio: \{r}\""
    None => ""
  }
  let warnings = if b.warnings.length() == 0 {
    ""
  } else {
    "<ul class=\"warnings\">" +
    b.warnings.map(fn(w) { "<li>\{escape_html(w)}</li>" }).join("") +
    "</ul>"
  }
  "<section class=\"card\"><h2>\{name}</h2><object data=\"\{svg_url}\" type=\"image/svg+xml\"\{style}><img src=\"\{svg_url}\" alt=\"\{name}\"></object><p class=\"links\"><a href=\"\{svg_url}\">SVG</a> <a href=\"\{src_url}\">.excalidraw</a></p>\{warnings}</section>"
}

///|
fn failed_card(f : Failure) -> String {
  "<section class=\"card failed\"><h2>\{escape_html(f.name)}</h2><p class=\"error\">\{escape_html(f.message)}</p></section>"
}

///|
const STYLE : String = "\n:root{color-scheme:light dark;--bg:#fafafa;--fg:#1e1e1e;--card:#fff;--line:#e0e0e0;--bad:#cf222e;--muted:#6a6a6a}\n@media (prefers-color-scheme:dark){:root{--bg:#161616;--fg:#e6e6e6;--card:#202020;--line:#383838;--bad:#ff7b72;--muted:#a0a0a0}}\nbody{margin:0;padding:32px 16px;background:var(--bg);color:var(--fg);font:16px/1.5 system-ui,sans-serif}\nmain{max-width:1100px;margin:0 auto}\nh1{margin:0 0 4px}.lead{margin:0 0 24px;color:var(--muted)}\n.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(min(100%,440px),1fr));gap:16px}\n.card{background:var(--card);border:1px solid var(--line);border-radius:10px;padding:14px;min-width:0}\n.card h2{margin:0 0 10px;font-size:15px;font-weight:600;word-break:break-all}\nobject,img{display:block;width:100%;height:auto;background:#fff;border:1px solid var(--line);border-radius:6px}\n.links{margin:10px 0 0;font-size:14px}.links a{margin-right:12px}\n.warnings{margin:8px 0 0;padding-left:20px;font-size:13px;color:var(--muted)}\n.error{margin:0;color:var(--bad);font-size:14px}\n"

///|
fn page(
  title : String,
  cards : Array[String],
  count : Int32,
  failed : Int32,
) -> String {
  let title_html = escape_html(title)
  let summary = if count == 0 {
    "No diagrams found."
  } else if failed == 0 {
    "\{count} diagram\{if count == 1 { "" } else { "s" }}."
  } else {
    "\{count} diagrams, \{failed} could not be rendered."
  }
  let body = if count == 0 {
    "<p>No diagrams found. Put <code>.excalidraw</code> files in the folder and build again.</p>"
  } else {
    "<div class=\"grid\">" + cards.join("") + "</div>"
  }
  "<!doctype html>\n<html lang=\"en\"><head><meta charset=\"utf-8\"><meta name=\"viewport\" content=\"width=device-width,initial-scale=1\"><title>\{title_html}</title><style>\{STYLE}</style></head><body><main><h1>\{title_html}</h1><p class=\"lead\">\{summary} Drawn by moon_excalidraw.</p>\{body}</main></body></html>\n"
}

///|
priv enum Rendered {
  Done(@export.ExportResult)
  Failed(String)
}

///|
fn render(d : Diagram, fonts : @export.FontMode) -> Rendered {
  let scene = @model.parse_scene(d.source) catch {
    e => return Failed(Show::to_string(e))
  }
  let result = @export.export_to_svg(scene, fonts~) catch {
    e => return Failed(Show::to_string(e))
  }
  Done(result)
}

///|
/// Renders every diagram and builds the page. A diagram that can't be rendered
/// gets a card that says why and is listed in `failures`; the others still build.
/// Diagrams are listed in order of their file names.
pub fn build_site(
  diagrams : Array[Diagram],
  title~ : String = "Diagrams",
  fonts~ : @export.FontMode = Url,
) -> SiteResult {
  let sorted = diagrams.copy()
  sorted.sort_by(fn(a, b) { a.name.compare(b.name) })
  let files = []
  let failures = []
  let cards = []
  let taken : Map[String, Bool] = Map([])
  for d in sorted {
    match render(d, fonts) {
      Failed(message) => {
        failures.push({ name: d.name, message, })
        cards.push(failed_card({ name: d.name, message, }))
      }
      Done(result) => {
        let svg_path = unique_path(
          taken,
          "svg",
          safe_file_name(stem_of(d.name)),
          ".svg",
        )
        let source_path = unique_path(taken, "src", safe_file_name(d.name), "")
        files.push({ path: svg_path, content: result.svg, })
        files.push({ path: source_path, content: d.source, })
        cards.push(
          card({
            name: d.name,
            svg_path,
            source_path,
            ratio: aspect_ratio(result.svg),
            warnings: result.warnings.map(fn(w) {
              match w.element_id {
                Some(id) => "element \"\{id}\": \{w.message}"
                None => w.message
              }
            }),
          }),
        )
      }
    }
  }
  files.insert(0, {
    path: "index.html",
    content: page(title, cards, sorted.length(), failures.length()),
  })
  { files, failures, }
}
