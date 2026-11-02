// The normalisation of `restoreElements` in Excalidraw's data/restore.ts, as the
// official exportToSvg runs it (no binding repair, no text re-measuring).

///|
const ROUNDNESS_LEGACY : Int32 = 1

///|
const ROUNDNESS_PROPORTIONAL : Int32 = 2

///|
const FONT_EXCALIFONT : Int32 = 5

///|
fn js_truthy(x : Double) -> Bool {
  x != 0.0 && !x.is_nan()
}

///|
/// `ToInt32`, which is how rough.js' `Math.imul` reads a seed.
fn to_int32(x : Double) -> Int32 {
  if x.is_nan() || x.is_inf() {
    return 0
  }
  let t = x.abs().floor()
  let m = t - (t / 4294967296.0).floor() * 4294967296.0
  let u = m.to_int64().to_int()
  if x < 0.0 {
    -u
  } else {
    u
  }
}

///|
/// The `FONT_FAMILY` table, for the legacy `font: "20px Virgil"` field.
fn font_family_by_name(name : StringView) -> Int32 {
  match name {
    "Virgil" => 1
    "Helvetica" => 2
    "Cascadia" => 3
    "Excalifont" => 5
    "Nunito" => 6
    _ => FONT_EXCALIFONT
  }
}

///|
fn line_count(text : String) -> Int32 {
  let mut lines = 1
  let chars = text.to_array()
  for i, c in chars {
    if c == '\n' ||
      (c == '\r' && !(i + 1 < chars.length() && chars[i + 1] == '\n')) {
      lines += 1
    }
  }
  lines
}

///|
fn restore_roundness(f : Fields, kind : String) -> Roundness? raise ParseError {
  match f.get("roundness") {
    Some(Object(r)) => {
      let inner = { id: f.id, map: r, }
      Some({
        kind: inner.number("type").unwrap_or(0.0).to_int(),
        value: inner.number("value"),
      })
    }
    Some(False) | None =>
      if f.get("strokeSharpness") is Some(String("round")) {
        let adaptive = kind == "rectangle" || kind == "image"
        Some({
          kind: if adaptive {
            ROUNDNESS_LEGACY
          } else {
            ROUNDNESS_PROPORTIONAL
          },
          value: None,
        })
      } else {
        None
      }
    Some(_) => raise f.bad("roundness", "an object")
  }
}

///|
fn restore_bound_elements(f : Fields) -> Array[BoundElement] raise ParseError {
  if f.get("boundElementIds") is Some(Array(ids)) {
    return ids.filter_map(fn(id) {
      if id is String(id) {
        Some({ id, kind: "arrow", })
      } else {
        None
      }
    })
  }
  match f.get("boundElements") {
    None => []
    Some(Array(items)) =>
      items.map(fn(item) raise ParseError {
        guard item is Object(b) &&
          b.get("id") is Some(String(id)) &&
          b.get("type") is Some(String(kind)) else {
          raise f.bad("boundElements", "a list of {id, type}")
        }
        { id, kind, }
      })
    Some(_) => raise f.bad("boundElements", "an array")
  }
}

///|
fn size_from_points(points : Array[(Double, Double)]) -> (Double, Double) {
  let mut min_x = points[0].0
  let mut max_x = points[0].0
  let mut min_y = points[0].1
  let mut max_y = points[0].1
  for p in points {
    min_x = @jsmath.min(min_x, p.0)
    max_x = @jsmath.max(max_x, p.0)
    min_y = @jsmath.min(min_y, p.1)
    max_y = @jsmath.max(max_y, p.1)
  }
  (max_x - min_x, max_y - min_y)
}

