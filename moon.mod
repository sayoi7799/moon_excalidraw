name = "sayoi7799/moon_excalidraw"

version = "0.1.0"

readme = "README.md"

repository = "https://github.com/sayoi7799/moon_excalidraw"

license = "MIT"

keywords = [ "excalidraw", "svg", "hand-drawn", "rough", "freehand" ]

description = "Renders .excalidraw files to SVG, byte-identical to the official exportToSvg, without a browser."

source = "src"

preferred_target = "js"

import {
  "sayoi7799/moon_rough@0.2.1",
  "moonbitlang/x@0.5.7",
}

warnings = "-implicit_impl_as_method"
