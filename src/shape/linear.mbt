// Geometry of lines and arrows: how rough.js curves bound them.
// From element/bounds.ts and element/linearElementEditor.ts.

///|
/// Upstream keeps generated shapes in a cache, and `getElementAbsoluteCoords`
/// changes behaviour with it: with no cached shape it estimates a line's box
/// from its points, with one it uses the real curve. So the coordinates depend
/// on which shapes were generated before, and that history is part of the output.
pub struct ShapeCache {
  priv cached : Map[String, Bool]
}

///|
pub fn ShapeCache::new() -> ShapeCache {
  { cached: {}, }
}

///|
/// Records that upstream's `ShapeCache.generateElementShape` ran for `e`.
pub fn ShapeCache::mark(self : ShapeCache, e : @model.Element) -> Unit {
  self.cached[e.id] = true
}

///|
fn linear_points(e : @model.Element) -> Array[(Double, Double)] {
  match e.kind {
    Line(l) | Arrow(l) => l.points
    _ => abort("not a linear element")
  }
}

///|
/// `generateLinearElementShape`: the curve drawn for a line or arrow, which is
/// also the first drawable of its shape.
pub fn linear_curve(
  e : @model.Element,
  points : Array[(Double, Double)],
) -> @moon_rough.Drawable {
  let gen = @moon_rough.generator()
  let options = rough_options(e)
  if e.roundness is Some(_) {
    gen.curve(points, options~)
  } else if options.fill is Some(_) {
    gen.polygon(points, options~)
  } else {
    gen.linear_path(points, options~)
  }
}

///|
/// `getCurvePathOps`.
pub fn curve_path_ops(d : @moon_rough.Drawable) -> Array[@moon_rough.Op] {
  for set in d.sets {
    if set.kind is Path {
      return set.ops
    }
  }
  if d.sets.length() > 0 {
    d.sets[0].ops
  } else {
    []
  }
}

///|
/// `getBezierValueForT`.
fn bezier_value(
  t : Double,
  p0 : Double,
  p1 : Double,
  p2 : Double,
  p3 : Double,
) -> Double {
  let u = 1.0 - t
  @jsnum.cube(u) * p0 +
  3.0 * (u * u) * t * p1 +
  3.0 * u * (t * t) * p2 +
  @jsnum.cube(t) * p3
}

///|
/// `solveQuadratic`: the curve's values at its extrema inside 0..1.
fn extrema(p0 : Double, p1 : Double, p2 : Double, p3 : Double) -> Array[Double] {
  let i = p1 - p0
  let j = p2 - p1
  let k = p3 - p2
  let a = 3.0 * i - 6.0 * j + 3.0 * k
  let b = 6.0 * j - 6.0 * i
  let c = 3.0 * i
  let sqrt_part = b * b - 4.0 * a * c
  if !(sqrt_part >= 0.0) {
    return []
  }
  let (t1, t2) = if a == 0.0 {
    (-c / b, -c / b)
  } else {
    let root = sqrt_part.sqrt()
    ((-b + root) / (2.0 * a), (-b - root) / (2.0 * a))
  }
  let out = []
  if t1 >= 0.0 && t1 <= 1.0 {
    out.push(bezier_value(t1, p0, p1, p2, p3))
  }
  if t2 >= 0.0 && t2 <= 1.0 {
    out.push(bezier_value(t2, p0, p1, p2, p3))
  }
  out
}

///|
/// `getMinMaxXYFromCurvePathOps`. Only Bézier ops count, as upstream.
fn curve_ops_bounds(
  ops : Array[@moon_rough.Op],
  transform : ((Double, Double)) -> (Double, Double),
) -> (Double, Double, Double, Double) {
  let mut current = (0.0, 0.0)
  let mut min_x = @double.infinity
  let mut min_y = @double.infinity
  let mut max_x = @double.neg_infinity
  let mut max_y = @double.neg_infinity
  for op in ops {
    match op {
      Move(x, y) => current = (x, y)
      BCurveTo(x1, y1, x2, y2, x3, y3) => {
        let p1 = transform((x1, y1))
        let p2 = transform((x2, y2))
        let p3 = transform((x3, y3))
        let p0 = transform(current)
        current = (x3, y3)
        let mut lo_x = @jsmath.min(p0.0, p3.0)
        let mut hi_x = @jsmath.max(p0.0, p3.0)
        for v in extrema(p0.0, p1.0, p2.0, p3.0) {
          lo_x = @jsmath.min(lo_x, v)
          hi_x = @jsmath.max(hi_x, v)
        }
        let mut lo_y = @jsmath.min(p0.1, p3.1)
        let mut hi_y = @jsmath.max(p0.1, p3.1)
        for v in extrema(p0.1, p1.1, p2.1, p3.1) {
          lo_y = @jsmath.min(lo_y, v)
          hi_y = @jsmath.max(hi_y, v)
        }
        min_x = @jsmath.min(min_x, lo_x)
        min_y = @jsmath.min(min_y, lo_y)
        max_x = @jsmath.max(max_x, hi_x)
        max_y = @jsmath.max(max_y, hi_y)
      }
      LineTo(_, _) => ()
    }
  }
  (min_x, min_y, max_x, max_y)
}

///|
/// `getBoundsFromPoints`.
fn points_bounds(
  points : Array[(Double, Double)],
) -> (Double, Double, Double, Double) {
  let mut min_x = @double.infinity
  let mut min_y = @double.infinity
  let mut max_x = @double.neg_infinity
  let mut max_y = @double.neg_infinity
  for p in points {
    min_x = @jsmath.min(min_x, p.0)
    min_y = @jsmath.min(min_y, p.1)
    max_x = @jsmath.max(max_x, p.0)
    max_y = @jsmath.max(max_y, p.1)
  }
  (min_x, min_y, max_x, max_y)
}

///|
/// `LinearElementEditor.getElementAbsoluteCoords`.
fn linear_absolute_coords(
  cache : ShapeCache,
  e : @model.Element,
) -> (Double, Double, Double, Double, Double, Double) {
  let points = linear_points(e)
  let (min_x, min_y, max_x, max_y) = if cache.cached.contains(e.id) {
    curve_ops_bounds(curve_path_ops(linear_curve(e, points)), fn(p) { p })
  } else {
    points_bounds(points)
  }
  let x1 = min_x + e.x
  let y1 = min_y + e.y
  let x2 = max_x + e.x
  let y2 = max_y + e.y
  (x1, y1, x2, y2, (x1 + x2) / 2.0, (y1 + y2) / 2.0)
}

///|
/// `getLinearElementRotatedBounds`, for an element without a bound label.
fn linear_rotated_bounds(
  e : @model.Element,
  cx : Double,
  cy : Double,
) -> (Double, Double, Double, Double) {
  let ops = curve_path_ops(linear_curve(e, linear_points(e)))
  curve_ops_bounds(ops, fn(p) { rotate(e.x + p.0, e.y + p.1, cx, cy, e.angle) })
}