///|
fn restore_text(f : Fields, height : Double) -> TextData raise ParseError {
  let text = if f.get("text") is Some(String(t)) { t } else { "" }
  let raw_font_size = f.number("fontSize")
  let raw_family = f.number("fontFamily")
  // The legacy `font` field wins over `fontSize` and `fontFamily`.
  let (font_size, font_family) = match f.string("font") {
    Some(font) => {
      let parts = font.split(" ").collect()
      let name = if parts.length() > 1 { parts[1] } else { "" }
      let px = parts[0].strip_suffix("px").unwrap_or(parts[0])
      (@jsmath.parse_float(px), font_family_by_name(name))
    }
    None => {
      // The official code would write font-size="undefinedpx".
      guard raw_font_size is Some(size) else {
        raise f.bad("fontSize", "a number")
      }
      (
        size,
        match raw_family {
          Some(family) => family.to_int()
          None => -1
        },
      )
    }
  }
  let line_height = match f.number("lineHeight") {
    Some(v) if js_truthy(v) => v
    _ =>
      if js_truthy(height) {
        // `detectLineHeight` reads the raw fontSize, which legacy elements lack.
        match raw_font_size {
          Some(size) => height / line_count(text).to_double() / size
          None => @double.not_a_number
        }
      } else {
        @text.line_height(raw_family.map(fn(v) { v.to_int() }).unwrap_or(-1))
      }
  }
  let original = f.string("originalText").unwrap_or("")
  {
    text,
    original_text: if original == "" {
      text
    } else {
      original
    },
    font_size,
    font_family,
    text_align: non_empty(f.string("textAlign"), "left"),
    vertical_align: non_empty(f.string("verticalAlign"), "top"),
    container_id: f.string("containerId"),
    line_height,
  }
}

///|
/// `value || fallback` for a string field.
fn non_empty(value : String?, fallback : String) -> String {
  match value {
    Some(v) if v != "" => v
    _ => fallback
  }
}

///|
fn restore_crop(f : Fields) -> Crop? raise ParseError {
  match f.get("crop") {
    None => None
    Some(Object(c)) => {
      let inner = { id: f.id, map: c, }
      let n = fn(key) raise ParseError {
        match inner.number(key) {
          Some(v) => v
          None => raise f.bad("crop", "an object with a number \"\{key}\"")
        }
      }
      Some({
        x: n("x"),
        y: n("y"),
        width: n("width"),
        height: n("height"),
        natural_width: n("naturalWidth"),
        natural_height: n("naturalHeight"),
      })
    }
    Some(_) => raise f.bad("crop", "an object")
  }
}

///|
fn restore_scale(f : Fields) -> (Double, Double) raise ParseError {
  match f.get("scale") {
    None => (1.0, 1.0)
    Some(Array([Number(x, ..), Number(y, ..), ..])) => (x, y)
    Some(_) => raise f.bad("scale", "two numbers")
  }
}

///|
/// An element's `points` with the first point moved to the origin, and how far
/// `x` and `y` shift to make up for it.
fn normalized_points(
  points : Array[(Double, Double)],
) -> (Array[(Double, Double)], Double, Double) {
  let dx = points[0].0
  let dy = points[0].1
  if dx != 0.0 || dy != 0.0 {
    (points.map(fn(p) { (p.0 - dx, p.1 - dy) }), dx, dy)
  } else {
    (points, 0.0, 0.0)
  }
}

