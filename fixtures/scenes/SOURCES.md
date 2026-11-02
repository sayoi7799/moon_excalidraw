# Where the real scenes come from

The `real-*.excalidraw` files were drawn with the mouse in the Excalidraw web app
at https://excalidraw.com on 2026-11-02 (driven through the browser pane of the
tool that built this project), then read from the editor's own storage
(`localStorage["excalidraw"]`) without changes. They are what the current
editor writes, not what Excalidraw 0.18.1 writes, so they carry newer fields such as
`mode` and `fixedPoint` on bindings, `created`, `labelPosition`, `polygon` and
freedraw `strokeOptions`. The library has to ignore those, and the official 0.18.1
export does too.

| File | What it shows |
|---|---|
| `real-flowchart.excalidraw` | Rectangle, diamond and ellipse with bound labels, two bound arrows, one with a label. |
| `real-frame.excalidraw` | A frame drawn after its children, so it comes last in the array; shapes inside it, a line, a bound arrow. The frame has no name (`null`). |
| `real-mixed.excalidraw` | What was left after the frame was deleted: children that still name a frame that no longer exists, pencil strokes with all-zero pressures, free text, and a diamond overlapping an ellipse. |

The expected SVG for each is produced by the pinned official package
(`scripts/gen_fixtures.mjs combo`), like every other fixture.

The scenes named `editor-api/` in the combined suite are built with the official
`convertToExcalidrawElements`, the function the editor uses for generated diagrams.
`handmade/` and `random/` scenes are written by scripts. None of those were drawn
with the mouse.
