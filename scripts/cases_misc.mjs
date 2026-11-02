// Freedraw, images, frames and links.
import { rng } from "./mbt.mjs";
import { base, doc } from "./cases_single.mjs";
import { textEl } from "./cases_text.mjs";

const PNG = "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==";
const SVG = "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciLz4=";
const FILES = {
  abc: { id: "abc", mimeType: "image/png", dataURL: PNG, created: 1 },
  def: { id: "def", mimeType: "image/svg+xml", dataURL: SVG, created: 2 },
  "0f3-x": { id: "0f3-x", mimeType: "image/png", dataURL: PNG, created: 3 },
};

const walk = (r, n, step) => {
  const pts = [[0, 0]];
  let x = 0, y = 0;
  for (let i = 1; i < n; i++) {
    x += (r() - 0.4) * step;
    y += (r() - 0.5) * step;
    pts.push([Math.round(x * 100) / 100, Math.round(y * 100) / 100]);
  }
  return pts;
};

const freedraw = (extra = {}) => ({
  ...base,
  id: "f",
  type: "freedraw",
  x: 10,
  y: 20,
  width: 50,
  height: 30,
  points: [[0, 0], [10, 5], [20, 12], [30, 18], [40, 20]],
  pressures: [],
  simulatePressure: true,
  lastCommittedPoint: [40, 20],
  backgroundColor: "transparent",
  ...extra,
});

const image = (extra = {}) => ({
  ...base,
  id: "i",
  type: "image",
  x: 10,
  y: 20,
  width: 120.4,
  height: 80.6,
  fileId: "abc",
  status: "saved",
  scale: [1, 1],
  crop: null,
  backgroundColor: "transparent",
  ...extra,
});

