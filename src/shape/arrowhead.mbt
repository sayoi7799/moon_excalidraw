// Arrowheads: `getArrowheadPoints` of element/bounds.ts and `getArrowheadShapes`
// of scene/Shape.ts.

///|
fn arrowhead_size(arrowhead : String) -> Double {
  match arrowhead {
    "arrow" => 25.0
    "diamond" | "diamond_outline" => 12.0
    "crowfoot_many" | "crowfoot_one" | "crowfoot_one_or_many" => 20.0
    _ => 15.0
  }
}

///|
fn arrowhead_angle(arrowhead : String) -> Double {
  match arrowhead {
    "bar" => 90.0
    "arrow" => 20.0
    _ => 25.0
  }
}

///|
/// JavaScript's `x || 0`.
fn or_zero(x : Double) -> Double {
  if x == 0.0 || x.is_nan() {
    0.0
  } else {
    x
  }
}

///|
/// The points of an arrowhead. The direction of the tip comes from the first or
/// last Bézier segment rough.js drew, so it depends on the seed. Raises when that
/// segment isn't a Bézier, as upstream's invariant does.
fn arrowhead_points(
  e : @model.Element,
  points : Array[(Double, Double)],
  curve : @moon_rough.Drawable,
  at_start : Bool,
  arrowhead : String,
) -> Array[Double]? raise {
  let ops = curve_path_ops(curve)
  if ops.length() < 1 {
    return None
  }
  let index = if at_start { 1 } else { ops.length() - 1 }
  guard index < ops.length() && ops[index] is BCurveTo(x1, y1, x2, y2, x3, y3) else {
    fail("the arrow's path doesn't end in a curve")
  }
  let p0 = match ops[index - 1] {
    Move(x, y) => (x, y)
    BCurveTo(_, _, _, _, x, y) => (x, y)
    LineTo(_, _) => (0.0, 0.0)
  }
  // Upstream evaluates the curve at 0.3 with the end point's weight first, so
  // this is a point 70% of the way along, not 30%.
  let t = 0.3
  let u = 1.0 - t
  let eq = fn(a : Double, b : Double, c : Double, d : Double) {
    @jsnum.cube(u) * d +
    3.0 * t * (u * u) * c +
    3.0 * (t * t) * u * b +
    a * @jsnum.cube(t)
  }
  let px = eq(p0.0, x1, x2, x3)
  let py = eq(p0.1, y1, y2, y3)
  let (tip_x, tip_y) = if at_start { p0 } else { (x3, y3) }
  let distance = @jsnum.hypot(tip_x - px, tip_y - py)
  let nx = (tip_x - px) / distance
  let ny = (tip_y - py) / distance
  let size = arrowhead_size(arrowhead)
  let n = points.length()
  let (cx, cy) = if at_start { points[0] } else { points[n - 1] }
  let (lx, ly) = if n > 1 {
    if at_start {
      points[1]
    } else {
      points[n - 2]
    }
  } else {
    (0.0, 0.0)
  }
  let length = @jsnum.hypot(cx - lx, cy - ly)
  // Short segments get smaller heads.
  let multiplier = if arrowhead is ("diamond" | "diamond_outline") {
    0.25
  } else {
    0.5
  }
  let min_size = @jsmath.min(size, length * multiplier)
  let xs = tip_x - nx * min_size
  let ys = tip_y - ny * min_size
  if arrowhead is ("dot" | "circle" | "circle_outline") {
    let diameter = @jsnum.hypot(ys - tip_y, xs - tip_x) + e.stroke_width - 2.0
    return Some([tip_x, tip_y, diameter])
  }
  let angle = arrowhead_angle(arrowhead)
  let minus = -angle * @jsmath.PI / 180.0
  let plus = angle * @jsmath.PI / 180.0
  if arrowhead is ("crowfoot_many" | "crowfoot_one_or_many") {
    let (x3, y3) = rotate(tip_x, tip_y, xs, ys, minus)
    let (x4, y4) = rotate(tip_x, tip_y, xs, ys, plus)
    return Some([xs, ys, x3, y3, x4, y4])
  }
  let (x3, y3) = rotate(xs, ys, tip_x, tip_y, minus)
  let (x4, y4) = rotate(xs, ys, tip_x, tip_y, plus)
  if arrowhead is ("diamond" | "diamond_outline") {
    let (px, py) = if n > 1 {
      if at_start {
        points[1]
      } else {
        points[n - 2]
      }
    } else {
      (0.0, 0.0)
    }
    let (ox, oy) = if at_start {
      rotate(
        tip_x + min_size * 2.0,
        tip_y,
        tip_x,
        tip_y,
        @jsnum.atan2(py - tip_y, px - tip_x),
      )
    } else {
      rotate(
        tip_x - min_size * 2.0,
        tip_y,
        tip_x,
        tip_y,
        @jsnum.atan2(tip_y - py, tip_x - px),
      )
    }
    return Some([tip_x, tip_y, x3, y3, ox, oy, x4, y4])
  }
  Some([tip_x, tip_y, x3, y3, x4, y4])
}

