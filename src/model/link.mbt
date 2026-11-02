// `normalizeLink` of Excalidraw's data/url.ts and the `sanitizeUrl` it calls from
// @braintree/sanitize-url 6.0.2 (MIT). The upstream regexes are written out by
// hand because the core library has no regex engine.

///|
fn is_js_space(c : Char) -> Bool {
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
/// `String.prototype.trim`.
pub fn js_trim(s : String) -> String {
  let chars = s.to_array()
  let mut start = 0
  let mut end = chars.length()
  while start < end && is_js_space(chars[start]) {
    start += 1
  }
  while end > start && is_js_space(chars[end - 1]) {
    end -= 1
  }
  String::from_array(chars[start:end].to_owned())
}

///|
fn is_word(c : Char) -> Bool {
  (c >= 'a' && c <= 'z') ||
  (c >= 'A' && c <= 'Z') ||
  (c >= '0' && c <= '9') ||
  c == '_'
}

///|
/// JavaScript's `Number(s)` for a `\w+` token, then `String.fromCharCode`:
/// decimal or 0x/0o/0b integers; anything else is NaN, which becomes U+0000.
fn char_from_entity(token : Array[Char]) -> Char {
  let (radix, digits) = if token.length() > 2 && token[0] == '0' {
    match token[1] {
      'x' | 'X' => (16, token[2:].to_owned())
      'o' | 'O' => (8, token[2:].to_owned())
      'b' | 'B' => (2, token[2:].to_owned())
      _ => (10, token)
    }
  } else {
    (10, token)
  }
  let mut code = 0
  for c in digits {
    let d = match c {
      '0'..<='9' => c.to_int() - '0'.to_int()
      'a'..<='f' => c.to_int() - 'a'.to_int() + 10
      'A'..<='F' => c.to_int() - 'A'.to_int() + 10
      _ => return '\u{0}'
    }
    if d >= radix {
      return '\u{0}'
    }
    code = (code * radix + d) & 0xFFFF
  }
  // Lone surrogates can't be held in a Char; they sanitise to nothing useful.
  if code >= 0xD800 && code <= 0xDFFF {
    return '\u{FFFD}'
  }
  code.unsafe_to_char()
}

///|
/// `/&#(\w+)(^\w|;)?/g` replaced by the character it names.
fn decode_html_characters(chars : Array[Char]) -> Array[Char] {
  let out = []
  let mut i = 0
  while i < chars.length() {
    if chars[i] == '&' &&
      i + 2 < chars.length() &&
      chars[i + 1] == '#' &&
      is_word(chars[i + 2]) {
      let mut j = i + 2
      while j < chars.length() && is_word(chars[j]) {
        j += 1
      }
      out.push(char_from_entity(chars[i + 2:j].to_owned()))
      i = if j < chars.length() && chars[j] == ';' { j + 1 } else { j }
    } else {
      out.push(chars[i])
      i += 1
    }
  }
  out
}

///|
fn starts_with_ci(chars : Array[Char], at : Int32, word : String) -> Bool {
  let w = word.to_array()
  if at + w.length() > chars.length() {
    return false
  }
  for i, c in w {
    let x = chars[at + i]
    let lower = if x >= 'A' && x <= 'Z' {
      (x.to_int() + 32).unsafe_to_char()
    } else {
      x
    }
    if lower != c {
      return false
    }
  }
  true
}

///|
/// `/&(newline|tab);/gi` removed.
fn remove_control_entities(chars : Array[Char]) -> Array[Char] {
  let out = []
  let mut i = 0
  while i < chars.length() {
    if chars[i] == '&' && starts_with_ci(chars, i + 1, "newline;") {
      i += 9
    } else if chars[i] == '&' && starts_with_ci(chars, i + 1, "tab;") {
      i += 5
    } else {
      out.push(chars[i])
      i += 1
    }
  }
  out
}

///|
fn is_control(c : Char) -> Bool {
  match c {
    '\u{0}'..<='\u{1F}'
    | '\u{7F}'..<='\u{9F}'
    | '\u{2000}'..<='\u{200D}'
    | '\u{FEFF}' => true
    _ => false
  }
}

///|
/// The first match of `/^.+(:|&colon;)/m`: on the first line holding a colon
/// after at least one character, everything up to the last colon of that line.
fn url_scheme(chars : Array[Char]) -> Array[Char]? {
  let mut line_start = 0
  while line_start <= chars.length() {
    let mut line_end = line_start
    while line_end < chars.length() &&
          chars[line_end] != '\u{2028}' &&
          chars[line_end] != '\u{2029}' {
      line_end += 1
    }
    let mut i = line_end - 1
    while i > line_start {
      if chars[i] == ':' {
        return Some(chars[line_start:i + 1].to_owned())
      }
      if chars[i] == ';' &&
        i >= line_start + 7 &&
        matches_at(chars, i - 6, "&colon") {
        return Some(chars[line_start:i + 1].to_owned())
      }
      i -= 1
    }
    line_start = line_end + 1
  }
  None
}

///|
fn matches_at(chars : Array[Char], at : Int32, word : String) -> Bool {
  let w = word.to_array()
  for i, c in w {
    if chars[at + i] != c {
      return false
    }
  }
  true
}

///|
/// `/^([^\w]*)(javascript|data|vbscript)/im`.
fn has_invalid_protocol(scheme : Array[Char]) -> Bool {
  let mut i = 0
  while i < scheme.length() && !is_word(scheme[i]) {
    i += 1
  }
  starts_with_ci(scheme, i, "javascript") ||
  starts_with_ci(scheme, i, "data") ||
  starts_with_ci(scheme, i, "vbscript")
}

///|
fn sanitize_url(url : String) -> String {
  let cleaned = remove_control_entities(decode_html_characters(url.to_array())).filter(fn(
      c,
    ) {
      !is_control(c)
    },
  )
  let sanitized = js_trim(String::from_array(cleaned))
  if sanitized == "" {
    return "about:blank"
  }
  let chars = sanitized.to_array()
  if chars[0] == '.' || chars[0] == '/' {
    return sanitized
  }
  match url_scheme(chars) {
    Some(scheme) if has_invalid_protocol(scheme) => "about:blank"
    _ => sanitized
  }
}

///|
/// `normalizeLink(link)`: what the official export writes as the `href`.
pub fn normalize_link(link : String) -> String {
  let trimmed = js_trim(link)
  if trimmed == "" {
    return trimmed
  }
  sanitize_url(trimmed.replace_all(old="\"", new="&quot;"))
}
