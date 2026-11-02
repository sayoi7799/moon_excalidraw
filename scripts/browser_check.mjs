// Checks that the jsdom fixtures match a real browser. Serves the same bundle
// and the jsdom output for a set of scenes; browser_check.html re-exports them
// and reports mismatches. Run `node browser_check.mjs`, then open the URL.
import { readFileSync } from "node:fs";
import { createServer } from "node:http";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { bundlePath, exportScene } from "./official_env.mjs";

const here = dirname(fileURLToPath(import.meta.url));
const base = { version: 1, versionNonce: 1, isDeleted: false, fillStyle: "hachure", strokeWidth: 2, strokeStyle: "solid", roughness: 1, opacity: 100, angle: 0, strokeColor: "#1e1e1e", backgroundColor: "#a5d8ff", seed: 12345, groupIds: [], frameId: null, roundness: null, boundElements: null, updated: 1, link: null, locked: false };
const shape = (type, extra = {}) => ({ ...base, id: "e", type, x: 3, y: 4, width: 137, height: 83, ...extra });
const linear = (type, points, extra = {}) => shape(type, { points, width: 90, height: 90, lastCommittedPoint: null, startArrowhead: null, endArrowhead: type === "arrow" ? "arrow" : null, ...extra });
const text = (t, extra = {}) => shape("text", { text: t, originalText: t, fontSize: 20, fontFamily: 5, textAlign: "left", verticalAlign: "top", containerId: null, lineHeight: 1.25, height: 25, width: 80, ...extra });
const png = "data:image/png;base64,iVBORw0KGgo=";

const scenes = {
  rect: [shape("rectangle")],
  roundRect: [shape("rectangle", { roundness: { type: 3 }, fillStyle: "zigzag" })],
  diamond: [shape("diamond", { fillStyle: "cross-hatch", angle: 0.7 })],
  roundDiamond: [shape("diamond", { roundness: { type: 2 }, fillStyle: "solid", opacity: 40 })],
  ellipse: [shape("ellipse", { strokeStyle: "dashed", roughness: 2 })],
  dotted: [shape("ellipse", { strokeStyle: "dotted", roughness: 0, strokeWidth: 4 })],
  line: [linear("line", [[0, 0], [90, 40], [10, 90]])],
  loop: [linear("line", [[0, 0], [90, 5], [70, 80], [3, 2]], { roundness: { type: 2 } })],
  arrow: [linear("arrow", [[0, 0], [90, 40]], { roundness: { type: 2 }, startArrowhead: "dot" })],
  arrowHeads: [linear("arrow", [[0, 0], [50, 90], [90, 10]], { startArrowhead: "triangle_outline", endArrowhead: "diamond", strokeStyle: "dotted" })],
  crowfoot: [linear("arrow", [[0, 0], [90, 40]], { startArrowhead: "crowfoot_one_or_many", endArrowhead: "bar" })],
  arrowLabel: [linear("arrow", [[0, 0], [200, 50]], { id: "a", boundElements: [{ type: "text", id: "t" }] }), text("hi", { id: "t", containerId: "a", textAlign: "center" })],
  freedraw: [shape("freedraw", { points: [[0, 0], [10, 5], [20, 12], [30, 18], [40, 20]], pressures: [], simulatePressure: true, lastCommittedPoint: [40, 20] })],
  freedrawLoop: [shape("freedraw", { points: [[0, 0], [30, 5], [40, 30], [15, 40], [1, 2]], pressures: [0.2, 0.5, 0.8, 0.5, 0.2], simulatePressure: false, lastCommittedPoint: null })],
  text: [text("Hello\nworld", { fontFamily: 1, opacity: 50, angle: 0.3 })],
  cjk: [text("你好 😀 a&b<c>", { fontFamily: 6, textAlign: "right" })],
  rtl: [text("مرحبا", { fontFamily: 3 })],
  bound: [shape("rectangle", { id: "c", boundElements: [{ type: "text", id: "t" }] }), text("in box", { id: "t", containerId: "c", textAlign: "center", verticalAlign: "middle", x: 30, y: 30 })],
  image: [shape("image", { fileId: "abc", status: "saved", scale: [-1, 1], crop: null, roundness: { type: 3 } })],
  frame: [shape("frame", { id: "f", name: "My frame with a very long title that overflows the frame width", width: 100, backgroundColor: "transparent" }), shape("rectangle", { id: "r", frameId: "f", x: 50, y: 40 })],
  link: [shape("rectangle", { link: "https://example.com/?a=1&b=\"2\"" })],
};
const files = { abc: { id: "abc", mimeType: "image/png", dataURL: png, created: 1 } };

const cases = [];
for (const [name, elements] of Object.entries(scenes)) {
  cases.push({ name, elements, files, expected: await exportScene({ elements, files }) });
}

const body = JSON.stringify(cases);
createServer((req, res) => {
  if (req.url === "/bundle.mjs") {
    res.setHeader("content-type", "text/javascript");
    res.end(readFileSync(bundlePath));
  } else if (req.url === "/cases.json") {
    res.setHeader("content-type", "application/json");
    res.end(body);
  } else {
    res.setHeader("content-type", "text/html");
    res.end(readFileSync(join(here, "browser_check.html")));
  }
}).listen(4173, () => console.log("http://localhost:4173/"));
