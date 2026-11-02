// fdlibm's e_atan2.c as carried by V8 (src/base/ieee754.cc). See
// THIRD_PARTY_LICENSES for the fdlibm notice.

///|
fn high_word(x : Double) -> Int32 {
  (x.reinterpret_as_uint64() >> 32).to_uint().reinterpret_as_int()
}

///|
fn low_word(x : Double) -> UInt32 {
  x.reinterpret_as_uint64().to_uint()
}

///|
const TINY : Double = 1.0e-300

///|
const PI_O_4 : Double = 7.8539816339744827900E-01

///|
const PI_O_2 : Double = 1.5707963267948965580E+00

///|
const PI_VAL : Double = 3.1415926535897931160E+00

///|
const PI_LO : Double = 1.2246467991473531772E-16

///|
/// `Math.atan2(y, x)`.
pub fn atan2(y : Double, x : Double) -> Double {
  if x.is_nan() || y.is_nan() {
    return @double.not_a_number
  }
  let hx = high_word(x)
  let lx = low_word(x)
  let hy = high_word(y)
  let ly = low_word(y)
  let ix = hx & 0x7FFFFFFF
  let iy = hy & 0x7FFFFFFF
  if x == 1.0 {
    return @jsmath.atan(y)
  }
  let m = ((hy >> 31) & 1) | ((hx >> 30) & 2)
  if iy == 0 && ly == 0 {
    return match m {
      0 | 1 => y
      2 => PI_VAL + TINY
      _ => -PI_VAL - TINY
    }
  }
  if ix == 0 && lx == 0 {
    return if hy < 0 { -PI_O_2 - TINY } else { PI_O_2 + TINY }
  }
  if ix == 0x7FF00000 {
    if iy == 0x7FF00000 {
      return match m {
        0 => PI_O_4 + TINY
        1 => -PI_O_4 - TINY
        2 => 3.0 * PI_O_4 + TINY
        _ => -3.0 * PI_O_4 - TINY
      }
    } else {
      return match m {
        0 => 0.0
        1 => -0.0
        2 => PI_VAL + TINY
        _ => -PI_VAL - TINY
      }
    }
  }
  if iy == 0x7FF00000 {
    return if hy < 0 { -PI_O_2 - TINY } else { PI_O_2 + TINY }
  }
  let k = (iy - ix) >> 20
  let mut m = m
  let z = if k > 60 {
    m = m & 1
    PI_O_2 + 0.5 * PI_LO
  } else if hx < 0 && k < -60 {
    0.0
  } else {
    @jsmath.atan((y / x).abs())
  }
  match m {
    0 => z
    1 => -z
    2 => PI_VAL - (z - PI_LO)
    _ => z - PI_LO - PI_VAL
  }
}
