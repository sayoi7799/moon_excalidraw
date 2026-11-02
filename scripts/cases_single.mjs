// Single-element scenes for the conformance suites. Inputs are complete
// .excalidraw documents; expected values come from the official export.
import { rng } from "./mbt.mjs";

export const base = { version: 1, versionNonce: 1, isDeleted: false, fillStyle: "hachure", strokeWidth: 2, strokeStyle: "solid", roughness: 1, opacity: 100, angle: 0, strokeColor: "#1e1e1e", backgroundColor: "#a5d8ff", seed: 12345, groupIds: [], frameId: null, roundness: null, boundElements: null, updated: 1, link: null, locked: false };

export function doc(elements, extra = {}) {
  return { type: "excalidraw", version: 2, source: "https://excalidraw.com", elements, appState: { viewBackgroundColor: "#ffffff", gridSize: null }, files: {}, ...extra };
}

const ROUND = { rectangle: [null, { type: 1 }, { type: 2 }, { type: 3 }, { type: 3, value: 8 }], diamond: [null, { type: 2 }, { type: 1 }], ellipse: [null] };
const FILLS = ["hachure", "cross-hatch", "solid", "zigzag"];
const STROKES = ["solid", "dashed", "dotted"];
const WIDTHS = [1, 2, 4];
const ROUGHNESS = [0, 1, 2];

export function singleBasic() {
  const cases = [];
  const add = (name, el) => cases.push({ name, scene: doc([{ ...base, id: "e", x: 3, y: 4, width: 137, height: 83, ...el }]) });
  // UI defaults, all combinations.
  for (const type of ["rectangle", "diamond", "ellipse"]) {
    for (const fillStyle of ["hachure", "solid"]) {
      for (const strokeWidth of WIDTHS) {
        for (const roughness of ROUGHNESS) {
          add(`grid/${type}/${fillStyle}/${strokeWidth}/${roughness}`, { type, fillStyle, strokeWidth, roughness, seed: 1000 + cases.length });
        }
      }
    }
  }
  // A pairwise-style sample of everything else, with a fixed RNG.
  const r = rng(7);
  const pick = (a) => a[Math.floor(r() * a.length)];
  for (let i = 0; i < 140; i++) {
    const type = pick(["rectangle", "diamond", "ellipse"]);
    const el = {
      type,
      fillStyle: pick(FILLS),
      strokeStyle: pick(STROKES),
      strokeWidth: pick(WIDTHS),
      roughness: pick(ROUGHNESS),
      roundness: pick(ROUND[type]),
      opacity: pick([100, 100, 60, 35]),
      angle: pick([0, 0, 0.5, 1.7, -2.4]),
      strokeColor: pick(["#1e1e1e", "#e03131", "#2f9e44"]),
      backgroundColor: pick(["#a5d8ff", "#ffc9c9", "transparent", "#00000000", "#fff0"]),
      width: pick([137, 300.5, 40, 12]),
      height: pick([83, 21.25, 200]),
      x: pick([0, -50.5, 1234.75]),
      y: pick([4, -7.125]),
      seed: 1 + Math.floor(r() * 2 ** 31 - 2),
    };
    add(`sample/${i}/${type}/${el.fillStyle}/${el.strokeStyle}`, el);
  }
  // Each size rule of adjustRoughness, and non-UI stroke widths.
  for (const [w, h] of [[5, 5], [9, 30], [15, 15], [19, 49], [20, 49], [20, 50], [100, 5]]) {
    for (const type of ["rectangle", "diamond", "ellipse"]) {
      for (const roundness of [null, { type: 3 }]) {
        if (type === "ellipse" && roundness) continue;
        add(`small/${type}/${w}x${h}/${roundness ? "round" : "sharp"}`, { type, width: w, height: h, roundness, roughness: 2, fillStyle: "solid" });
      }
    }
  }
  for (const strokeWidth of [0.5, 1.3, 1.5, 3, 7.77]) {
    for (const fillStyle of FILLS) {
      add(`width/${strokeWidth}/${fillStyle}`, { type: "rectangle", strokeWidth, fillStyle });
    }
  }
  add("background/none", { type: "rectangle" });
  cases[cases.length - 1].scene.appState.exportBackground = false;
  add("background/color", { type: "rectangle" });
  cases[cases.length - 1].scene.appState.viewBackgroundColor = "#123456";
  add("background/empty", { type: "rectangle" });
  cases[cases.length - 1].scene.appState.viewBackgroundColor = "";
  return cases;
}
