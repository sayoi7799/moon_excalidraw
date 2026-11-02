// Classifies how our SVG differs from the official one, for the test report.

///|
pub(all) enum DiffKind {
  Identical
  /// Different elements or attribute names.
  Structural
  /// Same structure, some attribute or text differs beyond numbers.
  Attribute
  /// Everything but numbers is the same; the largest difference between them.
  Numeric(Double)
} derive(Eq, Debug)

///|
fn is_number_char(c : Char) -> Bool {
  (c >= '0' && c <= '9') || c == '.'
}

///|
/// Splits text into its numbers and everything between them.
fn split_numbers(s : String) -> (Array[String], Array[Double]) {
  let chars = s.to_array()
  let text = []
  let numbers = []
  let current = StringBuilder()
  let mut i = 0
  while i < chars.length() {
    if is_number_char(chars[i]) {
      let mut j = i
      while j < chars.length() && is_number_char(chars[j]) {
        j += 1
      }
      // An exponent belongs to the number.
      if j + 1 < chars.length() &&
        chars[j] == 'e' &&
        (
          chars[j + 1] == '-' ||
          chars[j + 1] == '+' ||
          (chars[j + 1] >= '0' && chars[j + 1] <= '9')
        ) {
        j += 2
        while j < chars.length() && chars[j] >= '0' && chars[j] <= '9' {
          j += 1
        }
      }
      let negative = i > 0 && chars[i - 1] == '-'
      let v = @jsmath.parse_float(String::from_array(chars[i:j].to_owned()))
      numbers.push(if negative { -v } else { v })
      text.push(current.to_string())
      current.reset()
      i = j
    } else {
      current.write_char(chars[i])
      i += 1
    }
  }
  text.push(current.to_string())
  (text, numbers)
}

///|
/// The markup with attribute values and text removed.
fn skeleton(s : String) -> String {
  let out = StringBuilder()
  let mut in_tag = false
  let mut in_value = false
  for c in s {
    if in_value {
      if c == '"' {
        in_value = false
      }
    } else if in_tag {
      if c == '"' {
        in_value = true
      } else {
        out.write_char(c)
      }
      if c == '>' {
        in_tag = false
      }
    } else if c == '<' {
      in_tag = true
      out.write_char(c)
    }
  }
  out.to_string()
}

///|
pub fn classify(actual : String, expected : String) -> DiffKind {
  if actual == expected {
    return Identical
  }
  if skeleton(actual) != skeleton(expected) {
    return Structural
  }
  let (text_a, nums_a) = split_numbers(actual)
  let (text_b, nums_b) = split_numbers(expected)
  if text_a != text_b || nums_a.length() != nums_b.length() {
    return Attribute
  }
  let mut max = 0.0
  for i, a in nums_a {
    let d = (a - nums_b[i]).abs()
    if d > max {
      max = d
    }
  }
  Numeric(max)
}

///|
pub(all) struct Stats {
  suite : String
  total : Int32
  identical : Int32
  failed : Int32
  structural : Int32
  attribute : Int32
  numeric : Int32
  max_delta : Double
  /// Names of the first failures, for the test output.
  failures : Array[String]
}

///|
pub impl Show for Stats with fn output(self, logger) {
  logger.write_string(
    "suite=\{self.suite} total=\{self.total} identical=\{self.identical} structural=\{self.structural} attribute=\{self.attribute} numeric=\{self.numeric} max_delta=\{self.max_delta}",
  )
}

///|
/// Renders every case and compares it with the official output. `render`
/// returns None when this library reports an error, which only matches a case
/// where the official code throws too.
pub fn run(
  suite : String,
  cases : Array[@fixtures.SceneCase],
  render : (@fixtures.SceneCase) -> String?,
) -> Stats {
  let mut identical = 0
  let mut structural = 0
  let mut attribute = 0
  let mut numeric = 0
  let mut max_delta = 0.0
  let failures = []
  for case in cases {
    let kind = match (render(case), case.expected) {
      (None, None) => Identical
      (Some(a), Some(e)) => classify(a, e)
      _ => Structural
    }
    match kind {
      Identical => identical += 1
      Structural => structural += 1
      Attribute => attribute += 1
      Numeric(d) => {
        numeric += 1
        if d > max_delta {
          max_delta = d
        }
      }
    }
    if kind != Identical && failures.length() < 5 {
      failures.push(case.name)
    }
  }
  {
    suite,
    total: cases.length(),
    identical,
    failed: cases.length() - identical,
    structural,
    attribute,
    numeric,
    max_delta,
    failures,
  }
}
