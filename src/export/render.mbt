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
  let degree = 180.0 * e.angle / @jsmath.PI
  let opacity = 100.0 * e.opacity / 10000.0
  match e.kind {
    Rectangle | Diamond | Ellipse => {
      let shapes = @shape.generate(e, ctx.canvas_background)
      let node = draw_rough(shapes[0])
      set_opacity(node, opacity)
      node.set("stroke-linecap", "round")
      set_transform(node, offset_x, offset_y, degree, cx, cy)
      svg_root.append(node)
    }
    Line(l) | Arrow(l) => {
      let mask = @svg.Node::element("mask")
      let group = @svg.Node::element("g")
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
      svg_root.append(group)
      svg_root.append(mask)
    }
    _ => ()
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
    // The official export logs a failing element and carries on without it.
    render_element(e, map, root, e.x + ctx.offset_x, e.y + ctx.offset_y, ctx) catch {
      _ =>
        ctx.warnings.push({
          element_id: Some(e.id),
          message: "skipped: its shape has invalid path data",
        })
    }
  }
}
