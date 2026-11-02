// Fixture shapes shared by the generated files in this package.

///|
/// One whole-scene comparison with the official exportToSvg.
pub(all) struct SceneCase {
  name : String
  /// The .excalidraw JSON.
  input : String
  /// "none" (skipInliningFonts) or "url" (the official font URL fallback).
  fonts : String
  /// The official outerHTML; None when the official code throws.
  expected : String?
}
