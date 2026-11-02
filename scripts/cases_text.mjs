// Text scenes: fonts, alignment, directions, escaping, text bound to shapes and arrows.
import { base, doc } from "./cases_single.mjs";

const LINE_HEIGHT = { 1: 1.25, 2: 1.15, 3: 1.2, 5: 1.25, 6: 1.35, 7: 1.15, 8: 1.25, 9: 1.15 };
const FAMILIES = [1, 2, 3, 5, 6, 7, 8, 9, 4, 99, 100, 1000];

/** A text element whose stored size follows the text, like the editor writes it. */
export function textEl(text, extra = {}) {
  const fontSize = extra.fontSize ?? 20;
  const fontFamily = extra.fontFamily ?? 5;
  const lineHeight = extra.lineHeight === undefined && !("lineHeight" in extra) ? LINE_HEIGHT[fontFamily] ?? 1.25 : extra.lineHeight;
  const lines = text.replace(/\r\n?/g, "\n").split("\n");
  const longest = Math.max(...lines.map((l) => [...l].length));
  return {
    ...base,
    id: "t",
    type: "text",
    x: 20,
    y: 30,
    width: Math.round(longest * fontSize * 0.55 * 100) / 100,
    height: lines.length * fontSize * (lineHeight ?? 1.25),
    text,
    originalText: text,
    fontSize,
    fontFamily,
    textAlign: "left",
    verticalAlign: "top",
    containerId: null,
    autoResize: true,
    backgroundColor: "transparent",
    ...extra,
    lineHeight,
  };
}

