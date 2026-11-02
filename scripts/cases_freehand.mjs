// Outlines from perfect-freehand 1.2.0 for random strokes and option sets.
import { getStroke } from "perfect-freehand";
import { hex, rng } from "./mbt.mjs";

const excalidrawEasing = (t) => Math.sin((t * Math.PI) / 2);

function randomStroke(r, n, withPressure) {
  const pts = [];
  let x = r() * 100, y = r() * 100;
  const step = 1 + r() * 30;
  for (let i = 0; i < n; i++) {
    const p = [x, y];
    if (withPressure) p.push(r());
    pts.push(p);
    x += (r() - 0.5) * step;
    y += (r() - 0.5) * step;
  }
  return pts;
}

const taperCode = (t) => (t === true ? "t" : t === 0 || t === false || t === undefined ? "0" : hex(t));

function line(points, o, ease) {
  const js = { ...o, easing: ease === "x" ? excalidrawEasing : (t) => t };
  const out = getStroke(points.map((p) => [...p]), js);
  const opts = [
    hex(o.size), hex(o.thinning), hex(o.smoothing), hex(o.streamline),
    o.simulatePressure ? "1" : "0", o.last ? "1" : "0",
    o.start?.cap === false ? "0" : "1", taperCode(o.start?.taper),
    o.end?.cap === false ? "0" : "1", taperCode(o.end?.taper), ease,
  ].join(" ");
  const pts = points.map((p) => `${hex(p[0])} ${hex(p[1])} ${p.length > 2 ? hex(p[2]) : "-"}`).join(";");
  return `${opts}|${pts}|${out.flat().map(hex).join(" ")}`;
}

/** Excalidraw's own options for strokeWidth `w`. */
const excalidraw = (w, simulatePressure, last) => ({ size: w * 4.25, thinning: 0.6, smoothing: 0.5, streamline: 0.5, simulatePressure, last });

export function freehandCases() {
  const r = rng(2024);
  const cases = [];
  const generic = () => ({
    size: [1, 4.25, 8.5, 16, 32, 0][Math.floor(r() * 5.2)],
    thinning: [0, 0.5, 0.6, -0.5, 0.95][Math.floor(r() * 5)],
    smoothing: [0, 0.25, 0.5, 0.99][Math.floor(r() * 4)],
    streamline: [0, 0.5, 0.9, 1][Math.floor(r() * 4)],
    simulatePressure: r() < 0.5,
    last: r() < 0.5,
    start: { cap: r() < 0.7, taper: [0, 0, true, 15][Math.floor(r() * 4)] },
    end: { cap: r() < 0.7, taper: [0, 0, true, 15][Math.floor(r() * 4)] },
  });
  for (const n of [1, 2, 3, 4, 5, 10, 30, 60]) {
    for (let k = 0; k < 25; k++) {
      cases.push(line(randomStroke(r, n, r() < 0.5), generic(), "i"));
    }
    for (const w of [1, 2, 4]) {
      for (const sim of [true, false]) {
        for (const last of [true, false]) {
          cases.push(line(randomStroke(r, n, !sim), excalidraw(w, sim, last), "x"));
        }
      }
    }
  }
  cases.push(line(randomStroke(r, 500, false), excalidraw(2, true, false), "x"));
  cases.push(line(randomStroke(r, 500, true), excalidraw(2, false, true), "x"));
  // Degenerate strokes: repeated points, very small and very large coordinates.
  const same = [[5, 5], [5, 5], [5, 5], [5, 5]];
  const tiny = [[1e-7, 2e-7], [3e-7, 1e-7], [5e-7, 4e-7], [9e-7, 2e-7]];
  const huge = [[1e15, 1e15], [1e15 + 100, 1e15], [1e15 + 200, 1e15 + 300]];
  const back = [[0, 0], [50, 0], [0, 0], [50, 0], [0, 0]];
  for (const pts of [same, tiny, huge, back, [[3, 4]], [[3, 4, 0.7]], [[3, 4], [3, 4]], []]) {
    for (const o of [excalidraw(2, true, false), excalidraw(2, true, true), excalidraw(1, false, false)]) {
      cases.push(line(pts, o, "x"));
    }
  }
  return cases;
}
