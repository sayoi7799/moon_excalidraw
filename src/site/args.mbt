// The command line of `excalidraw2site`.

///|
pub suberror UsageError {
  Usage(String)
} derive(Debug)

///|
pub impl Show for UsageError with fn output(self, logger) {
  match self {
    Usage(message) => logger.write_string(message)
  }
}

///|
pub(all) struct SiteOptions {
  input : String
  output : String
  title : String
  fonts : @export.FontMode
  help : Bool
}

///|
pub fn usage() -> String {
  "Usage: excalidraw2site <folder> [options]\n\nRenders every .excalidraw file in <folder> and writes a web page that shows them all.\n\nOptions:\n  -o, --output <dir>  Where to write the site (default: dist)\n  --title <text>      The page title (default: Diagrams)\n  --no-fonts          Leave the font rules out of the SVG files\n  -h, --help          Show this help\n\nThe site is index.html, an svg/ folder with one SVG per diagram, and a src/\nfolder with a copy of each .excalidraw file. Files that can't be rendered are\nlisted on the page and make the command exit with an error."
}

///|
pub fn parse_args(args : Array[String]) -> SiteOptions raise UsageError {
  let mut input : String? = None
  let mut output = "dist"
  let mut title = "Diagrams"
  let mut fonts : @export.FontMode = Url
  let mut help = false
  let mut i = 0
  while i < args.length() {
    let arg = args[i]
    if arg == "-h" || arg == "--help" {
      help = true
    } else if arg == "--no-fonts" {
      fonts = None
    } else if arg == "-o" || arg == "--output" {
      if i + 1 >= args.length() || args[i + 1].has_prefix("-") {
        raise Usage("\{arg} needs a folder name")
      }
      output = args[i + 1]
      i += 1
    } else if arg.has_prefix("--output=") {
      output = arg.view(start_offset="--output=".length()).to_owned()
    } else if arg == "--title" {
      if i + 1 >= args.length() {
        raise Usage("--title needs some text")
      }
      title = args[i + 1]
      i += 1
    } else if arg.has_prefix("-") {
      raise Usage("unknown option \{arg}")
    } else if input is Some(_) {
      raise Usage("only one folder is allowed")
    } else {
      input = Some(arg)
    }
    i += 1
  }
  if help {
    return { input: "", output, title, fonts, help, }
  }
  match input {
    Some(input) => { input, output, title, fonts, help, }
    None => raise Usage("no folder given")
  }
}
