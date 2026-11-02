// `generateRoughOptions` of Excalidraw's scene/Shape.ts: how an element's style
// becomes rough.js options.

///|
const DEFAULT_PROPORTIONAL_RADIUS : Double = 0.25

///|
const DEFAULT_ADAPTIVE_RADIUS : Double = 32.0

///|
const ROUGHNESS_CARTOONIST : Double = 2.0

///|
fn dash_dashed(stroke_width : Double) -> Array[Double] {
  [8.0, 8.0 + stroke_width]
}

///|
fn dash_dotted(stroke_width : Double) -> Array[Double] {
  [1.5, 6.0 + stroke_width]
}

///|
fn is_linear(e : @model.Element) -> Bool {
  e.kind is (Line(_) | Arrow(_))
}

///|
/// `canChangeRoundness` of scene/comparisons.ts, for the types we draw.
fn can_change_roundness(e : @model.Element) -> Bool {
  e.kind is (Rectangle | Line(_) | Arrow(_) | Diamond | Image(_))
}

///|
/// Small shapes get less roughness, or they'd turn into a scribble.
fn adjust_roughness(e : @model.Element) -> Double {
  let max_size = @jsmath.max(e.width, e.height)
  let min_size = @jsmath.min(e.width, e.height)
  if (min_size >= 20.0 && max_size >= 50.0) ||
    (min_size >= 15.0 && e.roundness is Some(_) && can_change_roundness(e)) ||
    (is_linear(e) && max_size >= 50.0) {
    return e.roughness
  }
  @jsmath.min(e.roughness / (if max_size < 10.0 { 3.0 } else { 2.0 }), 2.5)
}

///|
/// `isTransparent` of utils.ts.
pub fn is_transparent(color : String) -> Bool {
  let n = color.length()
  (n == 5 && color.code_unit_at(4) == '0') ||
  (n == 9 && color.code_unit_at(7) == '0' && color.code_unit_at(8) == '0') ||
  color == "transparent"
}

///|
pub fn is_path_a_loop(points : Array[(Double, Double)]) -> Bool {
  if points.length() < 3 {
    return false
  }
  let first = points[0]
  let last = points[points.length() - 1]
  @jsnum.hypot(last.0 - first.0, last.1 - first.1) <= 8.0
}

///|
/// `getCornerRadius` of shapes.tsx.
pub fn corner_radius(x : Double, e : @model.Element) -> Double {
  match e.roundness {
    Some({ kind: 1 | 2, .. }) => x * DEFAULT_PROPORTIONAL_RADIUS
    Some({ kind: 3, value, }) => {
      let fixed = value.unwrap_or(DEFAULT_ADAPTIVE_RADIUS)
      if x <= fixed / DEFAULT_PROPORTIONAL_RADIUS {
        x * DEFAULT_PROPORTIONAL_RADIUS
      } else {
        fixed
      }
    }
    _ => 0.0
  }
}

///|
/// `generateRoughOptions(element, continuousPath)`. Every call asks for rough.js
/// 4.6.4 behaviour, the version Excalidraw uses.
pub fn rough_options(
  e : @model.Element,
  continuous_path~ : Bool = false,
) -> @moon_rough.Options {
  let solid = e.stroke_style == "solid"
  let o = @moon_rough.Options::new(
    seed=e.seed,
    disable_multi_stroke=!solid,
    stroke_width=if solid { e.stroke_width } else { e.stroke_width + 0.5 },
    fill_weight=e.stroke_width / 2.0,
    hachure_gap=e.stroke_width * 4.0,
    roughness=adjust_roughness(e),
    stroke=e.stroke_color,
    preserve_vertices=continuous_path || e.roughness < ROUGHNESS_CARTOONIST,
    roughjs_464=true,
  )
  let o = match e.stroke_style {
    "dashed" => { ..o, stroke_line_dash: Some(dash_dashed(e.stroke_width)), }
    "dotted" => { ..o, stroke_line_dash: Some(dash_dotted(e.stroke_width)), }
    _ => o
  }
  let fill_style = Some(@moon_rough.FillStyle::from_name(e.fill_style))
  match e.kind {
    Rectangle | Diamond | Ellipse => {
      let fill = if is_transparent(e.background_color) {
        None
      } else {
        Some(e.background_color)
      }
      let curve_fitting = if e.kind is Ellipse { Some(1.0) } else { None }
      { ..o, fill_style, fill, curve_fitting, }
    }
    Line({ points, .. }) | Freedraw({ points, .. }) =>
      if is_path_a_loop(points) {
        let fill = if e.background_color == "transparent" {
          None
        } else {
          Some(e.background_color)
        }
        { ..o, fill_style, fill, }
      } else {
        o
      }
    _ => o
  }
}
