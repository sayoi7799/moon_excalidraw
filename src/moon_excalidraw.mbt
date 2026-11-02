// moon_excalidraw renders Excalidraw files to SVG without a browser, producing
// what the official `exportToSvg` produces.
//
//   let scene = @moon_excalidraw.parse_scene(text)
//   let result = @moon_excalidraw.export_to_svg(scene, fonts=None)
//   println(result.svg)
//
// `result.warnings` lists what couldn't be drawn or won't match the official
// export; pass `on_unsupported=Error` to fail instead of skipping.

///|
pub using @model {
  type Scene,
  type Element,
  type Kind,
  type ParseError,
  parse_scene,
}

///|
pub using @export {
  type FontMode,
  type UnsupportedPolicy,
  type Warning,
  type ExportResult,
  type ExportError,
  export_to_svg,
}
