///|
test "text and attributes escape like outerHTML" {
  for case in @fixtures.svg_cases {
    let g = @svg.Node::element("g")
    g.set("a", case.0)
    g.append(@svg.Node::text(case.0))
    assert_eq(g.to_html(), case.1)
  }
}

///|
test "style text is escaped like any SVG element" {
  let s = @svg.Node::element("style")
  s.append(@svg.Node::text("a > b & c"))
  assert_eq(s.to_html(), @fixtures.svg_style_case)
}

///|
test "comments, order and overwriting attributes" {
  let root = @svg.Node::element("svg")
  root.set("x", "1")
  root.set("y", "2")
  root.set("x", "3")
  root.append(@svg.Node::comment(" c "))
  let later = @svg.Node::element("path")
  root.append(later)
  root.prepend(@svg.Node::element("defs"))
  assert_eq(root.to_html(), @fixtures.svg_tree_case)
}
