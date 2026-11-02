// perfect-freehand's public API and the parameters Excalidraw calls it with.

///|
/// How long the taper at one end of the stroke is.
pub(all) enum Taper {
  /// A fixed length; 0 means no taper (also upstream's `false` and `undefined`).
  Length(Double)
  /// Upstream's `true`: the whole stroke.
  Full
}

///|
pub(all) struct TaperOptions {
  cap : Bool
  easing : (Double) -> Double
  taper : Taper
}

///|
pub(all) struct StrokeOptions {
  size : Double
  thinning : Double
  smoothing : Double
  streamline : Double
  simulate_pressure : Bool
  last : Bool
  easing : (Double) -> Double
  start : TaperOptions
  end : TaperOptions
}

///|
/// Upstream's defaults for the start of a stroke, with the given cap and taper.
pub fn start_taper(
  cap~ : Bool = true,
  taper~ : Taper = Length(0.0),
) -> TaperOptions {
  { cap, taper, easing: fn(t) { t * (2.0 - t) }, }
}

///|
/// Upstream's defaults for the end of a stroke, with the given cap and taper.
pub fn end_taper(
  cap~ : Bool = true,
  taper~ : Taper = Length(0.0),
) -> TaperOptions {
  {
    cap,
    taper,
    easing: fn(t) {
      let r = t - 1.0
      r * r * r + 1.0
    },
  }
}

///|
/// `getStroke(points, options)`: the outline polygon of a stroke through
/// `points`, each `(x, y, pressure)`.
pub fn get_stroke(
  points : Array[(Double, Double, Double?)],
  options : StrokeOptions,
) -> Array[(Double, Double)] {
  outline_points(
    stroke_points(points, options.streamline, options.size, options.last),
    options,
  )
}

///|
/// The options of `getFreeDrawSvgPath` in Excalidraw's renderElement.ts.
pub fn excalidraw_options(
  stroke_width : Double,
  simulate_pressure : Bool,
  last : Bool,
) -> StrokeOptions {
  {
    size: stroke_width * 4.25,
    thinning: 0.6,
    smoothing: 0.5,
    streamline: 0.5,
    simulate_pressure,
    last,
    easing: fn(t) { @jsmath.sin(t * @jsmath.PI / 2.0) },
    start: start_taper(),
    end: end_taper(),
  }
}
