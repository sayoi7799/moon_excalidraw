///|
let rectangle : String =
  #|{"type":"excalidraw","version":2,"elements":[
  #|  {"type":"rectangle","id":"a","x":0,"y":0,"width":120,"height":60,"seed":1}
  #|]}

///|
fn field(text : String, key : String) -> Json raise {
  match @json.parse(text) {
    Object(map) => map.get(key).unwrap()
    _ => abort("not an object")
  }
}

///|
test "a valid file renders to an svg" {
  let out = @web.render(rectangle, "none")
  assert_eq(field(out, "ok"), Json::boolean(true))
  match field(out, "svg") {
    String(svg) => assert_true(svg.has_prefix("<svg version=\"1.1\""))
    _ => fail("svg is not a string")
  }
  assert_eq(field(out, "warnings"), Json::array([]))
}

///|
test "invalid JSON is reported, not raised" {
  let out = @web.render("{bad", "none")
  assert_eq(field(out, "ok"), Json::boolean(false))
  match field(out, "error") {
    String(message) => assert_true(message.contains("not valid JSON"))
    _ => fail("error is not a string")
  }
}

///|
test "an element that cannot be drawn gives a warning" {
  let text =
    #|{"type":"excalidraw","version":2,"elements":[
    #|  {"type":"iframe","id":"i","x":0,"y":0,"width":50,"height":50,"seed":1},
    #|  {"type":"rectangle","id":"a","x":0,"y":0,"width":120,"height":60,"seed":1}
    #|]}
  let out = @web.render(text, "none")
  assert_eq(field(out, "ok"), Json::boolean(true))
  match field(out, "warnings") {
    Array(items) => assert_eq(items.length(), 1)
    _ => fail("warnings is not an array")
  }
}

///|
test "the url mode writes font rules and none does not" {
  let text =
    #|{"type":"excalidraw","version":2,"elements":[
    #|  {"type":"text","id":"t","x":0,"y":0,"width":40,"height":25,"text":"hi","originalText":"hi","fontSize":20,"fontFamily":5,"textAlign":"left","verticalAlign":"top","containerId":null,"lineHeight":1.25,"seed":1}
    #|]}
  let with_fonts = match field(@web.render(text, "url"), "svg") {
    String(svg) => svg
    _ => fail("no svg")
  }
  let without = match field(@web.render(text, "none"), "svg") {
    String(svg) => svg
    _ => fail("no svg")
  }
  assert_true(with_fonts.contains("@font-face"))
  assert_true(!without.contains("@font-face"))
}
