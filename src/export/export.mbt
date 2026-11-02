// `exportToSvg` of Excalidraw's scene/export.ts: canvas size, root element,
// background, then the elements in order.

///|
const EXPORT_PADDING : Double = 10.0

///|
pub(all) enum FontMode {
  /// `@font-face` rules pointing at the official font files.
  Url
  /// No fonts, like the official `skipInliningFonts`.
  None
} derive(Eq, Show)

///|
pub(all) enum UnsupportedPolicy {
  Error
  SkipWithWarning
} derive(Eq, Show)

///|
pub(all) struct Warning {
  element_id : String?
  message : String
} derive(Eq, Show)

///|
pub(all) struct ExportResult {
  svg : String
  warnings : Array[Warning]
}

///|
pub suberror ExportError {
  /// An element of this id can't be drawn, and the policy says to fail.
  Unsupported(String, String)
} derive(Show)

///|
/// Why this library doesn't draw an element, if it doesn't.
fn unsupported_reason(e : @model.Element) -> String? {
  match e.kind {
    Unsupported(t) => Some("element type \"\{t}\" isn't supported")
    Arrow({ elbowed: true, .. }) => Some("elbowed arrows aren't supported")
    _ => None
  }
}

///|
/// Applies the policy to unsupported elements and warns about what can't match
/// the official output.
fn check_elements(
  elements : Array[@model.Element],
  policy : UnsupportedPolicy,
  warnings : Array[Warning],
) -> Array[@model.Element] raise ExportError {
  let kept = []
  let seen = {}
  for e in elements {
    match unsupported_reason(e) {
      Some(reason) => {
        if policy == Error {
          raise Unsupported(e.id, reason)
        }
        warnings.push({ element_id: Some(e.id), message: "skipped: \{reason}", })
        continue
      }
      None => ()
    }
    if seen.contains(e.id) {
      warnings.push({
        element_id: Some(e.id),
        message: "duplicate element id; the official export renames the second one randomly",
      })
    }
    seen[e.id] = true
    if e.seed == 0 &&
      !(e.kind is (@model.Text(_) | Image(_) | Frame(_) | MagicFrame(_))) {
      warnings.push({
        element_id: Some(e.id),
        message: "seed 0 is random in the official export, so this shape won't match it",
      })
    }
    kept.push(e)
  }
  kept
}

///|
fn element_map(elements : Array[@model.Element]) -> Map[String, @model.Element] {
  let map = {}
  for e in elements {
    map[e.id] = e
  }
  map
}

///|
/// Renders a scene the way the official `exportToSvg` does. `measure_text` gives
/// the width of frame titles, the only text measured at export time; the default
/// estimates half the font size per character.
pub fn export_to_svg(
  scene : @model.Scene,
  fonts~ : FontMode = Url,
  on_unsupported~ : UnsupportedPolicy = SkipWithWarning,
  measure_text? : (String, String) -> Double,
) -> ExportResult raise ExportError {
  ignore(fonts)
  ignore(measure_text)
  let warnings = []
  let elements = check_elements(scene.elements, on_unsupported, warnings)
  let (min_x, min_y, max_x, max_y) = @shape.common_bounds(
    elements,
    element_map(elements),
  )
  let width = (min_x - max_x).abs() + EXPORT_PADDING * 2.0
  let height = (min_y - max_y).abs() + EXPORT_PADDING * 2.0
  let offset_x = -min_x + EXPORT_PADDING
  let offset_y = -min_y + EXPORT_PADDING
  let root = @svg.Node::element("svg")
  root.set("version", "1.1")
  root.set("xmlns", "http://www.w3.org/2000/svg")
  root.set("viewBox", "0 0 \{@svg.num(width)} \{@svg.num(height)}")
  root.set("width", @svg.num(width))
  root.set("height", @svg.num(height))
  root.append(@svg.Node::comment(" svg-source:excalidraw "))
  root.append(@svg.Node::element("metadata"))
  let defs = @svg.Node::element("defs")
  root.append(defs)
  let style = @svg.Node::element("style")
  style.set("class", "style-fonts")
  style.append(@svg.Node::text("\n      "))
  defs.append(style)
  if scene.export_background && scene.view_background_color != "" {
    let rect = @svg.Node::element("rect")
    rect.set("x", "0")
    rect.set("y", "0")
    rect.set("width", @svg.num(width))
    rect.set("height", @svg.num(height))
    rect.set("fill", scene.view_background_color)
    root.append(rect)
  }
  render_scene(elements, root, {
    offset_x,
    offset_y,
    canvas_background: scene.view_background_color,
    warnings,
  })
  { svg: root.to_html(), warnings, }
}