///|
/// `getArrowheadShapes`. Upstream mutates the one options object it shares
/// between both ends, so what the start arrowhead changes (no dash, lower
/// roughness) carries over to the end one; `options` plays that part.
fn arrowhead_shapes(
  gen : @moon_rough.Generator,
  e : @model.Element,
  points : Array[(Double, Double)],
  curve : @moon_rough.Drawable,
  at_start : Bool,
  arrowhead : String,
  options : Ref[@moon_rough.Options],
  canvas_background : String,
) -> Array[@moon_rough.Drawable] raise {
  guard arrowhead_points(e, points, curve, at_start, arrowhead) is Some(p) else {
    return []
  }
  match arrowhead {
    "dot" | "circle" | "circle_outline" => {
      options.val = { ..options.val, stroke_line_dash: None, }
      let fill = if arrowhead == "circle_outline" {
        canvas_background
      } else {
        e.stroke_color
      }
      let roughness = or_zero(options.val.roughness.unwrap_or(0.0))
      [
        gen.circle(p[0], p[1], p[2], options={
          ..options.val,
          fill: Some(fill),
          fill_style: Some(Solid),
          stroke: Some(e.stroke_color),
          roughness: Some(@jsmath.min(0.5, roughness)),
        }),
      ]
    }
    "triangle" | "triangle_outline" => {
      options.val = { ..options.val, stroke_line_dash: None, }
      let fill = if arrowhead == "triangle_outline" {
        canvas_background
      } else {
        e.stroke_color
      }
      let roughness = or_zero(options.val.roughness.unwrap_or(0.0))
      [
        gen.polygon([(p[0], p[1]), (p[2], p[3]), (p[4], p[5]), (p[0], p[1])], options={
          ..options.val,
          fill: Some(fill),
          fill_style: Some(Solid),
          roughness: Some(@jsmath.min(1.0, roughness)),
        }),
      ]
    }
    "diamond" | "diamond_outline" => {
      options.val = { ..options.val, stroke_line_dash: None, }
      let fill = if arrowhead == "diamond_outline" {
        canvas_background
      } else {
        e.stroke_color
      }
      let roughness = or_zero(options.val.roughness.unwrap_or(0.0))
      [
        gen.polygon(
          [(p[0], p[1]), (p[2], p[3]), (p[4], p[5]), (p[6], p[7]), (p[0], p[1])],
          options={
            ..options.val,
            fill: Some(fill),
            fill_style: Some(Solid),
            roughness: Some(@jsmath.min(1.0, roughness)),
          },
        ),
      ]
    }
    "crowfoot_one" => [gen.line(p[2], p[3], p[4], p[5], options=options.val)]
    _ => {
      let dash = if e.stroke_style == "dotted" {
        // A tighter dash keeps dotted arrow caps legible.
        let d = dash_dotted(e.stroke_width - 1.0)
        Some([d[0], d[1] - 1.0])
      } else {
        None
      }
      let roughness = or_zero(options.val.roughness.unwrap_or(0.0))
      options.val = {
        ..options.val,
        stroke_line_dash: dash,
        roughness: Some(@jsmath.min(1.0, roughness)),
      }
      let shapes = [
        gen.line(p[2], p[3], p[0], p[1], options=options.val),
        gen.line(p[4], p[5], p[0], p[1], options=options.val),
      ]
      if arrowhead == "crowfoot_one_or_many" {
        if arrowhead_points(e, points, curve, at_start, "crowfoot_one")
          is Some(q) {
          shapes.push(gen.line(q[2], q[3], q[4], q[5], options=options.val))
        }
      }
      shapes
    }
  }
}
