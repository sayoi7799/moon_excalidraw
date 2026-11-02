// Edge cases: empty and degenerate scenes, extreme numbers, old file formats,
// and inputs on which the official code throws (their fixtures expect an error).
import { base, doc } from "./cases_single.mjs";
import { textEl } from "./cases_text.mjs";

const rect = (extra = {}) => ({ ...base, id: "r", type: "rectangle", x: 0, y: 0, width: 100, height: 50, ...extra });

export function edgeScenes() {
  const cases = [];
  const add = (name, scene) => cases.push({ name, scene });
  const scene = (elements, extra = {}) => doc(elements, extra);

  add("empty/no-elements", scene([]));
  add("empty/no-elements-field", { type: "excalidraw", version: 2 });
  add("empty/no-app-state", { type: "excalidraw", elements: [rect()] });
  add("empty/null-app-state", { type: "excalidraw", elements: [rect()], appState: null });
  add("empty/app-state-background", scene([rect()], { appState: { viewBackgroundColor: "#ff00ff" } }));
  add("empty/app-state-no-export-background", scene([rect()], { appState: { exportBackground: false } }));
  add("empty/only-deleted", scene([rect({ isDeleted: true })]));
  add("empty/deleted-and-live", scene([rect({ id: "d", x: 900, isDeleted: true }), rect()]));
  add("empty/extra-top-level-fields", { ...scene([rect()]), source: "x", libraryItems: [1], extra: { a: [1, 2] } });
  add("empty/extra-element-fields", scene([{ ...rect(), customData: { a: 1 }, futureField: [1, { b: 2 }], index: "a0" }]));

  // Sizes.
  add("size/width-zero", scene([rect({ width: 0 })]));
  add("size/height-zero", scene([rect({ height: 0 })]));
  add("size/both-zero", scene([rect({ width: 0, height: 0 })]));
  add("size/both-zero-and-other", scene([rect({ width: 0, height: 0 }), rect({ id: "o", x: 50, y: 50 })]));
  add("size/ellipse-zero-width", scene([rect({ type: "ellipse", width: 0 })]));
  add("size/diamond-zero-height", scene([rect({ type: "diamond", height: 0 })]));
  add("size/negative", scene([rect({ x: 100, y: 100, width: -60, height: -40 })]));
  add("size/tiny", scene([rect({ width: 0.001, height: 0.002 })]));
  add("size/fractional", scene([rect({ x: 0.1, y: 0.2, width: 33.333333333, height: 66.666666667 })]));
  add("size/text-zero", scene([textEl("x", { width: 0, height: 0 })]));
  add("size/font-size-zero", scene([textEl("x", { fontSize: 0 })]));
  add("size/line-zero-length", scene([{ ...base, id: "l", type: "line", x: 5, y: 5, width: 0, height: 0, points: [[0, 0], [0, 0]], backgroundColor: "transparent", lastCommittedPoint: null }]));

  // Numbers.
  add("number/huge-x", scene([rect({ x: 1e21, y: -1e15 })]));
  add("number/huge-pair", scene([rect({ x: -1e15 }), rect({ id: "b", x: 1e15 })]));
  add("number/huge-size", scene([rect({ width: 1e12, height: 1e12, fillStyle: "solid" })]));
  add("number/max-ish", scene([rect({ x: 1e300, width: 1e300, fillStyle: "solid" })]));
  add("number/small-coordinates", scene([rect({ x: 1e-7, y: -1e-7 })]));
  add("number/negative-zero", scene([rect({ x: -0, y: -0 })]));
  add("number/many-digits", scene([rect({ x: 123456.78901234567, y: 0.1 + 0.2 })]));
  add("number/angle-large", scene([rect({ angle: 100 })]));
  add("number/angle-negative", scene([rect({ angle: -7.5 })]));
  add("number/roughness-extremes", scene([rect({ roughness: 3 }), rect({ id: "b", x: 200, roughness: 10 }), rect({ id: "c", x: 400, roughness: 0.5 })]));
  add("number/stroke-width-zero", scene([rect({ strokeWidth: 0 })]));
  add("number/stroke-width-large", scene([rect({ strokeWidth: 30 })]));
  add("number/opacity-zero", scene([rect({ opacity: 0 })]));
  add("number/opacity-over", scene([rect({ opacity: 150 })]));
  add("number/seed-negative", scene([rect({ seed: -5 })]));
  add("number/seed-fractional", scene([rect({ seed: 1.5 })]));
  add("number/seed-missing", scene([{ ...rect(), seed: undefined }]));

  // Old and incomplete files.
  add("old/minimal-rect", scene([{ id: "m", type: "rectangle", x: 0, y: 0, width: 40, height: 30 }]));
  add("old/minimal-types", scene(["rectangle", "ellipse", "diamond"].map((type, i) => ({ id: `m${i}`, type, x: i * 60, y: 0, width: 40, height: 30 }))));
  add("old/no-id", scene([{ type: "rectangle", x: 0, y: 0, width: 40, height: 30 }]));
  add("old/no-stroke-fields", scene([{ id: "m", type: "rectangle", x: 0, y: 0, width: 40, height: 30, backgroundColor: "#ff0000" }]));
  add("old/stroke-sharpness", scene([rect({ strokeSharpness: "round", roundness: undefined })]));
  add("old/stroke-sharpness-sharp", scene([rect({ strokeSharpness: "sharp", roundness: undefined })]));
  add("old/bound-element-ids", scene([rect({ boundElementIds: ["t"], boundElements: undefined }), textEl("hi", { containerId: "r", x: 20, y: 10 })]));
  add("old/text-no-line-height", scene([textEl("a\nb", { lineHeight: undefined, height: 50 })]));
  add("old/text-legacy-font", scene([textEl("a", { font: "24px Cascadia", fontSize: undefined, fontFamily: undefined, lineHeight: undefined, height: 29 })]));
  add("old/draw-type", scene([{ ...base, id: "d", type: "draw", x: 5, y: 5, width: 50, height: 50, points: [[0, 0], [50, 50]], backgroundColor: "transparent" }]));
  add("old/arrow-no-heads", scene([{ ...base, id: "a", type: "arrow", x: 5, y: 5, width: 50, height: 50, points: [[0, 0], [50, 50]], backgroundColor: "transparent" }]));
  add("old/arrow-first-point-nonzero", scene([{ ...base, id: "a", type: "arrow", x: 5, y: 5, width: 50, height: 50, points: [[10, 20], [60, 70]], backgroundColor: "transparent" }]));
  add("old/line-no-size", scene([{ id: "l", type: "line", x: 5, y: 5, points: [[0, 0], [30, 40]] }]));
  add("old/null-fields", scene([rect({ opacity: null, roughness: null, strokeStyle: null, frameId: null, link: null, groupIds: null })]));
  add("old/selection-element", scene([rect({ id: "s", type: "selection" }), rect()]));
  add("old/unknown-type", scene([rect(), { id: "u", type: "wat", x: 900, y: 900, width: 50, height: 50 }]));
  add("old/missing-type", scene([rect(), { id: "u", x: 900, y: 900, width: 50, height: 50 }]));
  add("old/duplicate-order", scene([rect({ id: "z", index: "a2" }), rect({ id: "y", x: 200, index: "a1" })]));
  add("old/files-unused", scene([rect()], { files: { x: { id: "x", mimeType: "image/png", dataURL: "data:image/png;base64,AA==", created: 1 } } }));
  add("old/image-no-files", scene([{ ...base, id: "i", type: "image", x: 0, y: 0, width: 50, height: 50, fileId: "gone", status: "pending", scale: [1, 1], backgroundColor: "transparent" }]));

  // The official code throws on these; so does this library, with an error.
  add("error/arrow-without-points", scene([{ ...base, id: "a", type: "arrow", x: 0, y: 0, width: 50, height: 50 }]));
  add("error/line-null-points", scene([{ ...base, id: "a", type: "line", x: 0, y: 0, width: 50, height: 50, points: null }]));

  // Dropped without a trace.
  add("dropped/line-one-point", scene([{ ...base, id: "a", type: "line", x: 0, y: 0, width: 5, height: 5, points: [[0, 0]] }, rect()]));
  add("dropped/line-no-points-list", scene([{ ...base, id: "a", type: "line", x: 0, y: 0, width: 5, height: 5, points: [] }, rect()]));
  add("dropped/freedraw-one-point", scene([{ ...base, id: "f", type: "freedraw", x: 0, y: 0, width: 5, height: 5, points: [[0, 0]], pressures: [], simulatePressure: true }, rect()]));
  add("dropped/empty-text", scene([textEl(""), rect({ x: 300 })]));
  return cases;
}