export function miscScenes() {
  const cases = [];
  const add = (name, elements, extra = {}) => cases.push({ name, scene: doc(elements, extra), ...(extra.fonts ? { fonts: extra.fonts } : {}) });
  const r = rng(5);

  // Freedraw.
  for (const strokeWidth of [1, 2, 4]) {
    for (const simulatePressure of [true, false]) {
      const points = walk(r, 25, 12);
      add(`freedraw/${strokeWidth}/${simulatePressure ? "sim" : "real"}`, [
        freedraw({ strokeWidth, simulatePressure, points, pressures: simulatePressure ? [] : points.map(() => Math.round(r() * 100) / 100), seed: 77 + strokeWidth }),
      ]);
    }
  }
  add("freedraw/two-points", [freedraw({ points: [[0, 0], [30, 10]] })]);
  add("freedraw/same-points", [freedraw({ points: [[0, 0], [0, 0], [0, 0]] })]);
  add("freedraw/short-pressures", [freedraw({ simulatePressure: false, points: [[0, 0], [10, 5], [20, 12], [30, 18]], pressures: [0.2, 0.9] })]);
  add("freedraw/long", [freedraw({ points: walk(r, 150, 8), strokeWidth: 3 })]);
  add("freedraw/rotated", [freedraw({ angle: 1.1, points: walk(r, 20, 15) })]);
  add("freedraw/opacity", [freedraw({ opacity: 45, strokeColor: "#e03131" })]);
  add("freedraw/negative", [freedraw({ x: -40, y: -60, points: walk(r, 12, 20) })]);
  const loop = [[0, 0], [30, 5], [45, 30], [20, 50], [-5, 30], [2, 3]];
  for (const fillStyle of ["hachure", "cross-hatch", "solid", "zigzag"]) {
    add(`freedraw/loop/${fillStyle}`, [freedraw({ points: loop, fillStyle, backgroundColor: "#a5d8ff" })]);
  }
  add("freedraw/loop/transparent", [freedraw({ points: loop })]);
  add("freedraw/loop/rotated", [freedraw({ points: loop, backgroundColor: "#ffc9c9", angle: 0.8, opacity: 60 })]);
  const closed = walk(r, 40, 10);
  closed.push([1, 1]);
  add("freedraw/loop/many", [freedraw({ points: closed, backgroundColor: "#b2f2bb", fillStyle: "solid" })]);

  // Images.
  const files = FILES;
  add("image/basic", [image()], { files });
  for (const scale of [[-1, 1], [1, -1], [-1, -1]]) add(`image/scale/${scale}`, [image({ scale })], { files });
  add("image/rounded", [image({ roundness: { type: 3 } })], { files });
  add("image/rounded-proportional", [image({ roundness: { type: 2 } })], { files });
  add("image/rotated-opacity", [image({ angle: 0.9, opacity: 55 })], { files });
  add("image/crop", [image({ crop: { x: 10, y: 20, width: 100, height: 60, naturalWidth: 400, naturalHeight: 300 } })], { files });
  add("image/crop-rounded-flipped", [image({ roundness: { type: 3 }, scale: [-1, 1], angle: 0.4, crop: { x: 0, y: 5, width: 200, height: 100, naturalWidth: 640, naturalHeight: 480 } })], { files });
  add("image/svg-file", [image({ fileId: "def" })], { files });
  add("image/odd-id", [image({ fileId: "0f3-x" })], { files });
  add("image/reused", [image(), image({ id: "i2", x: 200, y: 50 })], { files });
  add("image/reused-crop", [image({ crop: { x: 10, y: 20, width: 100, height: 60, naturalWidth: 400, naturalHeight: 300 } }), image({ id: "i2", x: 200, crop: { x: 10, y: 20, width: 100, height: 60, naturalWidth: 400, naturalHeight: 300 } })], { files });
  add("image/two-files", [image(), image({ id: "i2", x: 200, fileId: "def" })], { files });
  add("image/missing-file", [image({ fileId: "nope" })], { files });
  add("image/no-file-id", [image({ fileId: null })], { files });
  add("image/no-files", [image()]);
  add("image/fractional", [image({ width: 33.5, height: 22.49 })], { files });
  add("image/link", [image({ link: "https://example.com/a" })], { files });

  // Frames.
  const frame = (extra = {}) => ({ ...base, id: "fr", type: "frame", x: 0, y: 0, width: 200, height: 120, name: "Frame A", backgroundColor: "transparent", strokeColor: "#bbb", ...extra });
  const rect = (extra = {}) => ({ ...base, id: "r", type: "rectangle", x: 150, y: 60, width: 120, height: 100, ...extra });
  add("frame/empty", [frame()]);
  add("frame/no-name", [frame({ name: undefined })]);
  add("frame/null-name", [frame({ name: null })]);
  add("frame/empty-name", [frame({ name: "" })]);
  add("frame/magic", [frame({ type: "magicframe", name: null })]);
  add("frame/magic-named", [frame({ type: "magicframe", name: "Magic" })]);
  add("frame/escape", [frame({ name: "a&b<c> d" })]);
  add("frame/long-name", [frame({ width: 100, name: "A very long frame title that must be cut" })]);
  add("frame/cjk-name", [frame({ width: 60, name: "这是一个很长的框架标题" })]);
  add("frame/emoji-name", [frame({ width: 70, name: "😀😀😀😀😀😀😀😀😀😀" })]);
  add("frame/name-with-tab", [frame({ width: 80, name: "a\tb\tc\td" })]);
  add("frame/multiline-name", [frame({ name: "one\ntwo" })]);
  add("frame/narrow", [frame({ width: 10 })]);
  add("frame/child-rect", [frame(), rect({ frameId: "fr" })]);
  add("frame/child-outside", [frame(), rect({ frameId: "fr", x: 500, y: 400 })]);
  add("frame/child-first", [rect({ frameId: "fr" }), frame()]);
  add("frame/child-line", [frame(), { ...base, id: "l", type: "line", frameId: "fr", x: 150, y: 10, width: 100, height: 100, points: [[0, 0], [100, 100]], backgroundColor: "transparent", lastCommittedPoint: null }]);
  add("frame/child-arrow-label", [
    frame(),
    { ...base, id: "a", type: "arrow", frameId: "fr", x: 150, y: 10, width: 100, height: 60, points: [[0, 0], [100, 60]], backgroundColor: "transparent", boundElements: [{ type: "text", id: "t" }], startArrowhead: null, endArrowhead: "arrow", lastCommittedPoint: null },
    textEl("lbl", { containerId: "a", frameId: "fr", textAlign: "center" }),
  ]);
  add("frame/child-text", [frame(), textEl("inside", { frameId: "fr", x: 150, y: 50 })]);
  add("frame/child-freedraw", [frame(), freedraw({ frameId: "fr", x: 150, y: 50 })]);
  add("frame/child-image", [frame(), image({ frameId: "fr", x: 150, y: 50 })], { files });
  add("frame/child-image-link", [frame(), image({ frameId: "fr", x: 150, y: 50, link: "https://e.com" })], { files });
  add("frame/opacity", [frame({ opacity: 50 }), rect({ frameId: "fr", opacity: 80 })]);
  add("frame/rotated", [frame({ angle: 0.5 }), rect({ frameId: "fr" })]);
  add("frame/two", [frame(), rect({ frameId: "fr" }), frame({ id: "fr2", x: 400, y: 0, name: "Second" }), rect({ id: "r2", frameId: "fr2", x: 420, y: 20, width: 50, height: 50 })]);
  add("frame/child-missing-frame", [rect({ frameId: "gone" })]);
  add("frame/child-of-rect", [rect({ id: "box", opacity: 50 }), rect({ id: "r2", frameId: "box", x: 400 })]);
  add("frame/mixed-order", [rect({ id: "free", x: 600, y: 0 }), frame(), rect({ frameId: "fr" })]);

  // Links.
  add("link/rect", [{ ...rect(), link: "https://example.com/?a=1&b=\"2\"" }]);
  add("link/text", [textEl("click", { link: "https://example.com" })]);
  add("link/line", [{ ...base, id: "l", type: "line", x: 5, y: 5, width: 50, height: 50, points: [[0, 0], [50, 50]], backgroundColor: "transparent", link: "https://example.com", lastCommittedPoint: null }]);
  add("link/arrow-label", [
    { ...base, id: "a", type: "arrow", x: 5, y: 7, width: 200, height: 50, points: [[0, 0], [200, 50]], backgroundColor: "transparent", link: "https://example.com", boundElements: [{ type: "text", id: "t" }], startArrowhead: null, endArrowhead: "arrow", lastCommittedPoint: null },
    textEl("label", { containerId: "a", textAlign: "center", link: "https://label.example" }),
  ]);
  add("link/freedraw", [freedraw({ link: "https://example.com" })]);
  add("link/frame", [frame({ link: "https://example.com" })]);
  add("link/javascript", [{ ...rect(), link: "javascript:alert(1)" }]);
  add("link/relative", [{ ...rect(), link: "/docs/page" }]);
  add("link/blank", [{ ...rect(), link: "   " }]);
  add("link/spaces", [{ ...rect(), link: "  https://example.com  " }]);
  add("link/in-frame", [frame(), rect({ frameId: "fr", link: "https://example.com" })]);
  return cases;
}
