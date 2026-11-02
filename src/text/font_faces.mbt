// The `@font-face` rules the official export writes into the SVG, from
// `Fonts.generateFontFaceDeclarations` and `ExcalidrawFontFace.toCSS`. The
// official export embeds subsetted font data; without network access it falls
// back to naming each font file by URL, which is what this reproduces.

///|
/// One font file: the family it belongs to, where it is, and the code points it
/// covers, as (low, high) pairs.
pub(all) struct FaceData {
  family : String
  font : Int32
  url : String
  ranges : Array[Int32]
}

///|
/// Xiaolai, the hand-drawn CJK font Excalifont falls back to.
const XIAOLAI : Int32 = 100

///|
const EXCALIFONT : Int32 = 5

///|
fn in_ranges(ranges : Array[Int32], code : Int32) -> Bool {
  let mut i = 0
  while i + 1 < ranges.length() {
    if code >= ranges[i] && code <= ranges[i + 1] {
      return true
    }
    i += 2
  }
  false
}

///|
/// `containsCJK`.
fn contains_cjk(chars : Array[Char]) -> Bool {
  chars.iter().any(fn(c) { in_ranges(cjk_ranges, c.to_int()) })
}

///|
/// The rules for the texts of a scene, each given as its font family and the
/// original text. Faces are listed in family order and then file order, and a
/// rule is written once even if two families ask for the same file.
pub fn font_face_declarations(texts : Array[(Int32, String)]) -> Array[String] {
  let families : Array[Int32] = []
  let chars : Map[Int32, Array[Char]] = Map([])
  for text in texts {
    let (family, original) = text
    if !families.contains(family) {
      families.push(family)
    }
    for c in original {
      let seen = match chars.get(family) {
        Some(list) => list
        None => {
          let list = []
          chars[family] = list
          list
        }
      }
      if !seen.contains(c) {
        seen.push(c)
      }
    }
  }
  // Excalifont draws characters it doesn't have with Xiaolai.
  if families.contains(EXCALIFONT) {
    let wanted = chars.get(EXCALIFONT).unwrap_or([])
    if contains_cjk(wanted) {
      chars[XIAOLAI] = wanted.copy()
      families.insert(0, XIAOLAI)
    }
  }
  let declarations : Array[String] = []
  for family in families {
    let wanted = chars.get(family).unwrap_or([])
    for face in font_face_table {
      if face.font == family &&
        wanted.iter().any(fn(c) { in_ranges(face.ranges, c.to_int()) }) {
        let rule = "@font-face { font-family: \{face.family}; src: url(\{face.url}); }"
        if !declarations.contains(rule) {
          declarations.push(rule)
        }
      }
    }
  }
  declarations
}
