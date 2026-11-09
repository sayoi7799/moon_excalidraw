///|
test "site args: a folder and defaults" {
  let o = @site.parse_args(["diagrams"]) catch { e => abort("parse: \{e}") }
  assert_eq(o.input, "diagrams")
  assert_eq(o.output, "dist")
  assert_eq(o.title, "Diagrams")
  assert_eq(o.fonts, @export.FontMode::Url)
  assert_false(o.help)
}

///|
test "site args: every option" {
  let o = @site.parse_args([
    "--title", "My docs", "-o", "public", "diagrams", "--no-fonts",
  ]) catch {
    e => abort("parse: \{e}")
  }
  assert_eq(o.input, "diagrams")
  assert_eq(o.output, "public")
  assert_eq(o.title, "My docs")
  assert_eq(o.fonts, @export.FontMode::None)
}

///|
test "site args: --output=dir" {
  let o = @site.parse_args(["diagrams", "--output=out"]) catch {
    e => abort("parse: \{e}")
  }
  assert_eq(o.output, "out")
}

///|
test "site args: bad usage is refused" {
  let bad = [[], ["a", "b"], ["a", "--wat"], ["a", "-o"], ["a", "--title"]]
  for args in bad {
    assert_true(refuses(args), msg="should refuse \{args.join(" ")}")
  }
}

///|
fn refuses(args : Array[String]) -> Bool {
  ignore(@site.parse_args(args)) catch {
    _ => return true
  }
  false
}

///|
test "site args: help needs no folder" {
  let o = @site.parse_args(["--help"]) catch { e => abort("parse: \{e}") }
  assert_true(o.help)
}
