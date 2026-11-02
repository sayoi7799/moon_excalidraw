// Behaviour that is ours, not the official export's: how unsupported elements,
// suspicious input and huge input are handled.

///|
fn scene_of(elements : Array[String]) -> @model.Scene {
  @model.parse_scene(
    "{\"type\":\"excalidraw\",\"elements\":[\{elements.join(",")}]}",
  ) catch {
    e => abort("scene should parse: \{e}")
  }
}

///|
const RECT : String = "{\"id\":\"r\",\"type\":\"rectangle\",\"x\":0,\"y\":0,\"width\":100,\"height\":50,\"seed\":7}"

///|
const EMBED : String = "{\"id\":\"e\",\"type\":\"embeddable\",\"x\":900,\"y\":900,\"width\":100,\"height\":100}"

///|
const ELBOW : String = "{\"id\":\"b\",\"type\":\"arrow\",\"elbowed\":true,\"x\":900,\"y\":900,\"width\":50,\"height\":50,\"points\":[[0,0],[50,50]]}"

///|
test "unsupported elements raise when asked to" {
  let r = Ok(
    @export.export_to_svg(scene_of([RECT, EMBED]), on_unsupported=Error),
  ) catch {
    e => Err(e)
  }
  assert_true(r is Err(@export.Unsupported("e", _)))
}

///|
test "unsupported elements are skipped with a warning by default" {
  let with_embed = @export.export_to_svg(scene_of([RECT, EMBED]), fonts=None)
  let without = @export.export_to_svg(scene_of([RECT]), fonts=None)
  // Skipped elements don't widen the canvas either.
  assert_eq(with_embed.svg, without.svg)
  assert_eq(with_embed.warnings.length(), 1)
  assert_eq(with_embed.warnings[0].element_id, Some("e"))
}

///|
test "elbow arrows are unsupported" {
  let r = Ok(
    @export.export_to_svg(scene_of([RECT, ELBOW]), on_unsupported=Error),
  ) catch {
    e => Err(e)
  }
  assert_true(r is Err(@export.Unsupported("b", _)))
  let skipped = @export.export_to_svg(scene_of([RECT, ELBOW]), fonts=None)
  assert_eq(skipped.warnings.length(), 1)
}

///|
test "a clean scene has no warnings" {
  assert_eq(
    @export.export_to_svg(scene_of([RECT]), fonts=None).warnings.length(),
    0,
  )
}

///|
test "seed zero warns because the official export is random there" {
  let r = @export.export_to_svg(
    scene_of([
      "{\"id\":\"z\",\"type\":\"rectangle\",\"x\":0,\"y\":0,\"width\":10,\"height\":10,\"seed\":0}",
    ]),
    fonts=None,
  )
  assert_eq(r.warnings.length(), 1)
  assert_eq(r.warnings[0].element_id, Some("z"))
}

///|
test "duplicate ids warn" {
  let r = @export.export_to_svg(scene_of([RECT, RECT]), fonts=None)
  assert_eq(r.warnings.length(), 1)
}

///|
test "an image whose file is missing warns and draws nothing" {
  let image = "{\"id\":\"i\",\"type\":\"image\",\"x\":0,\"y\":0,\"width\":50,\"height\":50,\"fileId\":\"gone\",\"scale\":[1,1]}"
  let r = @export.export_to_svg(scene_of([image]), fonts=None)
  assert_eq(r.warnings.length(), 1)
  assert_eq(r.warnings[0].element_id, Some("i"))
  assert_false(r.svg.contains("<use"))
}

///|
test "an empty scene is a 20 by 20 canvas" {
  let r = @export.export_to_svg(scene_of([]), fonts=None)
  assert_true(r.svg.contains("viewBox=\"0 0 20 20\""))
}

///|
test "the frame title estimate is used without a measuring function" {
  let frame = "{\"id\":\"f\",\"type\":\"frame\",\"x\":0,\"y\":0,\"width\":50,\"height\":50,\"name\":\"A very long frame title\"}"
  let r = @export.export_to_svg(scene_of([frame]), fonts=None)
  // 14px * 0.5 per character cannot fit 23 characters in 50px.
  assert_true(r.svg.contains("..."))
}
