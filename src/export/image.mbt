// Images, from renderer/staticSvgScene.ts. Every file is stored once as a
// `<symbol>`, and each image element is a `<use>` of it.

///|
/// `hashString` of element/index.ts, which names the symbol of a cropped image.
/// Upstream shifts as a 32-bit integer but adds as a double, which matters only
/// once the hash passes 32 bits.
fn hash_string(s : String) -> Int64 {
  let mut hash : Int64 = 5381L
  for i in 0..<s.length() {
    let shifted = hash.to_int() << 5
    hash = shifted.to_int64() + hash + s.code_unit_at(i).to_int().to_int64()
  }
  hash & 0xFFFFFFFFL
}

///|
fn render_image(
  e : @model.Element,
  img : @model.ImageData,
  map : Map[String, @model.Element],
  root : @svg.Node,
  in_anchor : Bool,
  ctx : RenderContext,
  geometry : Placement,
) -> Unit {
  let file = match img.file_id {
    Some(id) => ctx.files.get(id)
    None => None
  }
  guard file is Some(file) else {
    ctx.warnings.push({
      element_id: Some(e.id),
      message: "not drawn: its image file is missing from \"files\"",
    })
    return
  }
  let width = @jsmath.round(e.width)
  let height = @jsmath.round(e.height)
  let mut symbol_id = "image-\{file.id}"
  let mut unc_width = e.width
  let mut unc_height = e.height
  if img.crop is Some(c) {
    unc_width = e.width / (c.width / c.natural_width)
    unc_height = e.height / (c.height / c.natural_height)
    let hash = hash_string("\{@svg.num(unc_width)}x\{@svg.num(unc_height)}")
    symbol_id = "image-crop-\{file.id}-\{hash}"
  }
  if !ctx.symbols.contains(symbol_id) {
    ctx.symbols[symbol_id] = true
    let symbol = @svg.Node::element("symbol")
    symbol.set("id", symbol_id)
    let image = @svg.Node::element("image")
    image.set("href", file.data_url)
    image.set("preserveAspectRatio", "none")
    if img.crop is Some(_) {
      image.set("width", @svg.num(unc_width))
      image.set("height", @svg.num(unc_height))
    } else {
      image.set("width", "100%")
      image.set("height", "100%")
    }
    symbol.append(image)
    // Upstream puts it in the first <defs> below the root, and inside the link
    // when there is one, where there is no <defs>.
    if in_anchor {
      root.prepend(symbol)
    } else {
      ctx.defs.prepend(symbol)
    }
  }
  let use_ = @svg.Node::element("use")
  use_.set("href", "#\{symbol_id}")
  let mut crop_x = 0.0
  let mut crop_y = 0.0
  if img.crop is Some(c) {
    crop_x = c.x / (c.natural_width / unc_width)
    crop_y = c.y / (c.natural_height / unc_height)
  }
  let center_x = geometry.cx + crop_x
  let center_y = geometry.cy + crop_y
  use_.set("width", @svg.num(width + crop_x))
  use_.set("height", @svg.num(height + crop_y))
  use_.set("opacity", @svg.num(geometry.opacity))
  if img.scale.0 != 1.0 || img.scale.1 != 1.0 {
    use_.set(
      "transform",
      "translate(\{@svg.num(center_x)} \{@svg.num(center_y)}) scale(\{@svg.num(img.scale.0)} \{@svg.num(img.scale.1)}) translate(\{@svg.num(-center_x)} \{@svg.num(-center_y)})",
    )
  }
  let g = @svg.Node::element("g")
  if img.crop is Some(_) {
    let mask = @svg.Node::element("mask")
    mask.set("id", "mask-image-crop-\{e.id}")
    mask.set("fill", "#fff")
    let rect = @svg.Node::element("rect")
    rect.set("x", @svg.num(crop_x))
    rect.set("y", @svg.num(crop_y))
    rect.set("width", @svg.num(width))
    rect.set("height", @svg.num(height))
    mask.append(rect)
    root.append(mask)
    g.set("mask", "url(#mask-image-crop-\{e.id})")
  }
  g.append(use_)
  g.set(
    "transform",
    "translate(\{@svg.num(geometry.offset_x - crop_x)} \{@svg.num(geometry.offset_y - crop_y)}) rotate(\{@svg.num(geometry.degree)} \{@svg.num(center_x)} \{@svg.num(center_y)})",
  )
  if e.roundness is Some(_) {
    let clip = @svg.Node::element("clipPath")
    clip.set("id", "image-clipPath-\{e.id}")
    let rect = @svg.Node::element("rect")
    let radius = @shape.corner_radius(@jsmath.min(e.width, e.height), e)
    rect.set("width", @svg.num(e.width))
    rect.set("height", @svg.num(e.height))
    rect.set("rx", @svg.num(radius))
    rect.set("ry", @svg.num(radius))
    clip.append(rect)
    root.append(clip)
    g.set("clip-path", "url(#image-clipPath-\{e.id})")
  }
  match wrap_in_frame_clip(e, map, [g]) {
    Some(wrapped) => root.append(wrapped)
    None => root.append(g)
  }
}
