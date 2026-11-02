///|
test "identical strings" {
  assert_eq(@conform.classify("<a b=\"1\"></a>", "<a b=\"1\"></a>"), Identical)
}

///|
test "different elements are structural" {
  assert_eq(@conform.classify("<a></a>", "<b></b>"), Structural)
}

///|
test "different attribute names are structural" {
  assert_eq(@conform.classify("<a x=\"1\"></a>", "<a y=\"1\"></a>"), Structural)
}

///|
test "different attribute text is an attribute difference" {
  assert_eq(
    @conform.classify("<a x=\"red\"></a>", "<a x=\"blue\"></a>"),
    Attribute,
  )
}

///|
test "number differences report the largest delta" {
  assert_eq(
    @conform.classify(
      "<a x=\"1.5 -2\" y=\"3e2\"></a>", "<a x=\"1.25 -2\" y=\"300\"></a>",
    ),
    Numeric(0.25),
  )
  assert_eq(
    @conform.classify("<a x=\"1.5 -2\"></a>", "<a x=\"1.25 -3\"></a>"),
    Numeric(1.0),
  )
}

///|
test "run counts results and matching errors" {
  let cases : Array[@fixtures.SceneCase] = [
    { name: "same", input: "a", fonts: "none", expected: Some("<a></a>"), },
    { name: "diff", input: "b", fonts: "none", expected: Some("<a></a>"), },
    { name: "both fail", input: "c", fonts: "none", expected: None, },
    {
      name: "only we fail",
      input: "d",
      fonts: "none",
      expected: Some("<a></a>"),
    },
  ]
  let stats = @conform.run("t", cases, fn(c) {
    match c.input {
      "a" => Some("<a></a>")
      "b" => Some("<b></b>")
      _ => None
    }
  })
  assert_eq(stats.total, 4)
  assert_eq(stats.identical, 2)
  assert_eq(stats.failed, 2)
  assert_eq(stats.structural, 2)
  assert_eq(stats.failures, ["diff", "only we fail"])
}
