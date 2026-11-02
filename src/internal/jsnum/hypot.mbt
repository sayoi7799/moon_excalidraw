// Math functions moon_rough's jsmath doesn't have, bit-identical to V8.

///|
/// `Math.hypot(a, b)`. V8's two-argument fast path scales by the larger value
/// and sums plainly; it isn't the Kahan loop used for more arguments.
pub fn hypot(a : Double, b : Double) -> Double {
  let a = a.abs()
  let b = b.abs()
  if a == @double.infinity || b == @double.infinity {
    return @double.infinity
  }
  if a.is_nan() || b.is_nan() {
    return @double.not_a_number
  }
  let max = if a > b { a } else { b }
  if max == 0.0 {
    return 0.0
  }
  let x = a / max
  let y = b / max
  (x * x + y * y).sqrt() * max
}
