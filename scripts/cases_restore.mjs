// Official restoreElements output in a canonical text form, the same one
// src/model/model_test.mbt builds. Also normalizeLink results.
const opt = (v) => (v === null || v === undefined ? "~" : String(v));
const pts = (p) => p.map((q) => `${q[0]},${q[1]}`).join(" ");

export function canon(e) {
  let kind = e.type;
  if (e.type === "line" || e.type === "arrow") kind += `:${pts(e.points)}:${opt(e.startArrowhead)}:${opt(e.endArrowhead)}`;
  if (e.type === "freedraw") kind += `:${pts(e.points)}:${(e.pressures ?? []).join(",")}:${!!e.simulatePressure}`;
  if (e.type === "text") kind += `:${e.text}:${e.originalText}:${e.fontSize}:${e.fontFamily ?? -1}:${e.textAlign}:${e.verticalAlign}:${opt(e.containerId)}:${e.lineHeight}`;
  if (e.type === "image") kind += `:${opt(e.fileId || null)}:${e.scale[0]},${e.scale[1]}`;
  if (e.type === "frame" || e.type === "magicframe") kind += `:${opt(e.name)}`;
  const round = e.roundness ? `${e.roundness.type}:${opt(e.roundness.value)}` : "~";
  const bound = (e.boundElements ?? []).map((b) => `${b.type}/${b.id}`).join(",");
  return [kind, e.id, e.x, e.y, e.width, e.height, e.angle, e.strokeColor, e.backgroundColor, e.fillStyle, e.strokeWidth, e.strokeStyle, e.roughness, e.opacity, e.seed, round, bound, opt(e.frameId), opt(e.link || null), e.isDeleted].join("|");
}

const r = { id: "r", type: "rectangle", x: 1, y: 2, width: 30, height: 20 };
const line = { id: "l", type: "line", x: 5, y: 6, width: 1, height: 1, points: [[0, 0], [30, 40]] };
const arrow = { ...line, id: "a", type: "arrow" };
const text = { id: "t", type: "text", x: 0, y: 0, width: 50, height: 50, text: "a\nb", fontSize: 20, fontFamily: 1 };

