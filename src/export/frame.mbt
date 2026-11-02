// Frames: the title labels the official export adds, and the clip paths.
// From scene/export.ts (`addFrameLabelsAsTextElements`, `truncateText`) and
// constants.ts (`FRAME_STYLE`).

///|
const FRAME_NAME_OFFSET_Y : Double = 3.0

///|
const FRAME_NAME_FONT_SIZE : Double = 14.0

///|
const FRAME_NAME_LINE_HEIGHT : Double = 1.25

///|
const FRAME_NAME_COLOR : String = "#999999"

///|
const FRAME_RADIUS : String = "8"

///|
const HELVETICA : Int32 = 2

///|
pub fn is_frame(e : @model.Element) -> Bool {
  e.kind is (Frame(_) | MagicFrame(_))
}

///|
/// The width of a text in a font, as the browser's canvas would measure it.
/// Without a font to measure, half the font size per character is an estimate.
fn default_measure(text : String, font : String) -> Double {
  let mut n = 0
  for _ in text {
    n += 1
  }
  n.to_double() * 0.5 * @jsnum.parse_float(font)
}

///|
/// `normalizeText`: one kind of line break, and tabs as eight spaces.
fn normalize_text(s : String) -> String {
  @text.split_lines(s).join("\n").replace_all(old="\t", new="        ")
}

///|
/// `getFrameLikeTitle`.
fn frame_title(frame : @model.Element) -> String {
  match frame.kind {
    Frame(name) => name.unwrap_or("Frame")
    MagicFrame(name) => name.unwrap_or("AI Frame")
    _ => ""
  }
}

///|
/// `measureText`: the size of a text block. Empty lines count as a space.
fn measure_block(
  text : String,
  font : String,
  measure : (String, String) -> Double,
) -> (Double, Double) {
  let lines = text
    .split("\n")
    .map(fn(l) { if l == "" { " " } else { l.to_string() } })
  let joined = lines.join("\n")
  let line_count = @text.split_lines(normalize_text(joined)).length()
  let mut width = 0.0
  for line in @text.split_lines(normalize_text(joined)) {
    width = @jsmath.max(width, measure(line, font))
  }
  (
    width,
    FRAME_NAME_FONT_SIZE * FRAME_NAME_LINE_HEIGHT * line_count.to_double(),
  )
}

///|
/// The first `units` UTF-16 code units of a text. Cutting through a surrogate
/// pair leaves half of it, which a saved file shows as U+FFFD.
fn take_units(chars : Array[Char], units : Int32) -> String {
  let out = StringBuilder::new()
  let mut used = 0
  for c in chars {
    let size = if c.to_int() > 0xFFFF { 2 } else { 1 }
    if used + size > units {
      if size == 2 && used < units {
        out.write_char('\u{FFFD}')
      }
      break
    }
    out.write_char(c)
    used += size
  }
  out.to_string()
}

///|
fn utf16_length(chars : Array[Char]) -> Int32 {
  let mut n = 0
  for c in chars {
    n += if c.to_int() > 0xFFFF { 2 } else { 1 }
  }
  n
}

///|
/// `truncateText`: a title wider than its frame loses characters from the right
/// and gets an ellipsis; either way the label is as wide as the frame.
fn truncate_label(
  label : @model.Element,
  data : @model.TextData,
  max_width : Double,
  measure : (String, String) -> Double,
) -> @model.Element {
  if label.width <= max_width {
    return label
  }
  let font = "\{@svg.num(data.font_size)}px \{@text.font_family_string(data.font_family)}"
  let mut text = data.text
  if measure(text, font) > max_width {
    let chars = text.to_array()
    for i = utf16_length(chars); i > 0; i = i - 1 {
      let candidate = take_units(chars, i) + "..."
      if measure(candidate, font) <= max_width {
        text = candidate
        break
      }
    }
  }
  { ..label, width: max_width, kind: Text({ ..data, text, }), }
}

///|
/// Puts a title label before every frame, as upstream does so the label can be
/// drawn like any other text.
pub fn add_frame_labels(
  elements : Array[@model.Element],
  measure : (String, String) -> Double,
) -> Array[@model.Element] {
  let out = []
  for e in elements {
    if is_frame(e) {
      let text = normalize_text(frame_title(e))
      let font = "\{@svg.num(FRAME_NAME_FONT_SIZE)}px \{@text.font_family_string(HELVETICA)}"
      let (width, height) = measure_block(text, font, measure)
      let data : @model.TextData = {
        text,
        original_text: text,
        font_size: FRAME_NAME_FONT_SIZE,
        font_family: HELVETICA,
        text_align: "left",
        vertical_align: "top",
        container_id: None,
        line_height: FRAME_NAME_LINE_HEIGHT,
      }
      let label : @model.Element = {
        id: "frame-label-\{e.id}",
        kind: Text(data),
        x: e.x,
        y: e.y - FRAME_NAME_OFFSET_Y - height,
        width,
        height,
        angle: 0.0,
        stroke_color: FRAME_NAME_COLOR,
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
      out.push(truncate_label(label, data, e.width, measure))
    }
    out.push(e)
  }
  out
}

///|
/// The `<clipPath>` of a frame. Its rotation is written in radians, as upstream
/// does, although SVG expects degrees.
pub fn frame_clip_path(
  cache : @shape.ShapeCache,
  frame : @model.Element,
  map : Map[String, @model.Element],
  offset_x : Double,
  offset_y : Double,
) -> @svg.Node {
  let (x1, y1, x2, y2, _, _) = @shape.absolute_coords(cache, frame, map)
  let cx = (x2 - x1) / 2.0 - (frame.x - x1)
  let cy = (y2 - y1) / 2.0 - (frame.y - y1)
  let clip = @svg.Node::element("clipPath")
  clip.set("id", frame.id)
  let rect = @svg.Node::element("rect")
  rect.set(
    "transform",
    "translate(\{@svg.num(frame.x + offset_x)} \{@svg.num(frame.y + offset_y)}) rotate(\{@svg.num(frame.angle)} \{@svg.num(cx)} \{@svg.num(cy)})",
  )
  rect.set("width", @svg.num(frame.width))
  rect.set("height", @svg.num(frame.height))
  rect.set("rx", FRAME_RADIUS)
  rect.set("ry", FRAME_RADIUS)
  clip.append(rect)
  clip
}
