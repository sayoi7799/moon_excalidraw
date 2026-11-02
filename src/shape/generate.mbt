// `_generateElementShape` of Excalidraw's scene/Shape.ts: which rough.js call
// draws each element type.

///|
fn num(x : Double) -> String {
  @svg.num(x)
}

///|
/// `getDiamondPoints`: top, right, bottom, left. The +1 is upstream's, to keep
/// the points from being 0.
pub fn diamond_points(
  e : @model.Element,
) -> (Double, Double, Double, Double, Double, Double, Double, Double) {
  let top_x = (e.width / 2.0).floor() + 1.0
  let right_y = (e.height / 2.0).floor() + 1.0
  (top_x, 0.0, e.width, right_y, top_x, e.height, 0.0, right_y)
}

///|
fn round_rect_path(e : @model.Element) -> String {
  let w = e.width
  let h = e.height
  let r = corner_radius(@jsmath.min(w, h), e)
  "M \{num(r)} 0 L \{num(w - r)} 0 Q \{num(w)} 0, \{num(w)} \{num(r)} L \{num(w)} \{num(h - r)} Q \{num(w)} \{num(h)}, \{num(w - r)} \{num(h)} L \{num(r)} \{num(h)} Q 0 \{num(h)}, 0 \{num(h - r)} L 0 \{num(r)} Q 0 0, \{num(r)} 0"
}

///|
fn round_diamond_path(e : @model.Element) -> String {
  let (top_x, top_y, right_x, right_y, bottom_x, bottom_y, left_x, left_y) = diamond_points(
    e,
  )
  let v = corner_radius((top_x - left_x).abs(), e)
  let h = corner_radius((right_y - top_y).abs(), e)
  // The line breaks and indentation are upstream's template literal; rough.js
  // normalises them when it parses the path.
  let nl = "\n            "
  [
    "M \{num(top_x + v)} \{num(top_y + h)} L \{num(right_x - v)} \{num(right_y - h)}",
    "C \{num(right_x)} \{num(right_y)}, \{num(right_x)} \{num(right_y)}, \{num(right_x - v)} \{num(right_y + h)}",
    "L \{num(bottom_x + v)} \{num(bottom_y - h)}",
    "C \{num(bottom_x)} \{num(bottom_y)}, \{num(bottom_x)} \{num(bottom_y)}, \{num(bottom_x - v)} \{num(bottom_y - h)}",
    "L \{num(left_x + v)} \{num(left_y + h)}",
    "C \{num(left_x)} \{num(left_y)}, \{num(left_x)} \{num(left_y)}, \{num(left_x + v)} \{num(left_y - h)}",
    "L \{num(top_x - v)} \{num(top_y + h)}",
    "C \{num(top_x)} \{num(top_y)}, \{num(top_x)} \{num(top_y)}, \{num(top_x + v)} \{num(top_y + h)}",
  ].join(nl)
}

///|
/// The rough.js drawables of an element, in paint order. Text, images and frames
/// have none. `canvas_background` fills "outline" arrowheads.
pub fn generate(
  e : @model.Element,
  canvas_background : String,
) -> Array[@moon_rough.Drawable] raise {
  let gen = @moon_rough.generator()
  match e.kind {
    Freedraw({ points, .. }) => freedraw_fill(e, points)
    Line({ points, .. }) => [linear_curve(e, points)]
    Arrow({ points, start_arrowhead, end_arrowhead, .. }) => {
      let options = Ref::new(rough_options(e))
      let curve = linear_curve(e, points)
      let shapes = [curve]
      if start_arrowhead is Some(head) {
        shapes.append(
          arrowhead_shapes(
            gen, e, points, curve, true, head, options, canvas_background,
          ),
        )
      }
      if end_arrowhead is Some(head) {
        shapes.append(
          arrowhead_shapes(
            gen, e, points, curve, false, head, options, canvas_background,
          ),
        )
      }
      shapes
    }
    Rectangle =>
      if e.roundness is Some(_) {
        [
          gen.path(
            round_rect_path(e),
            options=rough_options(e, continuous_path=true),
          ),
        ]
      } else {
        [gen.rectangle(0.0, 0.0, e.width, e.height, options=rough_options(e))]
      }
    Diamond =>
      if e.roundness is Some(_) {
        [
          gen.path(
            round_diamond_path(e),
            options=rough_options(e, continuous_path=true),
          ),
        ]
      } else {
        let (top_x, top_y, right_x, right_y, bottom_x, bottom_y, left_x, left_y) = diamond_points(
          e,
        )
        [
          gen.polygon(
            [
              (top_x, top_y),
              (right_x, right_y),
              (bottom_x, bottom_y),
              (left_x, left_y),
            ],
            options=rough_options(e),
          ),
        ]
      }
    Ellipse =>
      [
        gen.ellipse(
          e.width / 2.0,
          e.height / 2.0,
          e.width,
          e.height,
          options=rough_options(e),
        ),
      ]
    _ => []
  }
}
