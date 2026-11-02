// JavaScript's `parseFloat`. moon_rough's `jsmath.parse_float` is a strict number
// parser for path data and rejects trailing text, so it can't stand in for this.

///|
/// `StrWhiteSpaceChar`: white space and line terminators.
fn is_space(c : Char) -> Bool {
  match c {
    '\t' | '\n' | '\u{0B}' | '\u{0C}' | '\r' | ' ' | '\u{A0}' | '\u{1680}' =>
      true
    '\u{2000}'..<='\u{200A}'
    | '\u{2028}'
    | '\u{2029}'
    | '\u{202F}'
    | '\u{205F}'
    | '\u{3000}'
    | '\u{FEFF}' => true
    _ => false
  }
}

///|
fn is_digit(c : Char) -> Bool {
  c >= '0' && c <= '9'
}

///|
/// The digits starting at `from`, and the index after them.
fn digits_from(chars : Array[Char], from : Int32) -> (String, Int32) {
  let out = StringBuilder()
  let mut i = from
  while i < chars.length() && is_digit(chars[i]) {
    out.write_char(chars[i])
    i += 1
  }
  (out.to_string(), i)
}

///|
/// `parseFloat(s)`: the longest leading decimal literal, or NaN when there is
/// none.
pub fn parse_float(s : String) -> Double {
  let chars = s.to_array()
  let n = chars.length()
  let mut i = 0
  while i < n && is_space(chars[i]) {
    i += 1
  }
  let mut negative = false
  if i < n && (chars[i] == '+' || chars[i] == '-') {
    negative = chars[i] == '-'
    i += 1
  }
  let infinity = "Infinity".to_array()
  if i + infinity.length() <= n &&
    chars[i:i + infinity.length()].to_owned() == infinity {
    return if negative { @double.neg_infinity } else { @double.infinity }
  }
  let (int_part, after_int) = digits_from(chars, i)
  i = after_int
  let mut frac = ""
  if i < n && chars[i] == '.' {
    let (digits, after) = digits_from(chars, i + 1)
    // A lone "." isn't a number, but "5." is.
    if int_part != "" || digits != "" {
      frac = digits
      i = after
    }
  }
  if int_part == "" && frac == "" {
    return @double.not_a_number
  }
  let mut exponent = ""
  if i < n && (chars[i] == 'e' || chars[i] == 'E') {
    let mut j = i + 1
    let mut sign = ""
    if j < n && (chars[j] == '+' || chars[j] == '-') {
      sign = chars[j].to_string()
      j += 1
    }
    let (digits, _) = digits_from(chars, j)
    if digits != "" {
      exponent = "e" + sign + digits
    }
  }
  let text = (if int_part == "" { "0" } else { int_part }) +
    "." +
    (if frac == "" { "0" } else { frac }) +
    exponent
  let value = @jsmath.parse_float(text)
  if negative {
    -value
  } else {
    value
  }
}
