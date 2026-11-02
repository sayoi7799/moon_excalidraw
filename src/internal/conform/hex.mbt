// Bit-exact doubles as written by scripts/gen_fixtures.mjs.

///|
/// Decodes 16 hex digits (an IEEE-754 bit pattern) into a double.
pub fn hex_to_double(s : StringView) -> Double {
  guard s.length() == 16 else { abort("bad hex double: \{s}") }
  let mut bits : UInt64 = 0
  for c in s {
    let digit = if c >= '0' && c <= '9' {
      c.to_int() - '0'.to_int()
    } else if c >= 'a' && c <= 'f' {
      c.to_int() - 'a'.to_int() + 10
    } else {
      abort("bad hex digit in \{s}")
    }
    bits = (bits << 4) | digit.to_uint64()
  }
  bits.reinterpret_as_double()
}

///|
/// True when both doubles have the same bit pattern, so NaN matches NaN and
/// 0.0 differs from -0.0.
pub fn same_bits(a : Double, b : Double) -> Bool {
  (a.is_nan() && b.is_nan()) ||
  a.reinterpret_as_int64() == b.reinterpret_as_int64()
}
