// Big and hostile input must finish or fail cleanly, never crash.

///|
fn rect_json(i : Int32) -> String {
  "{\"id\":\"r\{i}\",\"type\":\"rectangle\",\"x\":\{i % 100 * 70},\"y\":\{i / 100 * 60},\"width\":60,\"height\":40,\"seed\":\{i + 1},\"backgroundColor\":\"#a5d8ff\"}"
}

///|
test "scale: 5000 rectangles" {
  let items = []
  for i in 0..<5000 {
    items.push(rect_json(i))
  }
  let scene = @model.parse_scene("{\"elements\":[\{items.join(",")}]}") catch {
    e => abort("should parse: \{e}")
  }
  let r = @export.export_to_svg(scene, fonts=None) catch {
    e => abort("should export: \{e}")
  }
  assert_eq(r.warnings.length(), 0)
  assert_true(r.svg.length() > 1000000)
}

///|
test "scale: a freedraw stroke of 10000 points" {
  let points = []
  for i in 0..<10000 {
    let x = (i % 200).to_double() + i.to_double() / 100.0
    let y = (i / 50).to_double()
    points.push("[\{x},\{y}]")
  }
  let json = "{\"elements\":[{\"id\":\"f\",\"type\":\"freedraw\",\"x\":0,\"y\":0,\"width\":300,\"height\":200,\"seed\":3,\"points\":[\{points.join(",")}],\"pressures\":[],\"simulatePressure\":true}]}"
  let scene = @model.parse_scene(json) catch {
    e => abort("should parse: \{e}")
  }
  let r = @export.export_to_svg(scene, fonts=None) catch {
    e => abort("should export: \{e}")
  }
  assert_true(r.svg.contains("<path"))
}

///|
test "scale: deeply nested JSON is an error, not a crash" {
  let sb = StringBuilder::new()
  for _ in 0..<100000 {
    sb.write_char('[')
  }
  let r = Ok(@model.parse_scene(sb.to_string())) catch { e => Err(e) }
  assert_true(r is Err(@model.InvalidJson(_)))
}

///|
test "scale: deeply nested fields inside an element are an error too" {
  let sb = StringBuilder::new()
  sb.write_string(
    "{\"elements\":[{\"id\":\"a\",\"type\":\"rectangle\",\"customData\":",
  )
  for _ in 0..<100000 {
    sb.write_string("{\"a\":")
  }
  sb.write_string("1")
  for _ in 0..<100000 {
    sb.write_char('}')
  }
  sb.write_string("}]}")
  let r = Ok(@model.parse_scene(sb.to_string())) catch { e => Err(e) }
  assert_true(r is Err(@model.InvalidJson(_)))
}
