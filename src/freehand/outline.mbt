// perfect-freehand's getStrokeOutlinePoints: offsets the stroke points to both
// sides, adds caps, and joins everything into one polygon.

///|
const RATE_OF_PRESSURE_CHANGE : Double = 0.275

///|
/// `Math.PI + 1e-4`: the upstream constant that makes arcs slightly overlap.
const FIXED_PI : Double = 3.1416926535897933

///|
fn stroke_radius(
  size : Double,
  thinning : Double,
  pressure : Double,
  easing : (Double) -> Double,
) -> Double {
  size * easing(0.5 - thinning * (0.5 - pressure))
}

///|
fn resolve_taper(taper : Taper, size : Double, total : Double) -> Double {
  match taper {
    Length(v) => v
    Full => @jsmath.max(size, total)
  }
}

///|
fn simulated_pressure(
  prev : Double,
  distance : Double,
  size : Double,
) -> Double {
  let sp = @jsmath.min(1.0, distance / size)
  let rp = @jsmath.min(1.0, 1.0 - sp)
  @jsmath.min(1.0, prev + (rp - prev) * (sp * RATE_OF_PRESSURE_CHANGE))
}

///|
fn outline_points(
  points : Array[StrokePoint],
  o : StrokeOptions,
) -> Array[(Double, Double)] {
  let size = o.size
  let thinning = o.thinning
  if points.length() == 0 || size <= 0.0 {
    return []
  }
  let last_index = points.length() - 1
  let total = points[last_index].running_length
  let taper_start = resolve_taper(o.start.taper, size, total)
  let taper_end = resolve_taper(o.end.taper, size, total)
  let min_distance = {
    let x = size * o.smoothing
    x * x
  }
  let left : Array[Vec] = []
  let right : Array[Vec] = []
  let mut prev_pressure = points[0].pressure
  for i in 0..<@cmp.minimum(points.length(), 10) {
    let mut pressure = points[i].pressure
    if o.simulate_pressure {
      pressure = simulated_pressure(prev_pressure, points[i].distance, size)
    }
    prev_pressure = (prev_pressure + pressure) / 2.0
  }
  let mut radius = stroke_radius(
    size,
    thinning,
    points[last_index].pressure,
    o.easing,
  )
  let mut first_radius : Double? = None
  let mut prev_vector = points[0].vector
  let mut prev_left = points[0].point
  let mut prev_right = prev_left
  let mut tl = prev_left
  let mut tr = prev_right
  let mut prev_sharp = false
  for i in 0..<points.length() {
    let cur = points[i]
    let mut pressure = cur.pressure
    let point = cur.point
    let vector = cur.vector
    // Skip the tail of the stroke: its noise would distort the end cap.
    if i < last_index && total - cur.running_length < 3.0 {
      continue
    }
    if truthy(thinning) {
      if o.simulate_pressure {
        pressure = simulated_pressure(prev_pressure, cur.distance, size)
      }
      radius = stroke_radius(size, thinning, pressure, o.easing)
    } else {
      radius = size / 2.0
    }
    if first_radius is None {
      first_radius = Some(radius)
    }
    let ts = if cur.running_length < taper_start {
      (o.start.easing)(cur.running_length / taper_start)
    } else {
      1.0
    }
    let te = if total - cur.running_length < taper_end {
      (o.end.easing)((total - cur.running_length) / taper_end)
    } else {
      1.0
    }
    radius = @jsmath.max(0.01, radius * @jsmath.min(ts, te))
    let next_vector = if i < last_index { points[i + 1].vector } else { vector }
    let next_dpr = if i < last_index { dpr(vector, next_vector) } else { 1.0 }
    let is_sharp = dpr(vector, prev_vector) < 0.0 && !prev_sharp
    let next_sharp = next_dpr < 0.0
    if is_sharp || next_sharp {
      // A sharp corner gets a full round cap on both sides.
      let offset = mul(per(prev_vector), radius)
      let step = 1.0 / 13.0
      let mut t = 0.0
      while t <= 1.0 {
        tl = rot_around(sub(point, offset), point, FIXED_PI * t)
        left.push(tl)
        tr = rot_around(add(point, offset), point, FIXED_PI * -t)
        right.push(tr)
        t += step
      }
      prev_left = tl
      prev_right = tr
      if next_sharp {
        prev_sharp = true
      }
      continue
    }
    prev_sharp = false
    if i == last_index {
      let offset = mul(per(vector), radius)
      left.push(sub(point, offset))
      right.push(add(point, offset))
      continue
    }
    let offset = mul(per(lrp(next_vector, vector, next_dpr)), radius)
    tl = sub(point, offset)
    if i <= 1 || dist2(prev_left, tl) > min_distance {
      left.push(tl)
      prev_left = tl
    }
    tr = add(point, offset)
    if i <= 1 || dist2(prev_right, tr) > min_distance {
      right.push(tr)
      prev_right = tr
    }
    prev_pressure = pressure
    prev_vector = vector
  }
  let first_point = points[0].point
  let last_point = if points.length() > 1 {
    points[last_index].point
  } else {
    add(points[0].point, (1.0, 1.0))
  }
  let start_cap : Array[Vec] = []
  let end_cap : Array[Vec] = []
  let tapered = truthy(taper_start) || truthy(taper_end)
  if points.length() == 1 {
    if !tapered || o.last {
      // A dot.
      let r = match first_radius {
        Some(v) if truthy(v) => v
        _ => radius
      }
      let start = prj(first_point, uni(per(sub(first_point, last_point))), -r)
      let dot = []
      let step = 1.0 / 13.0
      let mut t = step
      while t <= 1.0 {
        dot.push(rot_around(start, first_point, FIXED_PI * 2.0 * t))
        t += step
      }
      return dot
    }
  } else {
    if !(truthy(taper_start) || (truthy(taper_end) && points.length() == 1)) {
      if o.start.cap {
        let step = 1.0 / 13.0
        let mut t = step
        while t <= 1.0 {
          start_cap.push(rot_around(right[0], first_point, FIXED_PI * t))
          t += step
        }
      } else {
        let corners = sub(left[0], right[0])
        let a = mul(corners, 0.5)
        let b = mul(corners, 0.51)
        start_cap.push(sub(first_point, a))
        start_cap.push(sub(first_point, b))
        start_cap.push(add(first_point, b))
        start_cap.push(add(first_point, a))
      }
    }
    let direction = per(neg(points[last_index].vector))
    if truthy(taper_end) || (truthy(taper_start) && points.length() == 1) {
      end_cap.push(last_point)
    } else if o.end.cap {
      let start = prj(last_point, direction, radius)
      let step = 1.0 / 29.0
      let mut t = step
      while t < 1.0 {
        end_cap.push(rot_around(start, last_point, FIXED_PI * 3.0 * t))
        t += step
      }
    } else {
      end_cap.push(add(last_point, mul(direction, radius)))
      end_cap.push(add(last_point, mul(direction, radius * 0.99)))
      end_cap.push(sub(last_point, mul(direction, radius * 0.99)))
      end_cap.push(sub(last_point, mul(direction, radius)))
    }
  }
  right.rev_in_place()
  [..left, ..end_cap, ..right, ..start_cap]
}
