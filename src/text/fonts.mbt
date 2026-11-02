// Font families and their metrics, from Excalidraw's constants.ts and
// fonts/FontMetadata.ts. The vertical position of text in the SVG is computed
// from these tables, not measured, so they have to match.

///|
priv struct Metrics {
  units_per_em : Double
  ascender : Double
  descender : Double
  line_height : Double
}

///|
let virgil : Metrics = {
  units_per_em: 1000.0,
  ascender: 886.0,
  descender: -374.0,
  line_height: 1.25,
}

///|
/// `Fonts.registered.get(family)?.metadata.metrics`: None for families
/// Excalidraw doesn't know.
fn metrics_of(family : Int32) -> Metrics? {
  match family {
    1 | 5 | 1000 => Some(virgil)
    2 =>
      Some({
        units_per_em: 2048.0,
        ascender: 1577.0,
        descender: -471.0,
        line_height: 1.15,
      })
    3 =>
      Some({
        units_per_em: 2048.0,
        ascender: 1900.0,
        descender: -480.0,
        line_height: 1.2,
      })
    6 =>
      Some({
        units_per_em: 1000.0,
        ascender: 1011.0,
        descender: -353.0,
        line_height: 1.35,
      })
    7 =>
      Some({
        units_per_em: 1000.0,
        ascender: 923.0,
        descender: -220.0,
        line_height: 1.15,
      })
    8 =>
      Some({
        units_per_em: 1000.0,
        ascender: 750.0,
        descender: -250.0,
        line_height: 1.25,
      })
    9 =>
      Some({
        units_per_em: 2048.0,
        ascender: 1854.0,
        descender: -434.0,
        line_height: 1.15,
      })
    100 =>
      Some({
        units_per_em: 1000.0,
        ascender: 880.0,
        descender: -144.0,
        line_height: 1.15,
      })
    _ => None
  }
}

///|
/// `getLineHeight(fontFamily)`: the unitless line height of a family.
pub fn line_height(family : Int32) -> Double {
  match metrics_of(family) {
    Some(m) => m.line_height
    None => virgil.line_height
  }
}

///|
/// `getVerticalOffset`: where the first baseline sits for an alphabetic text.
pub fn vertical_offset(
  family : Int32,
  font_size : Double,
  line_height_px : Double,
) -> Double {
  let m = metrics_of(family).unwrap_or(virgil)
  let font_size_em = font_size / m.units_per_em
  let line_gap = (
      line_height_px - font_size_em * m.ascender + font_size_em * m.descender
    ) /
    2.0
  font_size_em * m.ascender + line_gap
}

///|
/// `getFontFamilyString`: the CSS `font-family` of a family id.
pub fn font_family_string(family : Int32) -> String {
  match family {
    1 => "Virgil, Segoe UI Emoji"
    2 => "Helvetica, Segoe UI Emoji"
    3 => "Cascadia, Segoe UI Emoji"
    5 => "Excalifont, Xiaolai, Segoe UI Emoji"
    6 => "Nunito, Segoe UI Emoji"
    7 => "Lilita One, Segoe UI Emoji"
    8 => "Comic Shanns, Segoe UI Emoji"
    9 => "Liberation Sans, Segoe UI Emoji"
    _ => "Segoe UI Emoji"
  }
}
