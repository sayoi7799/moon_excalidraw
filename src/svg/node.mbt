// A small SVG tree, serialised the way `outerHTML` does it: the official export
// is compared byte for byte, so attribute order and escaping have to match.

///|
priv enum Content {
  Element(
    tag~ : String,
    attrs~ : Array[(String, String)],
    children~ : Array[Node]
  )
  Text(String)
  Comment(String)
}

///|
pub struct Node {
  priv content : Content
}

///|
pub fn Node::element(tag : String) -> Node {
  { content: Element(tag~, attrs=[], children=[]), }
}

///|
pub fn Node::text(s : String) -> Node {
  { content: Text(s), }
}

///|
pub fn Node::comment(s : String) -> Node {
  { content: Comment(s), }
}

///|
/// `setAttribute`: a new attribute goes last, an existing one keeps its place.
pub fn Node::set(self : Node, name : String, value : String) -> Unit {
  guard self.content is Element(attrs~, ..) else { abort("not an element") }
  for i, attr in attrs {
    if attr.0 == name {
      attrs[i] = (name, value)
      return
    }
  }
  attrs.push((name, value))
}

///|
pub fn Node::append(self : Node, child : Node) -> Unit {
  guard self.content is Element(children~, ..) else { abort("not an element") }
  children.push(child)
}

///|
pub fn Node::prepend(self : Node, child : Node) -> Unit {
  guard self.content is Element(children~, ..) else { abort("not an element") }
  children.insert(0, child)
}

///|
fn write_attr_value(out : StringBuilder, s : String) -> Unit {
  for c in s {
    match c {
      '&' => out.write_string("&amp;")
      '"' => out.write_string("&quot;")
      '\u{A0}' => out.write_string("&nbsp;")
      _ => out.write_char(c)
    }
  }
}

///|
fn write_text(out : StringBuilder, s : String) -> Unit {
  for c in s {
    match c {
      '&' => out.write_string("&amp;")
      '<' => out.write_string("&lt;")
      '>' => out.write_string("&gt;")
      '\u{A0}' => out.write_string("&nbsp;")
      _ => out.write_char(c)
    }
  }
}

///|
fn write_node(out : StringBuilder, node : Node) -> Unit {
  match node.content {
    Text(s) => write_text(out, s)
    Comment(s) => {
      out.write_string("<!--")
      out.write_string(s)
      out.write_string("-->")
    }
    Element(tag~, attrs~, children~) => {
      out.write_char('<')
      out.write_string(tag)
      for attr in attrs {
        out.write_char(' ')
        out.write_string(attr.0)
        out.write_string("=\"")
        write_attr_value(out, attr.1)
        out.write_char('"')
      }
      out.write_char('>')

      for child in children {
        write_node(out, child)
      }
      out.write_string("</")
      out.write_string(tag)
      out.write_char('>')
    }
  }
}

///|
pub fn Node::to_html(self : Node) -> String {
  let out = StringBuilder()
  write_node(out, self)
  out.to_string()
}
