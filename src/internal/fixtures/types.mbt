// Fixture shapes shared by the generated files in this package.

///|
/// Official `restoreElements` output, in the canonical text of model_test.mbt.
pub(all) struct RestoreCase {
  name : String
  input : String
  expected : String
}

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
