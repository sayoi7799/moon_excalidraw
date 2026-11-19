///|
/// "id|text" entries joined by U+0001, as the fixture generator writes them.
fn pairs_of(joined : String) -> Map[String, String] {
  let out : Map[String, String] = Map([])
  if joined == "" {
    return out
  }
  for entry in joined.split("\u{1}") {
    let entry = entry.to_owned()
    match entry.find("|") {
      Some(i) =>
        out[entry.clamped_view(end=i).to_owned()] = entry
          .clamped_view(start=i + 1)
          .to_owned()
      None => ()
    }
  }
  out
}

///|
test "the drawing read from each file is the scene's JSON, byte for byte" {
  for c in obsidian_files {
    let (name, md, json, _, _) = c
    let found = @obsidian.extract(md) catch { err => fail("\{name}: \{err}") }
    if found.json != json {
      fail("\{name}: the drawing differs from the scene it was made from")
    }
  }
}

///|
test "the Text Elements and Embedded Files sections are read" {
  for c in obsidian_files {
    let (name, md, _, texts, embedded) = c
    let found = @obsidian.extract(md)
    let want = pairs_of(texts)
    assert_eq(found.texts.length(), want.length())
    for id, text in want {
      if found.texts.get(id) != Some(text) {
        fail("\{name}: text \{id} was not read back")
      }
    }
    let want_files = pairs_of(embedded)
    assert_eq(found.embedded.length(), want_files.length())
    for id, path in want_files {
      if found.embedded.get(id) != Some(path) {
        fail("\{name}: embedded file \{id} was not read back")
      }
    }
  }
}

///|
test "the front matter says whether texts are parsed" {
  let mut parsed = 0
  for c in obsidian_files {
    let (name, md, _, _, _) = c
    if @obsidian.extract(md).parsed_mode {
      parsed += 1
      assert_true(name.contains("parsed mode"))
    }
  }
  assert_eq(parsed, 1)
}

///|
test "every fixture is a Markdown file and a bare scene is not" {
  for c in obsidian_files {
    let (_, md, json, _, _) = c
    assert_true(@obsidian.looks_like_markdown(md))
    assert_true(!@obsidian.looks_like_markdown(json))
  }
  assert_true(!@obsidian.looks_like_markdown("  \n{\"elements\": []}"))
  assert_true(!@obsidian.looks_like_markdown("not json and not markdown"))
}

///|
fn refuses(text : String) -> String {
  try @obsidian.extract(text) catch {
    @obsidian.Message(message) => message
  } noraise {
    _ => "no error"
  }
}

///|
test "damaged files are reported, not raised through" {
  assert_true(
    refuses("# Excalidraw Data\n\n## Text Elements\n").contains(
      "no \"## Drawing\"",
    ),
  )
  assert_true(
    refuses("## Drawing\n```compressed-json\nnot base64 !!\n```\n").contains(
      "not Base64",
    ),
  )
  assert_true(
    refuses("## Drawing\n```compressed-json\nQUJD\n```\n").contains("damaged") ||
    refuses("## Drawing\n```compressed-json\nQUJD\n```\n").contains(
      "does not contain",
    ),
  )
  assert_true(
    refuses("## Drawing\n```json\nno scene here\n```\n").contains(
      "does not contain a scene",
    ),
  )
  assert_true(refuses("## Drawing\n").contains("no drawing"))
  assert_true(refuses("").contains("no \"## Drawing\""))
}

///|
test "a plain json fence and a drawing without fences are read" {
  let scene = "{\"type\":\"excalidraw\",\"elements\":[]}"
  assert_eq(
    @obsidian.extract("## Drawing\n```json\n\{scene}\n```\n%%").json,
    scene,
  )
  assert_eq(@obsidian.extract("## Drawing\n\{scene}\n%%\n").json, scene)
  // The compressed data on its own line, with no fence, as a hand edit leaves it.
  let packed = @obsidian.compress_to_base64(scene)
  assert_eq(@obsidian.extract("## Drawing\n\{packed}\n%%\n").json, scene)
}

///|
test "text lines before the id belong to the same element" {
  let md = "## Text Elements\nfirst\nsecond ^abcdefgh\n\nthird ^12345678\n\n%%\n## Drawing\n{}\n"
  let found = @obsidian.extract(md)
  assert_eq(found.texts.get("abcdefgh"), Some("first\nsecond"))
  assert_eq(found.texts.get("12345678"), Some("third"))
}
