# placeholder

<!-- stats:begin -->
| Suite | What it covers | Scenes | Byte-identical | Different |
|---|---|---:|---:|---:|
| single basic | Rectangles, diamonds, ellipses × fill, stroke, roughness, roundness | 252 | 252 | 0 |
| single linear | Lines, arrows, closed fills, all arrowhead styles | 341 | 341 | 0 |
| single text | Text: every font id, alignment, direction, bound to shapes and arrows | 200 | 200 | 0 |
| single misc | Freedraw, images, frames, links | 78 | 78 | 0 |
| fonts | Font rules (`FontMode::Url`) for each family and character set | 185 | 185 | 0 |
| combined | Diagrams (editor API, hand-made, random, and 3 drawn in the real editor) | 55 | 55 | 0 |
| edge cases | Empty and degenerate scenes, extreme numbers, old formats, official errors | 66 | 66 | 0 |
| **Total** | | **1177** | **1177** | **0** |

| Lower-level check | Cases | Different |
|---|---:|---:|
| perfect-freehand outlines, every number compared by bit pattern | 322 | 0 |
| `restoreElements` normalisation of old and partial elements | 50 | 0 |
| JSON numbers read like V8 does | 10000 | 0 |
| `Math.hypot` | 5256 | 0 |
| `Math.atan2` | 5256 | 0 |
| `Math.pow(x, 3)` | 8000 | 0 |
<!-- stats:end -->
