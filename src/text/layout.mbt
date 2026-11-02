// How text is split and which way it reads.

///|
/// `text.replace(/\r\n?/g, "\n").split("\n")`.
pub fn split_lines(text : String) -> Array[String] {
  let lines = []
  let current = StringBuilder::new()
  let chars = text.to_array()
  let mut i = 0
  while i < chars.length() {
    let c = chars[i]
    if c == '\r' || c == '\n' {
      lines.push(current.to_string())
      current.reset()
      if c == '\r' && i + 1 < chars.length() && chars[i + 1] == '\n' {
        i += 1
      }
    } else {
      current.write_char(c)
    }
    i += 1
  }
  lines.push(current.to_string())
  lines
}

///|
/// The characters upstream's `RS_LTR_CHARS` matches, as UTF-16 code units, which
/// is how the JavaScript regular expression sees the text. Surrogates fall in
/// the U+2C00 to U+FB1C range, so emoji read as left-to-right.
fn is_ltr_unit(u : Int32) -> Bool {
  (u >= 0x41 && u <= 0x5A) ||
  (u >= 0x61 && u <= 0x7A) ||
  (u >= 0xC0 && u <= 0xD6) ||
  (u >= 0xD8 && u <= 0xF6) ||
  (u >= 0xF8 && u <= 0x2B8) ||
  (u >= 0x300 && u <= 0x590) ||
  (u >= 0x800 && u <= 0x1FFF) ||
  (u >= 0x2C00 && u <= 0xFB1C) ||
  (u >= 0xFDFE && u <= 0xFE6F) ||
  u >= 0xFEFD
}

///|
fn is_rtl_unit(u : Int32) -> Bool {
  (u >= 0x591 && u <= 0x7FF) ||
  (u >= 0xFB1D && u <= 0xFDFD) ||
  (u >= 0xFE70 && u <= 0xFEFC)
}

///|
/// `isRTL`: whether the first strongly directional character is right-to-left.
/// Upstream's regular expression, `^[^LTR]*[RTL]`, finds an RTL character before
/// any LTR one.
pub fn is_rtl(text : String) -> Bool {
  for i in 0..<text.length() {
    let u = text.code_unit_at(i).to_int()
    if is_rtl_unit(u) {
      return true
    }
    if is_ltr_unit(u) {
      return false
    }
  }
  false
}
