///|
fn obsidian_case(name : String) -> @fixtures.SceneCase {
  for c in @fixtures.obsidian {
    if c.name == name {
      return c
    }
  }
  abort("no fixture called \{name}")
}

///|
fn warnings_of(name : String) -> Array[String] raise {
  let c = obsidian_case(name)
  let scene = @model.parse_scene(c.input)
  let result = @export.export_to_svg(
    scene,
    fonts=None,
    measure_text=fixture_measure,
  )
  result.warnings.map(fn(w) { w.message })
}

///|
fn has_warning(warnings : Array[String], part : String) -> Bool {
  warnings.any(fn(w) { w.contains(part) })
}

///|
test "a file saved by the plugin gives no notes of its own" {
  assert_eq(warnings_of("flowchart"), [])
  assert_eq(warnings_of("texts"), [])
  assert_eq(warnings_of("flowchart, CRLF"), [])
}

///|
test "an empty text is filled in from the Text Elements section" {
  let w = warnings_of("texts, one empty in the drawing")
  assert_eq(w.length(), 1)
  assert_true(has_warning(w, "empty in the drawing"))
  assert_true(has_warning(w, "cD4eF6hJ"))
}

///|
test "a section edited by hand is reported and the drawing wins" {
  let w = warnings_of("texts, section edited")
  assert_eq(w.length(), 1)
  assert_true(has_warning(w, "differs from the drawing"))
  assert_true(has_warning(w, "aB3dE5gH"))
}

///|
test "the parsed mode does not report differences" {
  // In that mode the section holds the text as typed and the drawing the
  // resolved text, so they differ by design.
  assert_eq(warnings_of("flowchart, parsed mode"), [])
}

///|
test "an image in the vault says where it is" {
  let w = warnings_of("texts and an image in the vault")
  assert_true(has_warning(w, "Obsidian vault"))
  assert_true(has_warning(w, "[[Pasted image 20260101.png]]"))
}

///|
test "a damaged Obsidian file is a ParseError" {
  let r : Result[@model.Scene, @model.ParseError] = Ok(
    @model.parse_scene("---\nexcalidraw-plugin: raw\n---\n# Excalidraw Data\n"),
  ) catch {
    e => Err(e)
  }
  assert_true(r is Err(@model.InvalidMarkdown(_)))
}
