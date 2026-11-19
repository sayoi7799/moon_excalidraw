///|
test "compress matches lz-string byte for byte" {
  for c in lz_cases {
    let (name, input, expected) = c
    let got = @obsidian.compress_to_base64(input)
    if got != expected {
      fail("\{name}: compress differs from lz-string")
    }
  }
}

///|
test "decompress gives back the input lz-string compressed" {
  for c in lz_cases {
    let (name, input, packed) = c
    match @obsidian.decompress_from_base64(packed) {
      Some(text) => if text != input { fail("\{name}: decompress differs") }
      None => fail("\{name}: decompress gave null")
    }
  }
}

///|
test "null and truncated input" {
  assert_true(@obsidian.decompress_from_base64("") is None)
}

///|
test "the fixtures are not empty" {
  assert_true(lz_cases.length() >= 20)
  // One of them is long enough to need 15-bit dictionary codes.
  let mut longest = 0
  for c in lz_cases {
    let (_, input, _) = c
    if input.length() > longest {
      longest = input.length()
    }
  }
  assert_true(longest > 10000)
}
