// Geometry of lines and arrows: how rough.js curves bound them.
// From element/bounds.ts and element/linearElementEditor.ts.

///|
/// Upstream keeps generated shapes in a cache, and `getElementAbsoluteCoords`
/// changes behaviour with it: with no cached shape it estimates a line's box
/// from its points, with one it uses the real curve. So the coordinates depend
/// on which shapes were generated before, and that history is part of the output.
pub struct ShapeCache {
  priv shapes : Map[String, @moon_rough.Drawable]
}

///|
pub fn ShapeCache::new() -> ShapeCache {
  { shapes: Map([]), }
}

///|
/// Keeps the drawable upstream's `ShapeCache.generateElementShape` made for `e`.
/// Later reads use it as it was drawn, not a fresh one made from the points as
/// they are by then.
pub fn ShapeCache::store(
  self : ShapeCache,
  e : @model.Element,
  curve : @moon_rough.Drawable,
) -> Unit {
  self.shapes[e.id] = curve
}

///|
fn ShapeCache::get(
  self : ShapeCache,
  e : @model.Element,
) -> @moon_rough.Drawable? {
  self.shapes.get(e.id)
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
///
/// A closed line with a pattern fill is drawn as a polygon, and rough.js's pattern
/// fills rotate the polygon's points in place and back. That leaves rounding noise
/// in upstream's `element.points`, which every later calculation then reads, so
/// the element's points are overwritten the same way.
pub fn generate_curve(e : @model.Element) -> @moon_rough.Drawable {
  let points = linear_points(e)
  let gen = @moon_rough.generator()
  let options = rough_options(e)
  if e.roundness is Some(_) {
    gen.curve(points, options~)
  } else if options.fill is Some(_) {
    let work = points.map(fn(p) { @geometry.Point::new(p.0, p.1) })
    let drawable = gen.polygon_points(work, options~)
    for i, p in work {
      points[i] = (p.x, p.y)
    }
    drawable
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
  let (min_x, min_y, max_x, max_y) = match cache.get(e) {
    Some(curve) => curve_ops_bounds(curve_path_ops(curve), fn(p) { p })
    None => points_bounds(points)
  }
  let x1 = min_x + e.x
  let y1 = min_y + e.y
  let x2 = max_x + e.x
  let y2 = max_y + e.y
  (x1, y1, x2, y2, (x1 + x2) / 2.0, (y1 + y2) / 2.0)
}

///|
/// `getLinearElementRotatedBounds`.
fn linear_rotated_bounds(
  cache : ShapeCache,
  e : @model.Element,
  cx : Double,
  cy : Double,
  map : Map[String, @model.Element],
) -> (Double, Double, Double, Double) {
  // Upstream uses the cached shape if there is one, and otherwise draws a fresh
  // one (without caching it).
  let curve = match cache.get(e) {
    Some(curve) => curve
    None => generate_curve(e)
  }
  let ops = curve_path_ops(curve)
  let bounds = curve_ops_bounds(ops, fn(p) {
    rotate(e.x + p.0, e.y + p.1, cx, cy, e.angle)
  })
  match bound_text(e, map) {
    Some(text) => bounds_with_text(cache, e, map, bounds, text)
    None => bounds
  }
}

///|
/// `getBoundTextElement`: the first text bound to a container.
pub fn bound_text(
  e : @model.Element,
  map : Map[String, @model.Element],
) -> @model.Element? {
  for b in e.bound_elements {
    if b.kind == "text" {
      return map.get(b.id)
    }
  }
  None
}

///|
fn point_global(
  cache : ShapeCache,
  e : @model.Element,
  p : (Double, Double),
  map : Map[String, @model.Element],
) -> (Double, Double) {
  let (x1, y1, x2, y2, _, _) = absolute_coords(cache, e, map)
  rotate(e.x + p.0, e.y + p.1, (x1 + x2) / 2.0, (y1 + y2) / 2.0, e.angle)
}

///|
/// `getControlPointsForBezierCurve`: the Bézier segment ending closest to
/// `end_point`. Upstream generates the shape here, which fills its cache.
fn control_points(
  cache : ShapeCache,
  e : @model.Element,
  end_point : (Double, Double),
) -> Array[(Double, Double)]? {
  // `generateElementShape`: the cached shape, or a new one that is then cached.
  let curve = match cache.get(e) {
    Some(curve) => curve
    None => {
      let curve = generate_curve(e)
      cache.store(e, curve)
      curve
    }
  }
  let mut current = (0.0, 0.0)
  let mut min_distance = @double.infinity
  let mut result = None
  for op in curve_path_ops(curve) {
    match op {
      Move(x, y) => current = (x, y)
      BCurveTo(x1, y1, x2, y2, x3, y3) => {
        let d = @jsnum.hypot(x3 - end_point.0, y3 - end_point.1)
        if d < min_distance {
          min_distance = d
          result = Some([current, (x1, y1), (x2, y2), (x3, y3)])
        }
        current = (x3, y3)
      }
      LineTo(_, _) => ()
    }
  }
  result
}

///|
/// `getBezierXY`. Note that the weights are listed from the end point back.
fn bezier_xy(cp : Array[(Double, Double)], t : Double) -> (Double, Double) {
  let u = 1.0 - t
  let eq = fn(p0 : Double, p1 : Double, p2 : Double, p3 : Double) {
    @jsnum.cube(u) * p3 +
    3.0 * t * (u * u) * p2 +
    3.0 * (t * t) * u * p1 +
    p0 * @jsnum.cube(t)
  }
  (
    eq(cp[0].0, cp[1].0, cp[2].0, cp[3].0),
    eq(cp[0].1, cp[1].1, cp[2].1, cp[3].1),
  )
}

///|
/// `mapIntervalToBezierT`: the t that lies `interval` of the way along the
/// curve's length, measured on 20 points of it.
fn interval_to_t(
  cp : Array[(Double, Double)],
  end_point : (Double, Double),
  interval : Double,
) -> Double {
  let points = []
  let mut t = 1.0
  while t > 0.0 {
    points.push(bezier_xy(cp, t))
    t -= 0.05
  }
  let last = points[points.length() - 1]
  if (last.0 - end_point.0).abs() < 10.0e-5 &&
    (last.1 - end_point.1).abs() < 10.0e-5 {
    points.push(end_point)
  }
  let arc_lengths = [0.0]
  let mut distance = 0.0
  for i in 0..<(points.length() - 1) {
    distance += @jsnum.hypot(
      points[i].0 - points[i + 1].0,
      points[i].1 - points[i + 1].1,
    )
    arc_lengths.push(distance)
  }
  let count = arc_lengths.length() - 1
  let target = interval * arc_lengths[count]
  let mut low = 0
  let mut high = count
  let mut index = 0
  while low < high {
    index = low + (high - low) / 2
    if arc_lengths[index] < target {
      low = index + 1
    } else {
      high = index
    }
  }
  if arc_lengths[index] > target {
    index -= 1
  }
  if arc_lengths[index] == target {
    return index.to_double() / count.to_double()
  }
  1.0 -
  (
    index.to_double() +
    (target - arc_lengths[index]) /
    (arc_lengths[index + 1] - arc_lengths[index])
  ) /
  count.to_double()
}

///|
/// `getSegmentMidPoint`: the middle of a segment, or for a curve the point half
/// way along its length.
fn segment_mid_point(
  cache : ShapeCache,
  e : @model.Element,
  points : Array[(Double, Double)],
  start : (Double, Double),
  end : (Double, Double),
  end_index : Int32,
  map : Map[String, @model.Element],
) -> (Double, Double) {
  if points.length() > 2 && e.roundness is Some(_) {
    let end_point = points[end_index]
    if control_points(cache, e, end_point) is Some(cp) {
      let t = interval_to_t(cp, end_point, 0.5)
      return point_global(cache, e, bezier_xy(cp, t), map)
    }
  }
  ((start.0 + end.0) / 2.0, (start.1 + end.1) / 2.0)
}

///|
/// `LinearElementEditor.getBoundTextElementPosition`: a label sits on the middle
/// point, or on the middle of the middle segment.
pub fn bound_text_position(
  cache : ShapeCache,
  e : @model.Element,
  text : @model.Element,
  map : Map[String, @model.Element],
) -> (Double, Double) {
  let points = linear_points(e)
  let (x1, y1, x2, y2, _, _) = absolute_coords(cache, e, map)
  let cx = (x1 + x2) / 2.0
  let cy = (y1 + y2) / 2.0
  let global = points.map(fn(p) {
    rotate(e.x + p.0, e.y + p.1, cx, cy, e.angle)
  })
  let mid = if points.length() % 2 == 1 {
    point_global(cache, e, points[points.length() / 2], map)
  } else {
    let index = points.length() / 2 - 1
    segment_mid_point(
      cache,
      e,
      points,
      global[index],
      global[index + 1],
      index + 1,
      map,
    )
  }
  (mid.0 - text.width / 2.0, mid.1 - text.height / 2.0)
}

///|
/// `getMinMaxXYWithBoundText`: grows a line's box to contain its label.
fn bounds_with_text(
  cache : ShapeCache,
  e : @model.Element,
  map : Map[String, @model.Element],
  bounds : (Double, Double, Double, Double),
  text : @model.Element,
) -> (Double, Double, Double, Double) {
  let (bx1, by1, bx2, by2) = bounds
  let mut x1 = bx1
  let mut y1 = by1
  let mut x2 = bx2
  let mut y2 = by2
  let cx = (x1 + x2) / 2.0
  let cy = (y1 + y2) / 2.0
  let (tx1, ty1) = bound_text_position(cache, e, text, map)
  let tx2 = tx1 + text.width
  let ty2 = ty1 + text.height
  let top_left = rotate(x1, y1, cx, cy, e.angle)
  let top_right = rotate(x2, y1, cx, cy, e.angle)
  let tl = rotate(tx1, ty1, cx, cy, -e.angle)
  let tr = rotate(tx2, ty1, cx, cy, -e.angle)
  let bl = rotate(tx1, ty2, cx, cy, -e.angle)
  let br = rotate(tx2, ty2, cx, cy, -e.angle)
  if top_left.0 < top_right.0 && top_left.1 >= top_right.1 {
    x1 = @jsmath.min(x1, bl.0)
    x2 = @jsmath.max(x2, @jsmath.max(tr.0, br.0))
    y1 = @jsmath.min(y1, tl.1)
    y2 = @jsmath.max(y2, br.1)
  } else if top_left.0 >= top_right.0 && top_left.1 > top_right.1 {
    x1 = @jsmath.min(x1, br.0)
    x2 = @jsmath.max(x2, @jsmath.max(tl.0, tr.0))
    y1 = @jsmath.min(y1, bl.1)
    y2 = @jsmath.max(y2, tr.1)
  } else if top_left.0 >= top_right.0 {
    x1 = @jsmath.min(x1, tr.0)
    x2 = @jsmath.max(x2, bl.0)
    y1 = @jsmath.min(y1, br.1)
    y2 = @jsmath.max(y2, tl.1)
  } else if top_left.1 <= top_right.1 {
    x1 = @jsmath.min(x1, @jsmath.min(tr.0, tl.0))
    x2 = @jsmath.max(x2, br.0)
    y1 = @jsmath.min(y1, tr.1)
    y2 = @jsmath.max(y2, bl.1)
  }
  (x1, y1, x2, y2)
}
