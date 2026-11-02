// `renderElementToSvg` and `renderSceneToSvg` of Excalidraw's
// renderer/staticSvgScene.ts.

///|
const MAX_DECIMALS : Int32 = 2

///|
priv struct RenderContext {
  offset_x : Double
  offset_y : Double
  canvas_background : String
  warnings : Array[Warning]
  cache : @shape.ShapeCache
  defs : @svg.Node
  files : Map[String, @model.FileData]
  /// Ids of the image symbols written so far.
  symbols : Map[String, Bool]
}

///|
/// Where an element goes: its offset, rotation, and the numbers derived from them.
priv struct Placement {
  offset_x : Double
  offset_y : Double
  degree : Double
  cx : Double
  cy : Double
  opacity : Double
}

///|
/// `RoughSVG.draw`: a `<g>` with one `<path>` per op set.
fn draw_rough(d : @moon_rough.Drawable) -> @svg.Node {
  let o = d.options
  let g = @svg.Node::element("g")
  let fill = o.fill.unwrap_or("")
  for set in d.sets {
    let path = @svg.Node::element("path")
    path.set("d", @moon_rough.ops_to_path(set, fixed_decimals=MAX_DECIMALS))
    match set.kind {
      Path => {
        path.set("stroke", o.stroke)
        path.set("stroke-width", @svg.num(o.stroke_width))
        path.set("fill", "none")
        match o.stroke_line_dash {
          Some(dash) =>
            path.set("stroke-dasharray", dash.map(@svg.num).join(" "))
          None => ()
        }
      }
      FillPath => {
        path.set("stroke", "none")
        path.set("stroke-width", "0")
        path.set("fill", fill)
        if d.shape is (Curve | Polygon) {
          path.set("fill-rule", "evenodd")
        }
      }
      FillSketch => {
        path.set("stroke", fill)
        let weight = if o.fill_weight < 0.0 {
          o.stroke_width / 2.0
        } else {
          o.fill_weight
        }
        path.set("stroke-width", @svg.num(weight))
        path.set("fill", "none")
      }
    }
    g.append(path)
  }
  g
}

///|
/// JavaScript's `x || 0`.
fn or_zero(x : Double) -> Double {
  if x.is_nan() {
    0.0
  } else {
    x
  }
}

///|
fn set_transform(
  node : @svg.Node,
  offset_x : Double,
  offset_y : Double,
  degree : Double,
  cx : Double,
  cy : Double,
) -> Unit {
  node.set(
    "transform",
    "translate(\{@svg.num(or_zero(offset_x))} \{@svg.num(or_zero(offset_y))}) rotate(\{@svg.num(degree)} \{@svg.num(cx)} \{@svg.num(cy)})",
  )
}

///|
fn set_opacity(node : @svg.Node, opacity : Double) -> Unit {
  if opacity != 1.0 {
    node.set("stroke-opacity", @svg.num(opacity))
    node.set("fill-opacity", @svg.num(opacity))
  }
}

///|
/// `getContainingFrame`. Upstream takes whatever element the id names, a frame
/// or not.
fn containing_frame(
  e : @model.Element,
  map : Map[String, @model.Element],
) -> @model.Element? {
  match e.frame_id {
    Some(id) => map.get(id)
    None => None
  }
}

///|
/// `maybeWrapNodesInFrameClipPath`: elements in a frame are drawn inside a group
/// clipped to it.
fn wrap_in_frame_clip(
  e : @model.Element,
  map : Map[String, @model.Element],
  nodes : Array[@svg.Node],
) -> @svg.Node? {
  match containing_frame(e, map) {
    Some(frame) => {
      let g = @svg.Node::element("g")
      g.set("clip-path", "url(#\{frame.id})")
      for node in nodes {
        g.append(node)
      }
      Some(g)
    }
    None => None
  }
}

///|
/// Adds a node to the root, inside the clip group when it has one.
fn add_wrapped(
  e : @model.Element,
  map : Map[String, @model.Element],
  root : @svg.Node,
  node : @svg.Node,
) -> Unit {
  match wrap_in_frame_clip(e, map, [node]) {
    Some(g) => root.append(g)
    None => root.append(node)
  }
}

