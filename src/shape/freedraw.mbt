// Freedraw strokes: `getFreeDrawSvgPath` and its helpers from Excalidraw's
// renderer/renderElement.ts.

///|
fn is_digit(c : Char) -> Bool {
  c >= '0' && c <= '9'
}

///|
/// `path.replace(/(\s?[A-Z]?,?-?[0-9]*\.[0-9]{0,2})(([0-9]|e|-)*)/g, "$1")`, the
/// regular expression upstream uses to cut every number with a fraction to two
/// decimals. It truncates, it doesn't round. The core library has no regex
/// engine, so this walks the text the same way a match would: an optional space,
/// an optional capital letter, an optional comma and minus, the integer digits, a
/// dot, up to two digits, and then it drops the rest of the digits, `e` and `-`.
pub fn trim_path_decimals(path : String) -> String {
  let chars = path.to_array()
  let n = chars.length()
  let out = StringBuilder()
  let mut i = 0
  while i < n {
    let mut j = i
    if j < n && chars[j] == ' ' {
      j += 1
    }
    if j < n && chars[j] >= 'A' && chars[j] <= 'Z' {
      j += 1
    }
    if j < n && chars[j] == ',' {
      j += 1
    }
    if j < n && chars[j] == '-' {
      j += 1
    }
    while j < n && is_digit(chars[j]) {
      j += 1
    }
    if j < n && chars[j] == '.' {
      j += 1
      let mut digits = 0
      while digits < 2 && j < n && is_digit(chars[j]) {
        j += 1
        digits += 1
      }
      for k in i..<j {
        out.write_char(chars[k])
      }
      while j < n && (is_digit(chars[j]) || chars[j] == 'e' || chars[j] == '-') {
        j += 1
      }
      i = j
    } else {
      out.write_char(chars[i])
      i += 1
    }
  }
  out.to_string()
}

///|
fn point_text(p : (Double, Double)) -> String {
  "\{@svg.num(p.0)},\{@svg.num(p.1)}"
}

///|
/// `getSvgPathFromStroke`: the outline as a closed path of quadratic curves
/// through the midpoints.
fn path_from_stroke(points : Array[(Double, Double)]) -> String {
  if points.length() == 0 {
    return ""
  }
  let mid = fn(a : (Double, Double), b : (Double, Double)) {
    ((a.0 + b.0) / 2.0, (a.1 + b.1) / 2.0)
  }
  let parts = ["M", point_text(points[0]), "Q"]
  let last = points.length() - 1
  for i, p in points {
    if i == last {
      parts.push(point_text(p))
      parts.push(point_text(mid(p, points[0])))
      parts.push("L")
      parts.push(point_text(points[0]))
      parts.push("Z")
    } else {
      parts.push(point_text(p))
      parts.push(point_text(mid(p, points[i + 1])))
    }
  }
  trim_path_decimals(parts.join(" "))
}

///|
/// `getFreeDrawSvgPath`. The editor's `last` option (the stroke is finished) is
/// always false here: `restore` clears `lastCommittedPoint`.
pub fn freedraw_path(e : @model.Element) -> String {
  guard e.kind is Freedraw({ points, pressures, simulate_pressure, }) else {
    abort("not a freedraw element")
  }
  let input : Array[(Double, Double, Double?)] = if simulate_pressure {
    points.map(fn(p) { (p.0, p.1, None) })
  } else if points.length() > 0 {
    points.mapi(fn(i, p) {
      (p.0, p.1, if i < pressures.length() { Some(pressures[i]) } else { None })
    })
  } else {
    [(0.0, 0.0, Some(0.5))]
  }
  let options = @freehand.excalidraw_options(
    e.stroke_width,
    simulate_pressure,
    false,
  )
  path_from_stroke(@freehand.get_stroke(input, options))
}

///|
/// The rough.js shape that fills a closed freedraw stroke: a curve through the
/// simplified points, drawn without an outline. Open strokes have none.
fn freedraw_fill(
  e : @model.Element,
  points : Array[(Double, Double)],
) -> Array[@moon_rough.Drawable] {
  if !is_path_a_loop(points) {
    return []
  }
  let simplified = @curve.simplify(
    points.map(fn(p) { @geometry.Point::new(p.0, p.1) }),
    0.75,
  ).map(fn(p) { (p.x, p.y) })
  let options = { ..rough_options(e), stroke: Some("none"), }
  [@moon_rough.generator().curve(simplified, options~)]
}
