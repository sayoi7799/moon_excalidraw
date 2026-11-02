///|
test "hex_to_double decodes bit patterns" {
  assert_eq(@conform.hex_to_double("3ff0000000000000"), 1.0)
  assert_eq(@conform.hex_to_double("c000000000000000"), -2.0)
}

///|
test "json double parse matches V8" {
  let mut bad = 0
  for line in json_doubles {
    guard line.split("|").collect() is [text, hex] else { abort("bad line") }
    let parsed = @json.parse(text) catch { _ => abort("parse") }
    guard parsed is Number(v, ..) else { abort("not a number") }
    if !@conform.same_bits(v, @conform.hex_to_double(hex)) {
      bad += 1
    }
  }
  println("[json doubles] total=\{json_doubles.length()} mismatched=\{bad}")
  assert_eq(bad, 0)
}