///|
fn render_element(
  e : @model.Element,
  map : Map[String, @model.Element],
  svg_root : @svg.Node,
  offset_x : Double,
  offset_y : Double,
  ctx : RenderContext,
) -> Unit raise {
  let (x1, y1, x2, y2, _, _) = @shape.absolute_coords(ctx.cache, e, map)
  let cx = (x2 - x1) / 2.0 - (e.x - x1)
  let cy = (y2 - y1) / 2.0 - (e.y - y1)
  // A label on an arrow sits where the arrow puts it, not where it is stored.
  let (cx, cy, offset_x, offset_y) = match e.kind {
    Text({ container_id: Some(id), .. }) =>
      match map.get(id) {
        Some({ kind: Arrow(_), .. } as container) => {
          let (cx1, cy1, cx2, cy2, _, _) = @shape.absolute_coords(
            ctx.cache,
            container,
            map,
          )
          let (bx, by) = @shape.bound_text_position(
            ctx.cache,
            container,
            e,
            map,
          )
          (
            (cx2 - cx1) / 2.0 - (bx - cx1),
            (cy2 - cy1) / 2.0 - (by - cy1),
            offset_x + bx - e.x,
            offset_y + by - e.y,
          )
        }
        _ => (cx, cy, offset_x, offset_y)
      }
    _ => (cx, cy, offset_x, offset_y)
  }
  let degree = 180.0 * e.angle / @jsmath.PI
  // An element with a link is drawn inside an <a>.
  let mut root = svg_root
  let in_anchor = e.link is Some(_)
  if e.link is Some(link) {
    let anchor = @svg.Node::element("a")
    anchor.set("href", @model.normalize_link(link))
    root.append(anchor)
    root = anchor
  }
  let frame_opacity = match containing_frame(e, map) {
    Some(frame) => frame.opacity
    None => 100.0
  }
  let opacity = frame_opacity * e.opacity / 10000.0
  match e.kind {
    Rectangle | Diamond | Ellipse => {
      let shapes = @shape.generate(e, ctx.canvas_background)
      let node = draw_rough(shapes[0])
      set_opacity(node, opacity)
      node.set("stroke-linecap", "round")
      set_transform(node, offset_x, offset_y, degree, cx, cy)
      add_wrapped(e, map, root, node)
    }
    Text(t) => {
      let node = @svg.Node::element("g")
      set_opacity(node, opacity)
      set_transform(node, offset_x, offset_y, degree, cx, cy)
      let line_height_px = t.font_size * t.line_height
      let horizontal = match t.text_align {
        "center" => e.width / 2.0
        "right" => e.width
        _ => 0.0
      }
      let vertical = @text.vertical_offset(
        t.font_family,
        t.font_size,
        line_height_px,
      )
      let rtl = @text.is_rtl(t.text)
      let anchor = if t.text_align == "center" {
        "middle"
      } else if t.text_align == "right" || rtl {
        "end"
      } else {
        "start"
      }
      for i, line in @text.split_lines(t.text) {
        let text = @svg.Node::element("text")
        text.append(@svg.Node::text(line))
        text.set("x", @svg.num(horizontal))
        text.set("y", @svg.num(i.to_double() * line_height_px + vertical))
        text.set("font-family", @text.font_family_string(t.font_family))
        text.set("font-size", @svg.num(t.font_size) + "px")
        text.set("fill", e.stroke_color)
        text.set("text-anchor", anchor)
        text.set("style", "white-space: pre;")
        text.set("direction", if rtl { "rtl" } else { "ltr" })
        text.set("dominant-baseline", "alphabetic")
        node.append(text)
      }
      add_wrapped(e, map, root, node)
    }
    Line(l) | Arrow(l) => {
      let mask = @svg.Node::element("mask")
      let bound = @shape.bound_text(e, map)
      if bound is Some(text) {
        let off_x = or_zero(offset_x)
        let off_y = or_zero(offset_y)
        mask.set("id", "mask-\{e.id}")
        let visible = @svg.Node::element("rect")
        visible.set("x", "0")
        visible.set("y", "0")
        visible.set("fill", "#fff")
        visible.set("width", @svg.num(e.width + 100.0 + off_x))
        visible.set("height", @svg.num(e.height + 100.0 + off_y))
        mask.append(visible)
        let hidden = @svg.Node::element("rect")
        let (bx, by) = @shape.bound_text_position(ctx.cache, e, text, map)
        hidden.set("x", @svg.num(off_x + bx - e.x))
        hidden.set("y", @svg.num(off_y + by - e.y))
        hidden.set("fill", "#000")
        hidden.set("width", @svg.num(text.width))
        hidden.set("height", @svg.num(text.height))
        hidden.set("opacity", "1")
        mask.append(hidden)
      }
      let group = @svg.Node::element("g")
      if bound is Some(_) {
        group.set("mask", "url(#mask-\{e.id})")
      }
      group.set("stroke-linecap", "round")
      let shapes = @shape.generate(e, ctx.canvas_background)
      ctx.cache.mark(e)
      let filled_loop = e.kind is Line(_) &&
        @shape.is_path_a_loop(l.points) &&
        e.background_color != "transparent"
      for shape in shapes {
        let node = draw_rough(shape)
        set_opacity(node, opacity)
        set_transform(node, offset_x, offset_y, degree, cx, cy)
        if filled_loop {
          node.set("fill-rule", "evenodd")
        }
        group.append(node)
      }
      match wrap_in_frame_clip(e, map, [group, mask]) {
        Some(g) => root.append(g)
        None => {
          root.append(group)
          root.append(mask)
        }
      }
    }
    Freedraw(_) => {
      let shapes = @shape.generate(e, ctx.canvas_background)
      let node = if shapes.length() > 0 {
        draw_rough(shapes[0])
      } else {
        @svg.Node::element("g")
      }
      set_opacity(node, opacity)
      set_transform(node, offset_x, offset_y, degree, cx, cy)
      node.set("stroke", "none")
      let path = @svg.Node::element("path")
      path.set("fill", e.stroke_color)
      path.set("d", @shape.freedraw_path(e))
      node.append(path)
      add_wrapped(e, map, root, node)
    }
    Image(img) =>
      render_image(e, img, map, root, in_anchor, ctx, {
        offset_x,
        offset_y,
        degree,
        cx,
        cy,
        opacity,
      })
    Frame(_) | MagicFrame(_) => {
      let rect = @svg.Node::element("rect")
      set_transform(rect, offset_x, offset_y, degree, cx, cy)
      rect.set("width", @svg.num(e.width) + "px")
      rect.set("height", @svg.num(e.height) + "px")
      rect.set("rx", FRAME_RADIUS)
      rect.set("ry", FRAME_RADIUS)
      rect.set("fill", "none")
      rect.set("stroke", "#bbb")
      rect.set("stroke-width", "2")
      root.append(rect)
    }
    Unsupported(_) => ()
  }
}

///|
fn render_scene(
  elements : Array[@model.Element],
  root : @svg.Node,
  ctx : RenderContext,
) -> Unit {
  let map = element_map(elements)
  for e in elements {
    if e.is_deleted {
      continue
    }
    // A label is drawn right after the shape that holds it. A text whose
    // container exists but doesn't list it is never drawn.
    if e.kind is Text({ container_id: Some(id), .. }) && map.contains(id) {
      continue
    }
    // The official export logs a failing element and carries on without it.
    try {
      render_element(e, map, root, e.x + ctx.offset_x, e.y + ctx.offset_y, ctx)
      if @shape.bound_text(e, map) is Some(text) {
        render_element(
          text,
          map,
          root,
          text.x + ctx.offset_x,
          text.y + ctx.offset_y,
          ctx,
        )
      }
    } catch {
      _ =>
        ctx.warnings.push({
          element_id: Some(e.id),
          message: "skipped: its shape could not be drawn",
        })
    }
  }
}
