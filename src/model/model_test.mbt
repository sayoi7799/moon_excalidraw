///|
fn num(x : Double) -> String {
  @jsmath.number_to_string(x)
}

///|
fn opt(s : String?) -> String {
  s.unwrap_or("~")
}

///|
fn pts(points : Array[(Double, Double)]) -> String {
  points.map(fn(p) { "\{num(p.0)},\{num(p.1)}" }).join(" ")
}

///|
/// The same canonical form as `canon` in scripts/cases_restore.mjs.
fn canon(e : @model.Element) -> String {
  let kind = match e.kind {
    Rectangle => "rectangle"
    Diamond => "diamond"
    Ellipse => "ellipse"
    Line(l) =>
      "line:\{pts(l.points)}:\{opt(l.start_arrowhead)}:\{opt(l.end_arrowhead)}"
    Arrow(l) =>
      "arrow:\{pts(l.points)}:\{opt(l.start_arrowhead)}:\{opt(l.end_arrowhead)}"
    Freedraw(f) =>
      "freedraw:\{pts(f.points)}:\{f.pressures.map(num).join(",")}:\{f.simulate_pressure}"
    Text(t) =>
      "text:\{t.text}:\{t.original_text}:\{num(t.font_size)}:\{t.font_family}:\{t.text_align}:\{t.vertical_align}:\{opt(t.container_id)}:\{num(t.line_height)}"
    Image(i) => "image:\{opt(i.file_id)}:\{num(i.scale.0)},\{num(i.scale.1)}"
    Frame(n) => "frame:\{opt(n)}"
    MagicFrame(n) => "magicframe:\{opt(n)}"
    Unsupported(t) => "unsupported:\{t}"
  }
  let round = match e.roundness {
    None => "~"
    Some(r) => {
      let value = r.value.map(num).unwrap_or("~")
      "\{r.kind}:\{value}"
    }
  }
  let bound = e.bound_elements.map(fn(b) { "\{b.kind}/\{b.id}" }).join(",")
  [
    kind,
    e.id,
    num(e.x),
    num(e.y),
    num(e.width),
    num(e.height),
    num(e.angle),
    e.stroke_color,
    e.background_color,
    e.fill_style,
    num(e.stroke_width),
    e.stroke_style,
    num(e.roughness),
    num(e.opacity),
    e.seed.to_string(),
    round,
    bound,
    opt(e.frame_id),
    opt(e.link),
    e.is_deleted.to_string(),
  ].join("|")
}

///|
test "restore matches official" {
  let mut bad = 0
  for case in @fixtures.restore_cases {
    let scene = @model.parse_scene(case.input)
    let got = scene.elements.map(canon).join("\n")
    if got != case.expected {
      println(
        "restore mismatch \{case.name}\n got: \{got}\nwant: \{case.expected}",
      )
      bad += 1
    }
  }
  println(
    "[restore] total=\{@fixtures.restore_cases.length()} mismatched=\{bad}",
  )
  assert_eq(bad, 0)
}

///|
test "normalize_link matches official" {
  let mut bad = 0
  for case in @fixtures.link_cases {
    let got = @model.normalize_link(case.0)
    if got != case.1 {
      println("link mismatch \{case.0}: got \{got}, want \{case.1}")
      bad += 1
    }
  }
  assert_eq(bad, 0)
}

///|
test "invalid json raises" {
  assert_true(attempt("{oops") is Some(@model.InvalidJson(_)))
}

///|
test "non-object top level raises" {
  assert_true(attempt("[1,2]") is Some(@model.NotAScene(_)))
}

///|
test "library file raises" {
  let r = attempt("{\"type\":\"excalidrawlib\",\"elements\":[]}")
  assert_true(r is Some(@model.NotAScene(_)))
}

///|
test "elements not array raises" {
  assert_true(attempt("{\"elements\":1}") is Some(@model.NotAScene(_)))
}

///|
test "element not an object raises" {
  let r = attempt("{\"elements\":[3]}")
  assert_true(r is Some(@model.InvalidElement("#0", _)))
}

///|
test "wrong field type names element" {
  let r = attempt(
    "{\"elements\":[{\"id\":\"e\",\"type\":\"rectangle\",\"width\":\"x\"}]}",
  )
  assert_true(r is Some(@model.InvalidElement("e", _)))
}

///|
test "non-numeric points name element" {
  let r = attempt(
    "{\"elements\":[{\"id\":\"l\",\"type\":\"line\",\"points\":[[0,0],[\"a\",1]]}]}",
  )
  assert_true(r is Some(@model.InvalidElement("l", _)))
}

///|
test "arrow without points raises" {
  let r = attempt(
    "{\"elements\":[{\"id\":\"a\",\"type\":\"arrow\",\"x\":0,\"y\":0}]}",
  )
  assert_true(r is Some(@model.InvalidElement("a", _)))
}

///|
test "utf8 bom skipped" {
  assert_true(attempt("\u{FEFF}{\"elements\":[]}") is None)
}

///|
test "unknown fields tolerated" {
  assert_true(attempt("{\"elements\":[],\"wat\":1}") is None)
}

///|
test "deleted elements are dropped without validation" {
  let s = @model.parse_scene(
    "{\"elements\":[{\"id\":\"e\",\"type\":\"rectangle\",\"width\":\"x\",\"isDeleted\":true}]}",
  )
  assert_eq(s.elements.length(), 0)
}

///|
test "unknown element types are kept as unsupported" {
  let s = @model.parse_scene(
    "{\"elements\":[{\"id\":\"u\",\"type\":\"embeddable\"}]}",
  )
  assert_true(s.elements[0].kind is Unsupported("embeddable"))
}

///|
test "app state defaults" {
  let s = @model.parse_scene("{\"elements\":[]}")
  assert_true(s.export_background)
  assert_eq(s.view_background_color, "#ffffff")
}

///|
fn attempt(s : String) -> @model.ParseError? {
  ignore(@model.parse_scene(s)) catch {
    e => return Some(e)
  }
  None
}
