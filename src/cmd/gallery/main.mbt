// Writes a single HTML page that shows, for each scene, this library's SVG next
// to the official one. The official SVGs are the test fixtures.
//
//   moon run --target js src/cmd/gallery -- gallery/index.html

///|
const B64 : String = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

///|
fn base64(bytes : Bytes) -> String {
  let table = B64.to_array()
  let out = StringBuilder::new()
  let n = bytes.length()
  let mut i = 0
  while i < n {
    let b0 = bytes[i].to_int()
    let b1 = if i + 1 < n { bytes[i + 1].to_int() } else { 0 }
    let b2 = if i + 2 < n { bytes[i + 2].to_int() } else { 0 }
    out.write_char(table[b0 >> 2])
    out.write_char(table[((b0 & 3) << 4) | (b1 >> 4)])
    out.write_char(
      if i + 1 < n {
        table[((b1 & 15) << 2) | (b2 >> 6)]
      } else {
        '='
      },
    )
    out.write_char(if i + 2 < n { table[b2 & 63] } else { '=' })
    i += 3
  }
  out.to_string()
}

///|
/// An SVG as an <img> source. An image keeps every scene's ids (masks, clip
/// paths) apart, which inline SVGs in one page would not.
fn data_uri(svg : String) -> String {
  "data:image/svg+xml;base64," + base64(@utf8.encode(svg))
}

///|
fn escape_html(s : String) -> String {
  s
  .replace_all(old="&", new="&amp;")
  .replace_all(old="<", new="&lt;")
  .replace_all(old=">", new="&gt;")
  .replace_all(old="\"", new="&quot;")
}

///|
fn fixture_measure(text : String, _font : String) -> Double {
  let mut n = 0
  for _ in text {
    n += 1
  }
  n.to_double() * 7.0
}

///|
/// This library's SVG for a fixture, or None if it reports an error.
fn render(c : @fixtures.SceneCase) -> String? {
  try {
    let scene = @model.parse_scene(c.input)
    let fonts : @export.FontMode = if c.fonts == "url" { Url } else { None }
    Some(@export.export_to_svg(scene, fonts~, measure_text=fixture_measure).svg)
  } catch {
    _ => None
  }
}

///|
fn picture(title : String, svg : String?) -> String {
  match svg {
    Some(svg) =>
      "<figure><figcaption>\{title}</figcaption><img loading=\"lazy\" alt=\"\{title}\" src=\"\{data_uri(svg)}\"></figure>"
    None =>
      "<figure><figcaption>\{title}</figcaption><p class=\"error\">reports an error</p></figure>"
  }
}

///|
struct Section {
  title : String
  note : String
  cases : Array[@fixtures.SceneCase]
}

///|
/// Every `step`-th case, so the big generated suites don't swamp the page.
fn every(
  cases : Array[@fixtures.SceneCase],
  step : Int32,
) -> Array[@fixtures.SceneCase] {
  let out = []
  for i, c in cases {
    if i % step == 0 {
      out.push(c)
    }
  }
  out
}

///|
fn main {
  let sections = [
    {
      title: "Diagrams",
      note: "Flowcharts and architecture diagrams, hand-made and random scenes, and three scenes drawn in the real editor (real/).",
      cases: @fixtures.combo,
    },
    {
      title: "Images, frames, freedraw and links",
      note: "Freedraw strokes, images, frames with clipped children, and links.",
      cases: @fixtures.single_misc,
    },
    {
      title: "Edge cases",
      note: "Empty and degenerate scenes, extreme numbers, and old file formats.",
      cases: @fixtures.edge,
    },
    {
      title: "Basic shapes (every 8th scene)",
      note: "Rectangles, diamonds and ellipses across every fill, stroke and roundness option.",
      cases: every(@fixtures.single_basic, 8),
    },
    {
      title: "Lines and arrows (every 10th scene)",
      note: "Lines, arrows, closed fills and all arrowhead styles.",
      cases: every(@fixtures.single_linear, 10),
    },
    {
      title: "Text (every 8th scene)",
      note: "Fonts, alignment, directions and text bound to shapes and arrows.",
      cases: every(@fixtures.single_text, 8),
    },
  ]
  let body = StringBuilder::new()
  let mut total = 0
  let mut same = 0
  for section in sections {
    body.write_string(
      "<h2>\{section.title}</h2><p class=\"note\">\{section.note}</p><div class=\"grid\">",
    )
    for c in section.cases {
      let ours = render(c)
      let identical = ours == c.expected
      total += 1
      if identical {
        same += 1
      }
      let badge = if identical {
        "<span class=\"ok\">identical bytes</span>"
      } else {
        "<span class=\"differs\">differs</span>"
      }
      body.write_string(
        "<section class=\"card\"><h3>\{escape_html(c.name)} \{badge}</h3><div class=\"pair\">\{picture("moon_excalidraw", ours)}\{picture("official exportToSvg", c.expected)}</div></section>",
      )
    }
    body.write_string("</div>")
  }
  let html = "<!doctype html>\n<html lang=\"en\"><head><meta charset=\"utf-8\"><meta name=\"viewport\" content=\"width=device-width,initial-scale=1\"><title>moon_excalidraw gallery</title><style>\n:root{color-scheme:light dark;--bg:#fafafa;--fg:#1e1e1e;--card:#fff;--line:#e0e0e0;--ok:#1a7f37;--bad:#cf222e}\n@media (prefers-color-scheme:dark){:root{--bg:#161616;--fg:#e6e6e6;--card:#202020;--line:#383838;--ok:#3fb950;--bad:#ff7b72}}\nbody{margin:0;padding:24px 16px;background:var(--bg);color:var(--fg);font:15px/1.5 system-ui,sans-serif}\nmain{max-width:1200px;margin:0 auto}\nh1{margin:0 0 4px}h2{margin:40px 0 4px}h3{margin:0 0 8px;font-size:14px;font-weight:600;word-break:break-all}\n.note,.summary{margin:0 0 16px;opacity:.75}\n.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(min(100%,520px),1fr));gap:16px}\n.card{background:var(--card);border:1px solid var(--line);border-radius:10px;padding:12px}\n.pair{display:grid;grid-template-columns:1fr 1fr;gap:8px}\nfigure{margin:0;min-width:0}figcaption{font-size:12px;opacity:.7;margin-bottom:4px}\nimg{width:100%;height:auto;max-height:340px;object-fit:contain;background:#fff;border:1px solid var(--line);border-radius:6px}\n.ok{color:var(--ok);font-weight:500;margin-left:6px}.differs,.error{color:var(--bad);font-weight:500}\n</style></head><body><main><h1>moon_excalidraw gallery</h1><p class=\"summary\">\{same} of \{total} scenes shown are byte-for-byte identical to the official Excalidraw 0.18.1 export. Text uses whatever font your browser falls back to, since an image can't load the fonts an SVG names.</p>\{body.to_string()}</main></body></html>\n"
  let path = match user_args() {
    [p, ..] => p
    [] => "gallery/index.html"
  }
  @fs.write_string_to_file(path, html) catch {
    @fs.IOError(message) => {
      eprintln("error: cannot write \{path}: \{message}")
      @sys.exit(1)
    }
  }
  println("wrote \{path}: \{total} scenes, \{same} identical")
}
