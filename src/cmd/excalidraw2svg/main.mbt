// `excalidraw2svg`: reads a .excalidraw file and writes the SVG the official
// exportToSvg would. The logic is in the cli package; this does the I/O.

///|
fn read_file(path : String) -> String raise @cli.CliError {
  @fs.read_file_to_string(path) catch {
    @fs.IOError(message) => raise @cli.Io(message)
  }
}

///|
fn write_file(path : String, text : String) -> Unit raise @cli.CliError {
  @fs.write_string_to_file(path, text) catch {
    @fs.IOError(message) => raise @cli.Io(message)
  }
}

///|
fn main {
  let result = @cli.run(user_args(), read_file, write_file)
  if result.stdout != "" {
    println(result.stdout)
  }
  if result.stderr != "" {
    eprintln(result.stderr)
  }
  if result.code != 0 {
    @sys.exit(result.code)
  }
}