export const restoreScenes = {
  rectMinimal: [{ id: "m", type: "rectangle", x: 0, y: 0, width: 40, height: 30 }],
  rectOnlyType: [{ id: "m", type: "rectangle" }],
  rectFull: [{ ...r, angle: 1.5, strokeColor: "#f00", backgroundColor: "#0f0", fillStyle: "zigzag", strokeWidth: 4, strokeStyle: "dotted", roughness: 2, opacity: 40, seed: 99, frameId: "f", roundness: { type: 3, value: 12 }, boundElements: [{ type: "text", id: "t" }] }],
  falsyFields: [{ ...r, strokeWidth: 0, opacity: 0, roughness: 0, angle: 0, strokeColor: "", backgroundColor: "", fillStyle: "", seed: 0 }],
  nullFields: [{ ...r, opacity: null, roughness: null, seed: null, strokeStyle: null, frameId: null, boundElements: null, roundness: null, link: null }],
  negativeSize: [{ ...r, x: 100, y: 90, width: -30, height: -20 }],
  zeroBoth: [{ ...r, width: 0, height: 0 }],
  zeroOne: [{ ...r, width: 0 }],
  sharpnessRect: [{ ...r, strokeSharpness: "round" }],
  sharpnessDiamond: [{ ...r, type: "diamond", strokeSharpness: "round" }],
  sharpnessImage: [{ ...r, type: "image", strokeSharpness: "round" }],
  sharpnessLine: [{ ...line, strokeSharpness: "round" }],
  sharpnessSharp: [{ ...r, strokeSharpness: "sharp" }],
  boundIds: [{ ...r, boundElementIds: ["x", "y"] }],
  selection: [{ ...r, type: "selection" }],
  textFull: [{ ...text, lineHeight: 1.25, originalText: "ab", textAlign: "center", verticalAlign: "middle", containerId: "c" }],
  textNoLineHeight: [text],
  textNoLineHeightNoHeight: [{ ...text, height: 0, fontFamily: 6 }],
  textNoHeightCascadia: [{ ...text, height: undefined, fontFamily: 3 }],
  textCrlfLines: [{ ...text, text: "a\r\nb\rc\nd" }],
  textFontLegacy: [{ id: "t", type: "text", x: 0, y: 0, width: 50, height: 25, text: "a", font: "24px Cascadia", lineHeight: 1.2 }],
  textFontUnknown: [{ id: "t", type: "text", x: 0, y: 0, width: 50, height: 25, text: "a", font: "24.5px Foo", lineHeight: 1.2 }],
  textFontNoLineHeight: [{ id: "t", type: "text", x: 0, y: 0, width: 50, height: 25, text: "a", font: "20px Virgil" }],
  textFontBoth: [{ ...text, font: "16px Helvetica", lineHeight: 1.15 }],
  textEmpty: [{ ...text, text: "", lineHeight: 1.25 }],
  textNonString: [{ ...text, text: 5, lineHeight: 1.25 }],
  textNoFamily: [{ id: "t", type: "text", x: 0, y: 0, width: 50, height: 25, text: "a", fontSize: 20 }],
  textRawText: [{ ...text, rawText: "zz", lineHeight: 1.25 }],
  lineDraw: [{ ...line, type: "draw" }],
  lineFirstNonZero: [{ ...line, points: [[10, 20], [60, 60], [10, 90]] }],
  lineArrowheads: [{ ...line, startArrowhead: "dot", endArrowhead: "bar" }],
  lineOnePoint: [{ ...line, points: [[0, 0]] }],
  lineThreeDecimal: [{ ...line, points: [[0, 0], [1.5, -2.25], [-7.125, 9]], width: 999, height: -5 }],
  arrowDefaultHead: [arrow],
  arrowNullHead: [{ ...arrow, endArrowhead: null, startArrowhead: "triangle" }],
  arrowFirstNonZero: [{ ...arrow, points: [[-3, 4], [60, 60]] }],
  arrowOnePoint: [{ ...arrow, points: [[0, 0]] }],
  arrowBinding: [{ ...arrow, startBinding: { elementId: "x", gap: 1 }, endBinding: null }],
  freedraw: [{ id: "f", type: "freedraw", x: 1, y: 2, width: 3, height: 4, points: [[0, 0], [1, 2], [3, 4]], pressures: [0.1, 0.2, 0.3], simulatePressure: false, lastCommittedPoint: [3, 4] }],
  freedrawSim: [{ id: "f", type: "freedraw", x: 1, y: 2, width: -3, height: 4, points: [[0, 0], [1, 2]], pressures: [], simulatePressure: true }],
  freedrawOnePoint: [{ id: "f", type: "freedraw", x: 1, y: 2, width: 3, height: 4, points: [[0, 0]], pressures: [], simulatePressure: true }],
  image: [{ id: "i", type: "image", x: 1, y: 2, width: 30, height: 40, fileId: "abc", status: "saved", scale: [-1, 1] }],
  imageNoFile: [{ id: "i", type: "image", x: 1, y: 2, width: 30, height: 40 }],
  frame: [{ id: "f", type: "frame", x: 1, y: 2, width: 30, height: 40, name: "Hello" }],
  frameNoName: [{ id: "f", type: "frame", x: 1, y: 2, width: 30, height: 40 }],
  magic: [{ id: "f", type: "magicframe", x: 1, y: 2, width: 30, height: 40, name: null }],
  linkNormal: [{ ...r, link: " https://example.com/a?b=1&c=\"2\" " }],
  linkJs: [{ ...r, link: "javascript:alert(1)" }],
  linkBlank: [{ ...r, link: "   " }],
  order: [{ ...r, id: "z", index: "a2" }, { ...r, id: "y", index: "a1" }],
};

export const linkInputs = [
  "", "   ", "example.com", "https://example.com/?a=1&b=2", "HTTP://X.COM", "mailto:a@b.c", "tel:+1", "/relative/path", "./x", "../y:z",
  "javascript:alert(1)", "JaVaScRiPt:alert(1)", " javascript:alert(1)", "\u0001javascript:alert(1)", "java\nscript:alert(1)", "java\tscript:alert(1)",
  "&#106;avascript:alert(1)", "&#106avascript:alert(1)", "&#0x6a;avascript:alert(1)", "javascript&colon;alert(1)", "data:text/html,x", "vbscript:x", "DATA:x",
  "&newline;javascript:alert(1)", "&TAB;javascript:alert(1)", "!!javascript:alert(1)", "foo javascript:alert(1)", "a\"b", "\"javascript:x\"", "&#x;", "&#;", "&#99999;a", "&#65;",
  " javascript:x", "a javascript:x", "http://a b:c", "​https://x", "https://x﻿", "中文:链接", "no scheme here", ":x", "::", "a:",
];