export function textScenes() {
  const cases = [];
  const add = (name, elements, extra) => cases.push({ name, scene: doc(elements, extra) });
  const one = (name, text, extra = {}) => add(name, [textEl(text, extra)]);

  for (const fontFamily of FAMILIES) {
    for (const textAlign of ["left", "center", "right"]) {
      one(`font/${fontFamily}/${textAlign}/single`, "Hello", { fontFamily, textAlign });
      one(`font/${fontFamily}/${textAlign}/multi`, "Hello\nworld wide", { fontFamily, textAlign });
    }
  }
  for (const fontSize of [8.5, 12, 16, 28, 36, 72]) {
    for (const fontFamily of [5, 3, 9]) one(`size/${fontSize}/${fontFamily}`, "Size\ntest", { fontSize, fontFamily });
  }
  const rtl = ["مرحبا", "123 مرحبا", "abc مرحبا", "שלום עולם", "  \n שלום", "؟مرحبا", "😀 مرحبا", "مرحبا\nabc", "...", "1234", "‏مرحبا"];
  rtl.forEach((t, i) => {
    for (const textAlign of ["left", "center", "right"]) one(`rtl/${i}/${textAlign}`, t, { textAlign, fontFamily: 6 });
  });
  const odd = ["你好 hi", "😀 emoji 👨‍👩‍👧", "a&b<c>d", "x y", "tab\there", "quote\"s'", "a  b   c", "line1\r\nline2\rline3", "\n\nlead", "trail\n", "a\n\nb", " ", "&amp;", " x", "é ñ ü", "ＡＢＣ"];
  odd.forEach((t, i) => one(`chars/${i}`, t));
  one("style/opacity", "Faded", { opacity: 40 });
  one("style/angle", "Tilted\ntext", { angle: 0.7 });
  one("style/angle-negative", "Tilted", { angle: -1.2, textAlign: "center" });
  one("style/color", "Red", { strokeColor: "#e03131" });
  one("style/at-negative", "Left", { x: -300.5, y: -20.25 });
  one("style/align-unknown", "odd", { textAlign: "justify" });
  one("style/valign", "v", { verticalAlign: "bottom" });

  // Fields the restore step fills in.
  add("restore/no-lineheight", [textEl("a\nb", { lineHeight: undefined, height: 50 })]);
  add("restore/no-lineheight-no-height", [textEl("a\nb", { lineHeight: undefined, height: undefined, fontFamily: 6 })]);
  add("restore/no-family", [textEl("a", { fontFamily: undefined })]);
  add("restore/legacy-font", [textEl("a", { font: "24px Cascadia", fontSize: undefined, fontFamily: undefined, lineHeight: 1.2 })]);
  add("restore/legacy-font-nolh", [textEl("a", { font: "20px Virgil", fontSize: undefined, fontFamily: undefined, lineHeight: undefined, height: 25 })]);
  add("restore/orig-text", [textEl("shown", { originalText: "" })]);

  // Text in shapes.
  for (const type of ["rectangle", "diamond", "ellipse"]) {
    for (const [textAlign, verticalAlign] of [["center", "middle"], ["left", "top"], ["right", "bottom"]]) {
      for (const angle of [0, 0.5]) {
        add(`bound/${type}/${textAlign}-${verticalAlign}/${angle}`, [
          { ...base, id: "c", type, x: 10, y: 10, width: 200, height: 100, angle, boundElements: [{ type: "text", id: "t" }] },
          textEl("In the\nbox", { containerId: "c", textAlign, verticalAlign, x: 60, y: 40, angle }),
        ]);
      }
    }
  }
  // Text in arrows: even and odd point counts, straight and curved, rotated.
  const arrows = { p2: [[0, 0], [200, 50]], p3: [[0, 0], [90, 70], [200, 10]], p4: [[0, 0], [60, 80], [120, -20], [210, 40]], p5: [[0, 0], [40, 60], [90, 10], [140, 70], [200, 20]] };
  for (const [pn, points] of Object.entries(arrows)) {
    for (const roundness of [null, { type: 2 }]) {
      for (const angle of [0, 0.6]) {
        add(`arrow/${pn}/${roundness ? "curve" : "poly"}/${angle}`, [
          { ...base, id: "a", type: "arrow", x: 5, y: 7, width: 200, height: 80, points, angle, roundness, backgroundColor: "transparent", boundElements: [{ type: "text", id: "t" }], startArrowhead: null, endArrowhead: "arrow", lastCommittedPoint: null },
          textEl("label", { containerId: "a", textAlign: "center", verticalAlign: "middle" }),
        ]);
      }
    }
  }
  add("arrow/line-label", [
    { ...base, id: "a", type: "line", x: 5, y: 7, width: 200, height: 80, points: arrows.p3, backgroundColor: "transparent", boundElements: [{ type: "text", id: "t" }], lastCommittedPoint: null },
    textEl("line label", { containerId: "a", textAlign: "center", verticalAlign: "middle" }),
  ]);
  add("arrow/two-arrows-one-label", [
    { ...base, id: "a", type: "arrow", x: 5, y: 7, width: 200, height: 80, points: arrows.p4, roundness: { type: 2 }, backgroundColor: "transparent", boundElements: [{ type: "text", id: "t" }], startArrowhead: null, endArrowhead: "arrow", lastCommittedPoint: null },
    { ...base, id: "b", type: "arrow", x: 5, y: 150, width: 200, height: 80, points: arrows.p4, roundness: { type: 2 }, backgroundColor: "transparent", startArrowhead: "dot", endArrowhead: "triangle", lastCommittedPoint: null },
    textEl("label", { containerId: "a", textAlign: "center", verticalAlign: "middle" }),
  ]);

  // Bindings that don't line up.
  const rect = { ...base, id: "c", type: "rectangle", x: 10, y: 10, width: 200, height: 100 };
  add("link/no-backlink", [rect, textEl("lost", { containerId: "c" })]);
  add("link/missing-container", [textEl("free", { containerId: "gone" })]);
  add("link/missing-text", [{ ...rect, boundElements: [{ type: "text", id: "gone" }] }]);
  add("link/arrow-first", [{ ...rect, boundElements: [{ type: "arrow", id: "x" }, { type: "text", id: "t" }] }, textEl("second", { containerId: "c", x: 50, y: 50 })]);
  add("link/two-texts", [{ ...rect, boundElements: [{ type: "text", id: "t" }, { type: "text", id: "u" }] }, textEl("first", { containerId: "c", x: 50, y: 40 }), textEl("second", { id: "u", containerId: "c", x: 50, y: 70 })]);
  add("link/wrong-container-id", [{ ...rect, boundElements: [{ type: "text", id: "t" }] }, textEl("odd", { containerId: "other", x: 50, y: 50 })]);
  add("link/text-after-container-removed", [textEl("alone", { containerId: null })]);

  // Empty text.
  add("empty/standalone", [rect, textEl("", { x: 600, y: 20 })]);
  add("empty/bound", [{ ...rect, boundElements: [{ type: "text", id: "t" }] }, textEl("", { containerId: "c", x: 50, y: 50 })]);
  add("empty/only", [textEl("")]);

  // Text among other elements: it counts for the canvas size.
  add("canvas/text-far", [rect, textEl("far away", { x: 800, y: -100 })]);
  add("canvas/text-rotated", [rect, textEl("rotated and far", { x: 400, y: 200, angle: 2.2 })]);
  return cases;
}
