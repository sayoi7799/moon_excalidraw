// `excalidraw2site`: turns a folder of .excalidraw files into a small website.
// The work is in the site package; this reads the folder and writes the result.

///|
fn join(dir : String, name : String) -> String {
  if dir.has_suffix("/") || dir.has_suffix("\\") {
    dir + name
  } else {
    dir + "/" + name
  }
}

///|
/// Makes `path` and the folders above it, like `mkdir -p`.
fn make_dirs(path : String) -> Unit raise @fs.IOError {
  let parts = path.replace_all(old="\\", new="/").split("/").collect()
  let mut current = if path.has_prefix("/") { "/" } else { "" }
  for part in parts {
    if part == "" {
      continue
    }
    current = if current == "" || current.has_suffix("/") {
      current + part.to_owned()
    } else {
      current + "/" + part.to_owned()
    }
    // A drive such as `D:` is already there.
    if !part.has_suffix(":") && !@fs.path_exists(current) {
      @fs.create_dir(current)
    }
  }
}

///|
fn read_diagrams(dir : String) -> Array[@site.Diagram] raise @fs.IOError {
  let names = @fs.read_dir(dir).to_owned()
  names.sort()
  let diagrams : Array[@site.Diagram] = []
  for name in names {
    let path = join(dir, name)
    if name.has_suffix(".excalidraw") && @fs.is_file(path) {
      diagrams.push({ name, source: @fs.read_file_to_string(path), })
    }
  }
  diagrams
}

///|
fn parent_of(path : String) -> String {
  match path.rev_find("/") {
    Some(i) => path.clamped_view(end=i).to_owned()
    None => ""
  }
}

///|
fn fail(message : String) -> Unit {
  eprintln("error: \{message}")
  @sys.exit(1)
}

///|
fn main {
  let options = @site.parse_args(user_args()) catch {
    @site.Usage(message) => {
      eprintln("error: \{message}\n\n\{@site.usage()}")
      @sys.exit(2)
      return
    }
  }
  if options.help {
    println(@site.usage())
    return
  }
  let diagrams = read_diagrams(options.input) catch {
    @fs.IOError(message) => {
      fail("cannot read \{options.input}: \{message}")
      return
    }
  }
  if diagrams.length() == 0 {
    fail("no .excalidraw files in \{options.input}")
    return
  }
  let result = @site.build_site(
    diagrams,
    title=options.title,
    fonts=options.fonts,
  )
  for file in result.files {
    let path = join(options.output, file.path)
    make_dirs(parent_of(path)) catch {
      @fs.IOError(message) => {
        fail("cannot create \{parent_of(path)}: \{message}")
        return
      }
    }
    @fs.write_string_to_file(path, file.content) catch {
      @fs.IOError(message) => {
        fail("cannot write \{path}: \{message}")
        return
      }
    }
  }
  let failed = result.failures.length()
  let suffix = if failed > 0 { ", \{failed} failed" } else { "" }
  println(
    "wrote \{join(options.output, "index.html")}: \{diagrams.length() - failed} diagrams\{suffix}",
  )
  for f in result.failures {
    eprintln("error: \{f.name}: \{f.message}")
  }
  if failed > 0 {
    @sys.exit(1)
  }
}