///|
/// Restores one element, or None when the official code drops it.
fn restore_element(f : Fields) -> Element? raise ParseError {
  let type_name = f.string("type").unwrap_or("")
  let is_points_type = match type_name {
    "line" | "draw" | "arrow" | "freedraw" => true
    _ => false
  }
  let known = match type_name {
    "rectangle"
    | "diamond"
    | "ellipse"
    | "text"
    | "image"
    | "frame"
    | "magicframe" => true
    _ => is_points_type
  }
  if type_name == "selection" {
    return None
  }
  if !known {
    // Don't validate what we won't draw: only the type and id matter.
    return Some(unsupported_element(f.id, type_name))
  }
  // `isInvisiblySmallElement`, on the raw values.
  if is_points_type {
    if f.points("points").length() < 2 {
      return None
    }
  } else if f.map.get("width") is Some(Number(0.0, ..)) &&
    f.map.get("height") is Some(Number(0.0, ..)) {
    return None
  }
  let raw_width = f.number("width").unwrap_or(0.0)
  let raw_height = f.number("height").unwrap_or(0.0)
  let raw_x = f.number("x").unwrap_or(0.0)
  let raw_y = f.number("y").unwrap_or(0.0)
  // `getNormalizedDimensions`; linear elements replace these below.
  let width = if raw_width.is_nan() { 0.0 } else { raw_width.abs() }
  let height = if raw_height.is_nan() { 0.0 } else { raw_height.abs() }
  let x = if raw_width < 0.0 { raw_x - width } else { raw_x }
  let y = if raw_height < 0.0 { raw_y - height } else { raw_y }
  let mut empty_text = false
  let (kind, x, y, width, height) : (Kind, Double, Double, Double, Double) = match
    type_name {
    "rectangle" => (Rectangle, x, y, width, height)
    "diamond" => (Diamond, x, y, width, height)
    "ellipse" => (Ellipse, x, y, width, height)
    "frame" => (Frame(f.string("name")), x, y, width, height)
    "magicframe" => (MagicFrame(f.string("name")), x, y, width, height)
    "text" => {
      let data = restore_text(f, raw_height)
      empty_text = data.text == ""
      (Text(data), x, y, width, height)
    }
    "image" =>
      (
        Image({
          file_id: match f.string("fileId") {
            Some("") => None
            other => other
          },
          scale: restore_scale(f),
          crop: restore_crop(f),
        }),
        x,
        y,
        width,
        height,
      )
    "freedraw" => {
      let pressures = match f.get("pressures") {
        None => None
        Some(Array(items)) =>
          Some(
            items.map(fn(p) raise ParseError {
              guard p is Number(v, ..) else {
                raise f.bad("pressures", "an array of numbers")
              }
              v
            }),
          )
        Some(_) => raise f.bad("pressures", "an array of numbers")
      }
      let simulate_pressure = f.boolean("simulatePressure").unwrap_or(false)
      if pressures is None && !simulate_pressure {
        // The official export throws for this element and skips it silently.
        raise f.bad("pressures", "present unless simulatePressure is set")
      }
      (
        Freedraw({
          points: f.points("points"),
          pressures: pressures.unwrap_or([]),
          simulate_pressure,
        }),
        x,
        y,
        width,
        height,
      )
    }
    _ => {
      let (points, dx, dy) = normalized_points(f.points("points"))
      let (w, h) = size_from_points(points)
      let is_arrow = type_name == "arrow"
      let end_arrowhead = match f.map.get("endArrowhead") {
        None => if is_arrow { Some("arrow") } else { None }
        Some(_) => f.string("endArrowhead")
      }
      let linear = {
        points,
        start_arrowhead: f.string("startArrowhead"),
        end_arrowhead,
        elbowed: is_arrow && f.boolean("elbowed").unwrap_or(false),
      }
      (
        if is_arrow {
          Arrow(linear)
        } else {
          Line(linear)
        },
        raw_x + dx,
        raw_y + dy,
        w,
        h,
      )
    }
  }
  let kind_name = if type_name == "draw" { "line" } else { type_name }
  let stroke_width = f.number("strokeWidth").unwrap_or(0.0)
  let angle = f.number("angle").unwrap_or(0.0)
  let link = match f.string("link") {
    Some("") | None => None
    Some(l) => {
      let normalized = normalize_link(l)
      if normalized == "" {
        None
      } else {
        Some(normalized)
      }
    }
  }
  Some({
    id: f.id,
    kind,
    x,
    y,
    width,
    height,
    angle: if js_truthy(angle) {
      angle
    } else {
      0.0
    },
    stroke_color: non_empty(f.string("strokeColor"), "#1e1e1e"),
    background_color: non_empty(f.string("backgroundColor"), "transparent"),
    fill_style: non_empty(f.string("fillStyle"), "solid"),
    stroke_width: if js_truthy(stroke_width) {
      stroke_width
    } else {
      2.0
    },
    stroke_style: f.string("strokeStyle").unwrap_or("solid"),
    roughness: f.number("roughness").unwrap_or(1.0),
    opacity: f.number("opacity").unwrap_or(100.0),
    seed: to_int32(f.number("seed").unwrap_or(1.0)),
    roundness: restore_roundness(f, kind_name),
    bound_elements: restore_bound_elements(f),
    frame_id: f.string("frameId"),
    link,
    is_deleted: empty_text,
  })
}

///|
fn unsupported_element(id : String, type_name : String) -> Element {
  {
    id,
    kind: Unsupported(type_name),
    x: 0.0,
    y: 0.0,
    width: 0.0,
    height: 0.0,
    angle: 0.0,
    stroke_color: "#1e1e1e",
    background_color: "transparent",
    fill_style: "solid",
    stroke_width: 2.0,
    stroke_style: "solid",
    roughness: 1.0,
    opacity: 100.0,
    seed: 1,
    roundness: None,
    bound_elements: [],
    frame_id: None,
    link: None,
    is_deleted: false,
  }
}
