// Line and arrow scenes: shapes, arrowheads, fills, rotation.
import { rng } from "./mbt.mjs";
import { base, doc } from "./cases_single.mjs";

const HEADS = [null, "arrow", "bar", "dot", "circle", "circle_outline", "triangle", "triangle_outline", "diamond", "diamond_outline", "crowfoot_one", "crowfoot_many", "crowfoot_one_or_many"];
const POINTS = {
  p2: [[0, 0], [160, 60]],
  p2short: [[0, 0], [12, 5]],
  p3: [[0, 0], [90, 70], [200, 10]],
  p4: [[0, 0], [60, 80], [120, -20], [210, 40]],
  p5: [[0, 0], [40, 60], [90, 10], [140, 70], [200, 20]],
};
const LOOPS = {
  tri: [[0, 0], [80, 10], [40, 70], [0, 0]],
  three: [[0, 0], [80, 40], [2, 3]],
  four: [[0, 0], [90, 5], [70, 80], [3, 2]],
};

export function singleLinear() {
  const cases = [];
  const add = (name, type, points, el = {}) => {
    const arrow = type === "arrow";
    cases.push({
      name,
      scene: doc([{ ...base, id: "l", type, x: 7, y: 9, width: 10, height: 10, points, lastCommittedPoint: null, startArrowhead: null, endArrowhead: arrow ? "arrow" : null, startBinding: null, endBinding: null, backgroundColor: "transparent", seed: 100 + cases.length, ...el }]),
    });
  };
  for (const type of ["line", "arrow"]) {
    for (const [pn, points] of Object.entries(POINTS)) {
      for (const roundness of [null, { type: 2 }]) {
        for (const strokeStyle of ["solid", "dashed", "dotted"]) {
          add(`shape/${type}/${pn}/${roundness ? "curve" : "poly"}/${strokeStyle}`, type, points, { roundness, strokeStyle });
        }
      }
    }
  }
  for (const head of HEADS) {
    for (const [pn, roundness] of [["p2", null], ["p3", { type: 2 }], ["p4", null], ["p2short", null]]) {
      add(`head/end/${head}/${pn}`, "arrow", POINTS[pn], { endArrowhead: head, roundness });
      add(`head/start/${head}/${pn}`, "arrow", POINTS[pn], { startArrowhead: head, endArrowhead: null, roundness });
      add(`head/both/${head}/${pn}`, "arrow", POINTS[pn], { startArrowhead: head, endArrowhead: head, roundness });
    }
    for (const strokeStyle of ["dashed", "dotted"]) {
      add(`head/style/${head}/${strokeStyle}`, "arrow", POINTS.p3, { startArrowhead: head, endArrowhead: head, strokeStyle, strokeWidth: 4 });
    }
  }
  for (const [startArrowhead, endArrowhead] of [["triangle", "dot"], ["bar", "diamond"], ["circle_outline", "triangle_outline"], ["crowfoot_one", "arrow"]]) {
    add(`head/mixed/${startArrowhead}/${endArrowhead}`, "arrow", POINTS.p3, { startArrowhead, endArrowhead, strokeWidth: 3, roughness: 2, backgroundColor: "#ffc9c9" });
  }
  for (const [ln, points] of Object.entries(LOOPS)) {
    for (const fillStyle of ["hachure", "cross-hatch", "solid", "zigzag"]) {
      for (const roundness of [null, { type: 2 }]) {
        add(`loop/line/${ln}/${fillStyle}/${roundness ? "curve" : "poly"}`, "line", points, { fillStyle, roundness, backgroundColor: "#a5d8ff" });
      }
    }
    add(`loop/arrow/${ln}`, "arrow", points, { backgroundColor: "#a5d8ff", roundness: { type: 2 } });
  }
  const r = rng(11);
  const pick = (a) => a[Math.floor(r() * a.length)];
  for (let i = 0; i < 60; i++) {
    const type = pick(["line", "arrow"]);
    const points = pick(Object.values(POINTS));
    add(`sample/${i}`, type, points, {
      roundness: pick([null, { type: 2 }]),
      strokeStyle: pick(["solid", "dashed", "dotted"]),
      strokeWidth: pick([1, 2, 4]),
      roughness: pick([0, 1, 2]),
      angle: pick([0, 0.6, -1.9, 3.1]),
      opacity: pick([100, 100, 50]),
      startArrowhead: type === "arrow" ? pick(HEADS) : null,
      endArrowhead: type === "arrow" ? pick(HEADS) : null,
      x: pick([0, -40.5, 300.25]),
      y: pick([0, 12]),
      seed: 1 + Math.floor(r() * 2 ** 31 - 2),
    });
  }
  // Degenerate geometry.
  add("degenerate/zero-length", "arrow", [[0, 0], [0, 0]]);
  add("degenerate/tiny", "arrow", [[0, 0], [1e-7, 2e-7]]);
  add("degenerate/closed-pair", "arrow", [[0, 0], [100, 0], [0, 0]]);
  add("degenerate/huge", "line", [[0, 0], [1e9, 5e8]]);
  add("degenerate/negative", "arrow", [[0, 0], [-120, -80]], { endArrowhead: "triangle" });
  add("degenerate/vertical", "arrow", [[0, 0], [0, 150]], { startArrowhead: "bar" });
  add("degenerate/first-nonzero", "arrow", [[10, 20], [90, 60], [30, 100]], { roundness: { type: 2 } });
  add("degenerate/decimal", "line", [[0, 0], [10.125, -3.0625], [33.3333333, 17.1]]);
  return cases;
}
