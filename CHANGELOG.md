# Changelog

## 0.1.0 (unreleased)

First version.

- Reads `.excalidraw` files and writes the SVG of Excalidraw 0.18.1's `exportToSvg`,
  byte for byte, for rectangles, diamonds, ellipses, lines, arrows (with all arrowhead
  styles), freedraw, text (also bound to shapes and arrows), images, frames and links.
- `FontMode::Url` and `FontMode::None`.
- Unsupported elements (embeddable, iframe, elbow arrows) fail or are skipped with a
  warning, as the caller chooses.
- `excalidraw2svg` command and a gallery page that sets each scene beside the
  official output.
- `perfect-freehand` 1.2.0 `getStroke` ported, bit for bit.
- 1176 scenes, 322 freehand strokes and 50 restore cases compared with the official
  package; see the README.
