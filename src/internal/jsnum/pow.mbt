// Excalidraw only calls Math.pow with exponents 2 and 3. V8 turns x ** 2 into
// x * x, so that needs no helper. x ** 3 goes to the platform's std::pow, whose
// last bit depends on the C library, so no port can match every platform; this
// computes the correctly rounded cube, which is what those libraries aim for.

///|
const SPLITTER : Double = 134217729.0

///|
/// The product a * b as a rounded value and its exact error (Dekker).
fn two_product(a : Double, b : Double) -> (Double, Double) {
  let p = a * b
  let t = SPLITTER * a
  let a_hi = t - (t - a)
  let a_lo = a - a_hi
  let t = SPLITTER * b
  let b_hi = t - (t - b)
  let b_lo = b - b_hi
  (p, a_lo * b_lo - (p - a_hi * b_hi - a_lo * b_hi - a_hi * b_lo))
}

///|
/// `x * x * x`, correctly rounded for ordinary magnitudes.
pub fn cube(x : Double) -> Double {
  let a = x.abs()
  // Outside this range the splitting would overflow or lose bits to underflow.
  if a.is_nan() || a == 0.0 || a > 1.0e90 || a < 1.0e-90 {
    return x * x * x
  }
  let (h, l) = two_product(x, x)
  let (p, e) = two_product(h, x)
  p + (e + l * x)
}
