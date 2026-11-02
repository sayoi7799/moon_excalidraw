// The command line behaviour, tested with a fake file system so it runs on every
// backend (wasm-gc can't read files).

///|
const RECT : String = "{\"type\":\"excalidraw\",\"elements\":[{\"id\":\"r\",\"type\":\"rectangle\",\"x\":0,\"y\":0,\"width\":100,\"height\":50,\"seed\":7}]}"

///|
const EMBED : String = "{\"type\":\"excalidraw\",\"elements\":[{\"id\":\"e\",\"type\":\"embeddable\",\"x\":0,\"y\":0,\"width\":10,\"height\":10}]}"

///|
fn reader(
  files : Map[String, String],
) -> (String) -> String raise @cli.CliError {
  fn(path) {
    match files.get(path) {
      Some(text) => text
      None => raise @cli.Io("no such file")
    }
  }
}

///|
fn writer(
  written : Map[String, String],
) -> (String, String) -> Unit raise @cli.CliError {
  fn(path, text) { written[path] = text }
}

///|
fn run(
  args : Array[String],
  files : Map[String, String],
  written : Map[String, String],
) -> @cli.CliResult {
  @cli.run(args, reader(files), writer(written))
}

///|
test "parse_args reads input, output and flags" {
  let o = @cli.parse_args([
    "a.excalidraw", "-o", "out.svg", "--no-fonts", "--strict",
  ]) catch {
    e => abort("should parse: \{e}")
  }
  assert_eq(o.input, "a.excalidraw")
  assert_eq(o.output, Some("out.svg"))
  assert_eq(o.fonts, @export.FontMode::None)
  assert_true(o.strict)
}

///|
test "parse_args defaults" {
  let o = @cli.parse_args(["a.excalidraw"]) catch {
    e => abort("should parse: \{e}")
  }
  assert_eq(o.output, None)
  assert_eq(o.fonts, @export.FontMode::Url)
  assert_false(o.strict)
  assert_false(o.help)
}

///|
test "parse_args accepts --output=file and flags before the input" {
  let o = @cli.parse_args(["--no-fonts", "--output=x.svg", "in.excalidraw"]) catch {
    e => abort("should parse: \{e}")
  }
  assert_eq(o.input, "in.excalidraw")
  assert_eq(o.output, Some("x.svg"))
}

///|
test "parse_args rejects bad usage" {
  let bad = [[], ["a", "b"], ["a", "--wat"], ["a", "-o"], ["-o", "--strict"]]
  for args in bad {
    let r = Ok(@cli.parse_args(args)) catch { e => Err(e) }
    assert_true(r is Err(@cli.Usage(_)), msg="should reject \{args}")
  }
}

///|
test "help prints the usage and succeeds" {
  let r = run(["--help"], {}, {})
  assert_eq(r.code, 0)
  assert_true(r.stdout.contains("excalidraw2svg"))
  assert_eq(r.stderr, "")
}

///|
test "converts a file to stdout" {
  let r = run(["a.excalidraw", "--no-fonts"], { "a.excalidraw": RECT }, {})
  assert_eq(r.code, 0)
  assert_true(r.stdout.has_prefix("<svg version=\"1.1\""))
  assert_eq(r.stderr, "")
}

///|
test "writes to the output file when asked" {
  let written = {}
  let r = run(
    ["a.excalidraw", "-o", "out.svg", "--no-fonts"],
    { "a.excalidraw": RECT },
    written,
  )
  assert_eq(r.code, 0)
  assert_eq(r.stdout, "")
  assert_true(written.get("out.svg").unwrap_or("").has_prefix("<svg"))
}

///|
test "a missing file fails with a message" {
  let r = run(["gone.excalidraw"], {}, {})
  assert_eq(r.code, 1)
  assert_true(r.stderr.contains("gone.excalidraw"))
  assert_eq(r.stdout, "")
}

///|
test "invalid json fails with a message" {
  let r = run(["a.excalidraw"], { "a.excalidraw": "{oops" }, {})
  assert_eq(r.code, 1)
  assert_true(r.stderr.contains("not valid JSON"))
}

///|
test "a file that is not a scene fails with a message" {
  let r = run(["a.excalidraw"], { "a.excalidraw": "[1,2]" }, {})
  assert_eq(r.code, 1)
  assert_true(r.stderr.contains("error"))
}

///|
test "an unsupported element is skipped with a warning by default" {
  let r = run(["a.excalidraw", "--no-fonts"], { "a.excalidraw": EMBED }, {})
  assert_eq(r.code, 0)
  assert_true(r.stderr.contains("warning"))
  assert_true(r.stderr.contains("e"))
  assert_true(r.stdout.has_prefix("<svg"))
}

///|
test "--strict fails on an unsupported element" {
  let r = run(["a.excalidraw", "--strict"], { "a.excalidraw": EMBED }, {})
  assert_eq(r.code, 1)
  assert_true(r.stderr.contains("embeddable"))
  assert_eq(r.stdout, "")
}

///|
test "bad usage exits with code 2 and shows the usage" {
  let r = run(["--wat"], {}, {})
  assert_eq(r.code, 2)
  assert_true(r.stderr.contains("Usage"))
}
