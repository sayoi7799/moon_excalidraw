///|
/// The same metric the fixtures stub `measureText` with: 7px per code point.
fn fixture_measure(text : String, _font : String) -> Double {
  let mut n = 0
  for _ in text {
    n += 1
  }
  n.to_double() * 7.0
}

///|
fn render(case : @fixtures.SceneCase) -> String? {
  try {
    let scene = @model.parse_scene(case.input)
    let fonts : @export.FontMode = if case.fonts == "url" { Url } else { None }
    Some(@export.export_to_svg(scene, fonts~, measure_text=fixture_measure).svg)
  } catch {
    _ => None
  }
}

///|
fn check_suite(name : String, cases : Array[@fixtures.SceneCase]) -> Unit raise {
  let stats = @conform.run(name, cases, render)
  println("[conformance] \{stats}")
  if stats.failed > 0 {
    println("  failing: " + stats.failures.join(", "))
  }
  assert_eq(stats.failed, 0)
}

///|
test "font modes match official" {
  check_suite("fonts", @fixtures.fonts)
}

///|
test "single misc match official" {
  check_suite("single misc", @fixtures.single_misc)
}

///|
test "single text match official" {
  check_suite("single text", @fixtures.single_text)
}

///|
test "single linear match official" {
  check_suite("single linear", @fixtures.single_linear)
}

///|
test "single basic shapes match official" {
  check_suite("single basic", @fixtures.single_basic)
}
