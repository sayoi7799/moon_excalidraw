///|
/// On Node the arguments start with the node binary and the script.
fn user_args() -> Array[String] {
  @env.args()[2:].to_array()
}
