///|
/// Natively the arguments start with the program itself.
fn user_args() -> Array[String] {
  @env.args()[1:].to_owned()
}
