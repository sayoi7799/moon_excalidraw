// A MoonBit port of perfect-freehand 1.2.0 (MIT, Copyright (c) 2021 Stephen
// Ruiz Ltd). This file: the vector helpers of vec.ts.

///|
type Vec = (Double, Double)

///|
fn neg(a : Vec) -> Vec {
  (-a.0, -a.1)
}

///|
fn add(a : Vec, b : Vec) -> Vec {
  (a.0 + b.0, a.1 + b.1)
}

///|
fn sub(a : Vec, b : Vec) -> Vec {
  (a.0 - b.0, a.1 - b.1)
}

///|
fn mul(a : Vec, n : Double) -> Vec {
  (a.0 * n, a.1 * n)
}

///|
fn per(a : Vec) -> Vec {
  (a.1, -a.0)
}

///|
fn dpr(a : Vec, b : Vec) -> Double {
  a.0 * b.0 + a.1 * b.1
}

///|
fn uni(a : Vec) -> Vec {
  let len = @jsnum.hypot(a.0, a.1)
  (a.0 / len, a.1 / len)
}

///|
fn dist2(a : Vec, b : Vec) -> Double {
  let d = sub(a, b)
  d.0 * d.0 + d.1 * d.1
}

///|
fn dist(a : Vec, b : Vec) -> Double {
  @jsnum.hypot(a.1 - b.1, a.0 - b.0)
}

///|
fn rot_around(a : Vec, c : Vec, r : Double) -> Vec {
  let s = @jsmath.sin(r)
  let co = @jsmath.cos(r)
  let px = a.0 - c.0
  let py = a.1 - c.1
  (px * co - py * s + c.0, px * s + py * co + c.1)
}

///|
fn lrp(a : Vec, b : Vec, t : Double) -> Vec {
  add(a, mul(sub(b, a), t))
}

///|
fn prj(a : Vec, b : Vec, c : Double) -> Vec {
  add(a, mul(b, c))
}

///|
/// JavaScript truthiness of a number.
fn truthy(x : Double) -> Bool {
  x != 0.0 && !x.is_nan()
}
