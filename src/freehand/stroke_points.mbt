// perfect-freehand's getStrokePoints: smooths the raw input into stroke points.

///|
priv struct StrokePoint {
  point : Vec
  pressure : Double
  mut vector : Vec
  distance : Double
  running_length : Double
}

///|
/// `n[2] >= 0 ? n[2] : fallback`, where a missing or NaN pressure compares false.
fn pressure_or(p : Double?, fallback : Double) -> Double {
  match p {
    Some(v) if v >= 0.0 => v
    _ => fallback
  }
}

///|
fn stroke_points(
  points : Array[(Double, Double, Double?)],
  streamline : Double,
  size : Double,
  last : Bool,
) -> Array[StrokePoint] {
  if points.length() == 0 {
    return []
  }
  let t = 0.15 + (1.0 - streamline) * 0.85
  // Strokes of one or two points are padded so the outline has a direction.
  let pts = if points.length() == 2 {
    let a = (points[0].0, points[0].1)
    let b = (points[1].0, points[1].1)
    let out = [points[0]]
    for i in 1..<5 {
      let p = lrp(a, b, i.to_double() / 4.0)
      out.push((p.0, p.1, None))
    }
    out
  } else if points.length() == 1 {
    let p = points[0]
    [p, (p.0 + 1.0, p.1 + 1.0, p.2)]
  } else {
    points
  }
  let first = pts[0]
  let result = [
    {
      point: (first.0, first.1),
      pressure: pressure_or(first.2, 0.25),
      vector: (1.0, 1.0),
      distance: 0.0,
      running_length: 0.0,
    },
  ]
  let mut has_reached_min_length = false
  let mut running_length = 0.0
  let mut prev = result[0]
  let last_index = pts.length() - 1
  for i in 1..<pts.length() {
    let raw = pts[i]
    let point = if last && i == last_index {
      (raw.0, raw.1)
    } else {
      lrp(prev.point, (raw.0, raw.1), t)
    }
    if prev.point.0 == point.0 && prev.point.1 == point.1 {
      continue
    }
    let d = dist(point, prev.point)
    running_length += d
    if i < last_index && !has_reached_min_length {
      if running_length < size {
        continue
      }
      has_reached_min_length = true
    }
    prev = {
      point,
      pressure: pressure_or(raw.2, 0.5),
      vector: uni(sub(prev.point, point)),
      distance: d,
      running_length,
    }
    result.push(prev)
  }
  result[0].vector = if result.length() > 1 {
    result[1].vector
  } else {
    (0.0, 0.0)
  }
  result
}
