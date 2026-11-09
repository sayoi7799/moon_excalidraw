// The logic of the `excalidraw2svg` command, apart from touching the file system
// and the process, which the caller supplies. That keeps it testable on every
// backend.

///|
#derive(Debug)
pub(all) suberror CliError {
  /// The command line is wrong.
  Usage(String)
  /// A file couldn't be read or written.
  Io(String)
}

///|
pub impl Show for CliError with fn output(self, logger) {
  match self {
    Usage(message) => logger.write_string(message)
    Io(message) => logger.write_string(message)
  }
}

///|
pub(all) struct CliOptions {
  input : String
  output : String?
  fonts : @export.FontMode
  strict : Bool
  help : Bool
}

///|
pub(all) struct CliResult {
  code : Int32
  stdout : String
  stderr : String
}

///|
pub fn usage() -> String {
  "Usage: excalidraw2svg <input.excalidraw> [options]\n\nRenders an Excalidraw file to SVG, like the official exportToSvg.\n\nOptions:\n  -o, --output <file>  Write the SVG to a file instead of printing it\n  --no-fonts           Leave the font rules out of the SVG\n  --strict             Fail on elements that can't be drawn (embeddables,\n                       iframes, elbow arrows) instead of skipping them\n  -h, --help           Show this help\n\nSkipped elements and other things that won't match the official export are\nreported on stderr as warnings."
}

///|
/// Reads the command line, without the program name.
pub fn parse_args(args : Array[String]) -> CliOptions raise CliError {
  let mut input : String? = None
  let mut output : String? = None
  let mut fonts : @export.FontMode = Url
  let mut strict = false
  let mut help = false
  let mut i = 0
  while i < args.length() {
    let arg = args[i]
    if arg == "-h" || arg == "--help" {
      help = true
    } else if arg == "--no-fonts" {
      fonts = None
    } else if arg == "--strict" {
      strict = true
    } else if arg == "-o" || arg == "--output" {
      if i + 1 >= args.length() || args[i + 1].has_prefix("-") {
        raise Usage("\{arg} needs a file name")
      }
      output = Some(args[i + 1])
      i += 1
    } else if arg.has_prefix("--output=") {
      output = Some(arg.clamped_view(start="--output=".length()).to_owned())
    } else if arg.has_prefix("-") {
      raise Usage("unknown option \{arg}")
    } else if input is Some(_) {
      raise Usage("only one input file is allowed")
    } else {
      input = Some(arg)
    }
    i += 1
  }
  if help {
    return { input: "", output, fonts, strict, help, }
  }
  match input {
    Some(input) => { input, output, fonts, strict, help, }
    None => raise Usage("no input file")
  }
}

///|
fn describe(e : @model.ParseError) -> String {
  match e {
    InvalidJson(message) => "the file is not valid JSON (\{message})"
    NotAScene(message) => "the file is not an Excalidraw scene: \{message}"
    InvalidElement(id, message) => "element \"\{id}\" is damaged: \{message}"
  }
}

///|
fn failure(code : Int32, message : String) -> CliResult {
  { code, stdout: "", stderr: "error: \{message}", }
}

///|
/// Runs the command. `read_file` and `write_file` do the file access.
pub fn run(
  args : Array[String],
  read_file : (String) -> String raise CliError,
  write_file : (String, String) -> Unit raise CliError,
) -> CliResult {
  let options = parse_args(args) catch {
    Usage(message) => return failure(2, message + "\n\n" + usage())
    e => return failure(2, Show::to_string(e))
  }
  if options.help {
    return { code: 0, stdout: usage(), stderr: "", }
  }
  let text = read_file(options.input) catch {
    Io(message) => return failure(1, "cannot read \{options.input}: \{message}")
    Usage(message) => return failure(1, message)
  }
  let scene = @model.parse_scene(text) catch {
    e => return failure(1, describe(e))
  }
  let policy : @export.UnsupportedPolicy = if options.strict {
    Error
  } else {
    SkipWithWarning
  }
  let result = @export.export_to_svg(
    scene,
    fonts=options.fonts,
    on_unsupported=policy,
  ) catch {
    @export.Unsupported(id, reason) =>
      return failure(1, "element \"\{id}\": \{reason}")
  }
  let warnings = result.warnings
    .map(fn(w) {
      match w.element_id {
        Some(id) => "warning: element \"\{id}\": \{w.message}"
        None => "warning: \{w.message}"
      }
    })
    .join("\n")
  match options.output {
    Some(path) => {
      write_file(path, result.svg) catch {
        Io(message) => return failure(1, "cannot write \{path}: \{message}")
        Usage(message) => return failure(1, message)
      }
      { code: 0, stdout: "", stderr: warnings, }
    }
    None => { code: 0, stdout: result.svg, stderr: warnings, }
  }
}
