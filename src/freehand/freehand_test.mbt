///|
fn parse_taper(s : StringView) -> @freehand.Taper {
  if s == "t" {
    Full
  } else if s == "0" {
    Length(0.0)
  } else {
    Length(@conform.hex_to_double(s))
  }
}

///|
/// Case format: size thinning smoothing streamline simulate last startCap
/// startTaper endCap endTaper easing | "x y p;..." | outline as hex pairs.
fn run_case(line : String) -> Bool raise {
  guard line.split("|").collect() is [opts, pts, out] else { fail("bad case") }
  guard opts.split(" ").collect()
    is [size, thin, smooth, stream, sim, last, scap, staper, ecap, etaper, ease] else {
    fail("bad options")
  }
  let options : @freehand.StrokeOptions = if ease == "x" {
    @freehand.excalidraw_options(
      @conform.hex_to_double(size) / 4.25,
      sim == "1",
      last == "1",
    )
  } else {
    {
      size: @conform.hex_to_double(size),
      thinning: @conform.hex_to_double(thin),
      smoothing: @conform.hex_to_double(smooth),
      streamline: @conform.hex_to_double(stream),
      simulate_pressure: sim == "1",
      last: last == "1",
      easing: fn(t) { t },
      start: @freehand.start_taper(cap=scap == "1", taper=parse_taper(staper)),
      end: @freehand.end_taper(cap=ecap == "1", taper=parse_taper(etaper)),
    }
  }
  let input = []
  if pts != "" {
    for p in pts.split(";") {
      guard p.split(" ").collect() is [x, y, pr] else { fail("bad point") }
      input.push(
        (
          @conform.hex_to_double(x),
          @conform.hex_to_double(y),
          if pr == "-" {
            None
          } else {
            Some(@conform.hex_to_double(pr))
          },
        ),
      )
    }
  }
  let got = @freehand.get_stroke(input, options)
  let want = if out == "" { [] } else { out.split(" ").collect() }
  if got.length() * 2 != want.length() {
    return false
  }
  for i, p in got {
    if !@conform.same_bits(p.0, @conform.hex_to_double(want[2 * i])) ||
      !@conform.same_bits(p.1, @conform.hex_to_double(want[2 * i + 1])) {
      return false
    }
  }
  true
}

///|
test "get_stroke matches perfect-freehand 1.2.0" {
  let mut bad = 0
  for i, line in @fixtures.freehand_cases {
    if !run_case(line) {
      if bad == 0 {
        println("first failing case: \{i}")
      }
      bad += 1
    }
  }
  println(
    "[freehand] total=\{@fixtures.freehand_cases.length()} mismatched=\{bad}",
  )
  assert_eq(bad, 0)
}
