// The Excalidraw element model, after the same normalisation the official
// `restore` applies on export (see restore.mbt).

///|
pub(all) struct Roundness {
  kind : Int32
  value : Double?
}

///|
pub(all) struct BoundElement {
  id : String
  kind : String
}

///|
pub(all) struct Linear {
  points : Array[(Double, Double)]
  start_arrowhead : String?
  end_arrowhead : String?
  elbowed : Bool
}

///|
pub(all) struct FreeDraw {
  points : Array[(Double, Double)]
  pressures : Array[Double]
  simulate_pressure : Bool
}

///|
pub(all) struct TextData {
  text : String
  original_text : String
  font_size : Double
  /// -1 when the file has none; it then behaves like any unknown family.
  font_family : Int32
  text_align : String
  vertical_align : String
  container_id : String?
  line_height : Double
}

///|
pub(all) struct Crop {
  x : Double
  y : Double
  width : Double
  height : Double
  natural_width : Double
  natural_height : Double
}

///|
pub(all) struct ImageData {
  file_id : String?
  scale : (Double, Double)
  crop : Crop?
}

///|
pub(all) enum Kind {
  Rectangle
  Diamond
  Ellipse
  Line(Linear)
  Arrow(Linear)
  Freedraw(FreeDraw)
  Text(TextData)
  Image(ImageData)
  /// The name; None renders as "Frame".
  Frame(String?)
  /// The name; None renders as "AI Frame".
  MagicFrame(String?)
  /// An element this library doesn't draw, with its `type`.
  Unsupported(String)
}

///|
pub(all) struct Element {
  id : String
  kind : Kind
  x : Double
  y : Double
  width : Double
  height : Double
  angle : Double
  stroke_color : String
  background_color : String
  fill_style : String
  stroke_width : Double
  stroke_style : String
  roughness : Double
  opacity : Double
  seed : Int32
  roundness : Roundness?
  bound_elements : Array[BoundElement]
  frame_id : String?
  link : String?
  /// Elements deleted in the file are dropped while parsing. This is only true
  /// for empty text, which `restore` marks deleted but which still counts for
  /// the canvas size, as in the official export.
  is_deleted : Bool
}

///|
pub(all) struct FileData {
  id : String
  mime_type : String
  data_url : String
}

///|
pub(all) struct Scene {
  version : Double?
  elements : Array[Element]
  export_background : Bool
  view_background_color : String
  files : Map[String, FileData]
}

///|
pub suberror ParseError {
  /// The text isn't valid JSON.
  InvalidJson(String)
  /// Valid JSON, but not an Excalidraw scene.
  NotAScene(String)
  /// An element with this id has an unusable field, described by the message.
  InvalidElement(String, String)
} derive(Debug)

///|
pub impl Show for ParseError with fn output(self, logger) {
  match self {
    InvalidJson(message) => logger.write_string("invalid JSON: \{message}")
    NotAScene(message) => logger.write_string("not a scene: \{message}")
    InvalidElement(id, message) =>
      logger.write_string("element \"\{id}\": \{message}")
  }
}
