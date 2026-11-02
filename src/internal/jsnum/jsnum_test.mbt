///|
/// Each case is "<hex a> <hex b> <hex expected>".
fn check_binary(
  name : String,
  cases : Array[String],
  f : (Double, Double) -> Double,
) -> Unit raise {
  let mut bad = 0
  for line in cases {
    guard line.split(" ").collect() is [a, b, r] else { fail("bad line") }
    let got = f(@conform.hex_to_double(a), @conform.hex_to_double(b))
    if !@conform.same_bits(got, @conform.hex_to_double(r)) {
      if bad == 0 {
        println("\{name} first mismatch: \{line} got \{got}")
      }
      bad += 1
    }
  }
  println("[jsnum] \{name}: total=\{cases.length()} mismatched=\{bad}")
  assert_eq(bad, 0)
}

///|
test "hypot matches V8" {
  check_binary("hypot", @fixtures.hypot_cases, @jsnum.hypot)
}

///|
test "atan2 matches V8" {
  check_binary("atan2", @fixtures.atan2_cases, @jsnum.atan2)
}

///|
test "cube is correctly rounded" {
  check_binary("cube", @fixtures.cube_cases, fn(x, _) { @jsnum.cube(x) })
}

///|
test "parse_float matches parseFloat" {
  let mut bad = 0
  for line in @fixtures.parse_float_cases {
    // Each case is a JSON string literal, a bar, and the result's bit pattern.
    let bar = line.rev_find("|").unwrap()
    let parsed = @json.parse(line[0:bar]) catch { _ => abort("bad literal") }
    guard parsed is String(text) else { abort("not a string") }
    let got = @jsnum.parse_float(text)
    if !@conform.same_bits(got, @conform.hex_to_double(line[bar + 1:])) {
      println("parse_float mismatch for {line}: got {got}")
      bad += 1
    }
  }
  assert_eq(bad, 0)
}
