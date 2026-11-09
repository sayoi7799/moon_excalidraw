// The static site builder, tested without a file system so it runs everywhere.

///|
const RECT : String = "{\"type\":\"excalidraw\",\"elements\":[{\"id\":\"r\",\"type\":\"rectangle\",\"x\":0,\"y\":0,\"width\":100,\"height\":50,\"seed\":7}]}"

///|
fn paths(r : @site.SiteResult) -> Array[String] {
  r.files.map(fn(f) { f.path })
}

///|
fn content_of(r : @site.SiteResult, path : String) -> String {
  for f in r.files {
    if f.path == path {
      return f.content
    }
  }
  abort("no file \{path}")
}

///|
test "one diagram gives a page, an svg and a copy of the source" {
  let r = @site.build_site(
    [{ name: "a.excalidraw", source: RECT, }],
    fonts=None,
  )
  assert_eq(r.failures.length(), 0)
  assert_true(paths(r).contains("index.html"))
  assert_true(paths(r).contains("svg/a.svg"))
  assert_true(paths(r).contains("src/a.excalidraw"))
  assert_true(content_of(r, "svg/a.svg").has_prefix("<svg version=\"1.1\""))
  assert_eq(content_of(r, "src/a.excalidraw"), RECT)
}

///|
test "the svg is what export_to_svg gives" {
  let r = @site.build_site(
    [{ name: "a.excalidraw", source: RECT, }],
    fonts=None,
  )
  let scene = @model.parse_scene(RECT) catch { e => abort("parse: \{e}") }
  let direct = @export.export_to_svg(scene, fonts=None) catch {
    e => abort("export: \{e}")
  }
  assert_eq(content_of(r, "svg/a.svg"), direct.svg)
}

///|
test "the page embeds each svg with the aspect ratio of its viewBox" {
  let r = @site.build_site(
    [{ name: "a.excalidraw", source: RECT, }],
    fonts=None,
  )
  let html = content_of(r, "index.html")
  assert_true(html.contains("data=\"svg/a.svg\""))
  assert_true(html.contains("aspect-ratio: 120 / 70"))
  assert_true(html.contains("href=\"src/a.excalidraw\""))
}

///|
test "diagrams are listed in name order" {
  let r = @site.build_site(
    [
      { name: "b.excalidraw", source: RECT, },
      { name: "a.excalidraw", source: RECT, },
    ],
    fonts=None,
  )
  let html = content_of(r, "index.html")
  let a = html.find("svg/a.svg").unwrap()
  let b = html.find("svg/b.svg").unwrap()
  assert_true(a < b)
}

///|
test "a broken file becomes an error card and the rest still build" {
  let r = @site.build_site(
    [
      { name: "bad.excalidraw", source: "{oops", },
      { name: "ok.excalidraw", source: RECT, },
    ],
    fonts=None,
  )
  assert_eq(r.failures.length(), 1)
  assert_eq(r.failures[0].name, "bad.excalidraw")
  assert_false(paths(r).contains("svg/bad.svg"))
  assert_true(paths(r).contains("svg/ok.svg"))
  let html = content_of(r, "index.html")
  assert_true(html.contains("bad.excalidraw"))
  assert_true(html.contains("not valid JSON"))
}

///|
test "names and titles are escaped, paths are encoded" {
  let r = @site.build_site(
    [{ name: "a b&c<d>.excalidraw", source: RECT, }],
    title="T<&>",
    fonts=None,
  )
  let html = content_of(r, "index.html")
  assert_true(html.contains("<title>T&lt;&amp;&gt;</title>"))
  assert_true(html.contains("a b&amp;c&lt;d&gt;"))
  assert_false(html.contains("a b&c<d>"))
  assert_true(html.contains("svg/a%20b%26c-d-.svg"))
  assert_true(paths(r).contains("svg/a b&c-d-.svg"))
}

///|
test "non-ascii names are percent-encoded as utf-8 in links" {
  let r = @site.build_site(
    [{ name: "流程图.excalidraw", source: RECT, }],
    fonts=None,
  )
  let html = content_of(r, "index.html")
  assert_true(html.contains("svg/%E6%B5%81%E7%A8%8B%E5%9B%BE.svg"))
  assert_true(paths(r).contains("svg/流程图.svg"))
}

///|
test "names that differ only by extension get different files" {
  let r = @site.build_site(
    [{ name: "x.excalidraw", source: RECT, }, { name: "x.json", source: RECT, }],
    fonts=None,
  )
  let svgs = paths(r).filter(fn(p) { p.has_prefix("svg/") })
  assert_eq(svgs.length(), 2)
  assert_true(svgs[0] != svgs[1])
}

///|
test "warnings are shown on the card" {
  let embed = "{\"elements\":[{\"id\":\"e\",\"type\":\"embeddable\",\"x\":0,\"y\":0,\"width\":10,\"height\":10},{\"id\":\"r\",\"type\":\"rectangle\",\"x\":0,\"y\":0,\"width\":50,\"height\":30,\"seed\":3}]}"
  let r = @site.build_site(
    [{ name: "w.excalidraw", source: embed, }],
    fonts=None,
  )
  assert_eq(r.failures.length(), 0)
  assert_true(content_of(r, "index.html").contains("embeddable"))
}

///|
test "fonts none leaves the font rules out" {
  let text = "{\"elements\":[{\"id\":\"t\",\"type\":\"text\",\"x\":0,\"y\":0,\"width\":40,\"height\":25,\"text\":\"hi\",\"originalText\":\"hi\",\"fontSize\":20,\"fontFamily\":5,\"lineHeight\":1.25,\"seed\":1}]}"
  let with_fonts = @site.build_site([{ name: "t.excalidraw", source: text, }])
  let without = @site.build_site(
    [{ name: "t.excalidraw", source: text, }],
    fonts=None,
  )
  assert_true(content_of(with_fonts, "svg/t.svg").contains("@font-face"))
  assert_false(content_of(without, "svg/t.svg").contains("@font-face"))
}

///|
test "no diagrams still gives a page that says so" {
  let r = @site.build_site([], fonts=None)
  assert_true(content_of(r, "index.html").contains("No diagrams"))
  assert_eq(r.failures.length(), 0)
}
