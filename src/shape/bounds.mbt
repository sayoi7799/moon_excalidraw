// Element bounds, from `ElementBounds` and `getElementAbsoluteCoords` of
// Excalidraw's element/bounds.ts. They decide the canvas size of the export.

///|
fn rotate(
  x : Double,
  y : Double,
  cx : Double,
  cy : Double,
  angle : Double,
) -> (Double, Double) {
  let cos = @jsmath.cos(angle)
  let sin = @jsmath.sin(angle)
  ((x - cx) * cos - (y - cy) * sin + cx, (x - cx) * sin + (y - cy) * cos + cy)
}

///|
fn min4(a : Double, b : Double, c : Double, d : Double) -> Double {
  @jsmath.min(@jsmath.min(@jsmath.min(a, b), c), d)
}

///|
fn max4(a : Double, b : Double, c : Double, d : Double) -> Double {
  @jsmath.max(@jsmath.max(@jsmath.max(a, b), c), d)
}

///|
/// `getElementAbsoluteCoords`: x1, y1, x2, y2, cx, cy, ignoring rotation.
pub fn absolute_coords(
  e : @model.Element,
  map : Map[String, @model.Element],
) -> (Double, Double, Double, Double, Double, Double) {
  ignore(map)
  (
    e.x,
    e.y,
    e.x + e.width,
    e.y + e.height,
    e.x + e.width / 2.0,
    e.y + e.height / 2.0,
  )
}

///|
/// `getElementBounds`: the box around the element after rotation.
pub fn element_bounds(
  e : @model.Element,
  map : Map[String, @model.Element],
) -> (Double, Double, Double, Double) {
  let (x1, y1, x2, y2, cx, cy) = absolute_coords(e, map)
  match e.kind {
    Diamond => {
      let (x11, y11) = rotate(cx, y1, cx, cy, e.angle)
      let (x12, y12) = rotate(cx, y2, cx, cy, e.angle)
      let (x22, y22) = rotate(x1, cy, cx, cy, e.angle)
      let (x21, y21) = rotate(x2, cy, cx, cy, e.angle)
      (
        min4(x11, x12, x22, x21),
        min4(y11, y12, y22, y21),
        max4(x11, x12, x22, x21),
        max4(y11, y12, y22, y21),
      )
    }
    Ellipse => {
      let w = (x2 - x1) / 2.0
      let h = (y2 - y1) / 2.0
      let cos = @jsmath.cos(e.angle)
      let sin = @jsmath.sin(e.angle)
      let ww = @jsnum.hypot(w * cos, h * sin)
      let hh = @jsnum.hypot(h * cos, w * sin)
      (cx - ww, cy - hh, cx + ww, cy + hh)
    }
    _ => {
      let (x11, y11) = rotate(x1, y1, cx, cy, e.angle)
      let (x12, y12) = rotate(x1, y2, cx, cy, e.angle)
      let (x22, y22) = rotate(x2, y2, cx, cy, e.angle)
      let (x21, y21) = rotate(x2, y1, cx, cy, e.angle)
      (
        min4(x11, x12, x22, x21),
        min4(y11, y12, y22, y21),
        max4(x11, x12, x22, x21),
        max4(y11, y12, y22, y21),
      )
    }
  }
}

///|
/// `getCommonBounds`. As upstream, an empty list is the empty box at the origin.
pub fn common_bounds(
  elements : Array[@model.Element],
  map : Map[String, @model.Element],
) -> (Double, Double, Double, Double) {
  if elements.length() == 0 {
    return (0.0, 0.0, 0.0, 0.0)
  }
  let mut min_x = @double.infinity
  let mut min_y = @double.infinity
  let mut max_x = @double.neg_infinity
  let mut max_y = @double.neg_infinity
  for e in elements {
    let (x1, y1, x2, y2) = element_bounds(e, map)
    min_x = @jsmath.min(min_x, x1)
    min_y = @jsmath.min(min_y, y1)
    max_x = @jsmath.max(max_x, x2)
    max_y = @jsmath.max(max_y, y2)
  }
  (min_x, min_y, max_x, max_y)
}
