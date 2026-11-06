// Multi-element scenes. "editor-api/" scenes are built with the official
// convertToExcalidrawElements, the code the editor itself uses to turn a diagram
// description into bound shapes, labels and arrows. "handmade/" scenes are
// written out by hand, and "random/" scenes are seeded random mixes of every
// element type. None of them is drawn with the mouse.
import { readdirSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { rng, root } from "./mbt.mjs";
import { loadOfficial } from "./official_env.mjs";
import { base, doc } from "./cases_single.mjs";
import { textEl } from "./cases_text.mjs";

const STROKES = ["#1e1e1e", "#e03131", "#2f9e44", "#1971c2", "#f08c00"];
const FILLS = ["#ffc9c9", "#b2f2bb", "#a5d8ff", "#ffec99", "transparent"];
const PNG = "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==";

/** Ids, seeds, timestamps and nonces from the converter are random: replace them. */
function normalize(elements, seedRng) {
  const ids = new Map();
  const id = (key) => {
    if (!ids.has(key)) ids.set(key, `e${ids.size + 1}`);
    return ids.get(key);
  };
  elements.forEach((e) => id(e.id));
  return JSON.parse(JSON.stringify(elements)).map((e, i) => {
    e.id = id(e.id);
    // Labels get a random seed from the converter; everything else keeps the one it was given.
    if (e.type === "text") e.seed = 1 + Math.floor(seedRng() * 2 ** 31 - 2);
    e.versionNonce = 1000 + i;
    e.updated = 1;
    if (e.containerId) e.containerId = id(e.containerId);
    if (e.frameId) e.frameId = id(e.frameId);
    if (e.boundElements) e.boundElements = e.boundElements.map((b) => ({ ...b, id: id(b.id) }));
    if (e.groupIds) e.groupIds = e.groupIds.map((g) => `g${[...new Set(elements.flatMap((x) => x.groupIds ?? []))].indexOf(g) + 1}`);
    for (const k of ["startBinding", "endBinding"]) if (e[k]) e[k] = { ...e[k], elementId: id(e[k].elementId) };
    return e;
  });
}

export async function comboScenes() {
  const official = await loadOfficial();
  const seedRng = rng(99);
  const cases = [];
  const build = (name, skeleton, extra = {}, mutate) => {
    // The converter places an arrow's label using a curve drawn with the arrow's
    // seed, and invents a random seed when none is given. Fixing the seeds makes
    // the labels land in the same place on every run.
    const seeded = skeleton.map((s, i) => ({ seed: 1 + Math.floor(seedRng() * 2 ** 31 - 2), ...s }));
    let elements = official.convertToExcalidrawElements(seeded);
    elements = normalize(elements, seedRng);
    if (mutate) mutate(elements);
    const { appState, files, fonts } = extra;
    cases.push({ name, scene: doc(elements, { ...(files ? { files } : {}), appState: { viewBackgroundColor: "#ffffff", ...(appState ?? {}) } }), ...(fonts ? { fonts } : {}) });
  };
  const handmade = (name, elements, extra = {}) => cases.push({ name, scene: doc(elements, extra) });

  // Flowcharts.
  const flow = (style = {}, arrow = {}, labelFont) => [
    { type: "rectangle", id: "start", x: 100, y: 40, width: 160, height: 60, label: { text: "Start", ...(labelFont ? { fontFamily: labelFont } : {}) }, ...style },
    { type: "rectangle", id: "work", x: 100, y: 180, width: 160, height: 60, label: { text: "Process", ...(labelFont ? { fontFamily: labelFont } : {}) }, ...style },
    { type: "diamond", id: "check", x: 90, y: 320, width: 180, height: 110, label: { text: "OK?", ...(labelFont ? { fontFamily: labelFont } : {}) }, ...style },
    { type: "ellipse", id: "end", x: 100, y: 520, width: 160, height: 70, label: { text: "End", ...(labelFont ? { fontFamily: labelFont } : {}) }, ...style },
    { type: "arrow", x: 180, y: 100, start: { id: "start" }, end: { id: "work" }, ...arrow },
    { type: "arrow", x: 180, y: 240, start: { id: "work" }, end: { id: "check" }, ...arrow },
    { type: "arrow", x: 180, y: 430, start: { id: "check" }, end: { id: "end" }, label: { text: "yes" }, ...arrow },
    { type: "arrow", x: 270, y: 375, start: { id: "check" }, end: { id: "start" }, label: { text: "no" }, points: [[0, 0], [150, 0], [150, -310], [-10, -310]], ...arrow },
  ];
  build("editor-api/flow/basic", flow());
  build("editor-api/flow/colors", [
    { type: "rectangle", id: "a", x: 40, y: 40, width: 150, height: 60, label: { text: "A" }, backgroundColor: FILLS[0], fillStyle: "solid", strokeColor: STROKES[1] },
    { type: "rectangle", id: "b", x: 260, y: 40, width: 150, height: 60, label: { text: "B" }, backgroundColor: FILLS[1], fillStyle: "solid", strokeColor: STROKES[2] },
    { type: "rectangle", id: "c", x: 480, y: 40, width: 150, height: 60, label: { text: "C" }, backgroundColor: FILLS[2], fillStyle: "solid", strokeColor: STROKES[3] },
    { type: "arrow", x: 190, y: 70, start: { id: "a" }, end: { id: "b" }, strokeColor: STROKES[4] },
    { type: "arrow", x: 410, y: 70, start: { id: "b" }, end: { id: "c" }, strokeColor: STROKES[4] },
  ]);
  for (const fillStyle of ["hachure", "cross-hatch", "zigzag", "solid"]) {
    build(`editor-api/flow/${fillStyle}`, flow({ fillStyle, backgroundColor: "#a5d8ff" }));
  }
  build("editor-api/flow/dashed", flow({ strokeStyle: "dashed" }, { strokeStyle: "dashed" }));
  build("editor-api/flow/dotted-thick", flow({ strokeStyle: "dotted", strokeWidth: 4 }, { strokeStyle: "dotted", strokeWidth: 4 }));
  build("editor-api/flow/rounded-curved", flow({ roundness: { type: 3 } }, { roundness: { type: 2 } }));
  build("editor-api/flow/roughness-0", flow({ roughness: 0, backgroundColor: "#ffec99", fillStyle: "solid" }, { roughness: 0 }));
  build("editor-api/flow/roughness-2", flow({ roughness: 2, backgroundColor: "#b2f2bb" }, { roughness: 2 }));
  for (const font of [1, 3, 6, 8]) build(`editor-api/flow/font-${font}`, flow({}, {}, font));

  // Architecture diagrams.
  const arch = (extra = []) => [
    { type: "rectangle", id: "web", x: 20, y: 140, width: 130, height: 70, label: { text: "Web" }, backgroundColor: FILLS[2], fillStyle: "solid" },
    { type: "rectangle", id: "gw", x: 240, y: 140, width: 150, height: 70, label: { text: "API gateway" }, backgroundColor: FILLS[3], fillStyle: "solid" },
    { type: "rectangle", id: "auth", x: 520, y: 40, width: 130, height: 60, label: { text: "Auth" } },
    { type: "rectangle", id: "orders", x: 520, y: 150, width: 130, height: 60, label: { text: "Orders" } },
    { type: "rectangle", id: "search", x: 520, y: 260, width: 130, height: 60, label: { text: "Search" } },
    { type: "ellipse", id: "db", x: 760, y: 140, width: 130, height: 90, label: { text: "DB" }, backgroundColor: FILLS[1], fillStyle: "hachure" },
    { type: "arrow", x: 150, y: 175, start: { id: "web" }, end: { id: "gw" }, label: { text: "HTTPS" } },
    { type: "arrow", x: 390, y: 175, start: { id: "gw" }, end: { id: "auth" } },
    { type: "arrow", x: 390, y: 180, start: { id: "gw" }, end: { id: "orders" } },
    { type: "arrow", x: 390, y: 185, start: { id: "gw" }, end: { id: "search" } },
    { type: "arrow", x: 650, y: 180, start: { id: "orders" }, end: { id: "db" }, startArrowhead: "dot", endArrowhead: "triangle" },
    ...extra,
  ];
  build("editor-api/arch/basic", arch());
  build("editor-api/arch/frame", arch([{ type: "frame", name: "Backend", children: ["auth", "orders", "search"] }]));
  build("editor-api/arch/frame-two", arch([
    { type: "frame", name: "Edge", children: ["web", "gw"] },
    { type: "frame", name: "Services (internal network, three replicas)", children: ["auth", "orders", "search"] },
  ]));
  build("editor-api/arch/frame-unnamed", arch([{ type: "frame", children: ["db"] }]));
  build("editor-api/arch/title-and-notes", arch([
    { type: "text", id: "title", x: 20, y: -40, text: "Shop architecture", fontSize: 28 },
    { type: "text", id: "note", x: 520, y: 340, text: "stateless services\nscale horizontally", fontSize: 16, strokeColor: STROKES[3] },
    { type: "line", x: 200, y: 20, points: [[0, 0], [0, 330]], strokeStyle: "dashed", strokeColor: "#868e96" },
  ]));
  build("editor-api/arch/arrowheads", [
    { type: "rectangle", id: "p", x: 0, y: 0, width: 100, height: 50, label: { text: "P" } },
    ...["arrow", "bar", "dot", "circle", "circle_outline", "triangle", "triangle_outline", "diamond", "diamond_outline", "crowfoot_one", "crowfoot_many", "crowfoot_one_or_many"].flatMap((head, i) => [
      { type: "rectangle", id: `q${i}`, x: 260, y: i * 80 - 100, width: 100, height: 50, label: { text: head.slice(0, 8) } },
      { type: "arrow", x: 100, y: 25, start: { id: "p" }, end: { id: `q${i}` }, startArrowhead: i % 3 === 0 ? "bar" : null, endArrowhead: head },
    ]),
  ]);
  build("editor-api/arch/links-and-groups", arch(), {}, (els) => {
    els[0].link = "https://example.com/web";
    els[1].link = "https://example.com/gw?a=1&b=2";
    els.filter((e) => ["e3", "e4", "e5"].includes(e.id)).forEach((e) => { e.groupIds = ["g1"]; });
  });
  build("editor-api/arch/opacity-rotation", arch(), {}, (els) => {
    els[2].opacity = 50;
    els[3].angle = 0.12;
    els[4].angle = -0.3;
    els[5].opacity = 70;
  });
  build("editor-api/arch/background-off", arch(), { appState: { exportBackground: false } });
  build("editor-api/arch/background-color", arch(), { appState: { viewBackgroundColor: "#f8f9fa" } });
  build("editor-api/arch/url-fonts", arch([{ type: "text", id: "cn", x: 20, y: 300, text: "网关 → 服务", fontSize: 20 }]), { fonts: "url" });

  // Text scenes.
  build("editor-api/text/notes", [
    { type: "text", id: "n1", x: 0, y: 0, text: "Shopping list\n- milk\n- eggs\n- bread", fontSize: 20 },
    { type: "text", id: "n2", x: 260, y: 0, text: "Done\n✔ milk", fontSize: 16, strokeColor: STROKES[2], fontFamily: 6 },
    { type: "text", id: "n3", x: 0, y: 160, text: "code: x = 1;\nreturn x;", fontSize: 18, fontFamily: 3 },
  ]);
  build("editor-api/text/cjk-emoji", [
    { type: "text", id: "n1", x: 0, y: 0, text: "你好，世界\nこんにちは\n안녕하세요", fontSize: 24 },
    { type: "text", id: "n2", x: 0, y: 140, text: "launch 🚀 done ✅", fontSize: 20 },
    { type: "rectangle", id: "r", x: 300, y: 0, width: 200, height: 90, label: { text: "你好 box" } },
  ], { fonts: "url" });
  build("editor-api/text/rtl", [
    { type: "text", id: "n1", x: 0, y: 0, text: "مرحبا بالعالم", fontSize: 24, fontFamily: 6 },
    { type: "text", id: "n2", x: 0, y: 60, text: "שלום עולם", fontSize: 24, fontFamily: 6 },
    { type: "rectangle", id: "r", x: 300, y: 0, width: 200, height: 90, label: { text: "مرحبا", fontFamily: 6 } },
  ]);

  // Rotation, opacity and groups, written out by hand.
  const el = (type, extra) => ({ ...base, id: `h${extra.n ?? 0}`, type, x: 20, y: 20, width: 140, height: 80, backgroundColor: "#a5d8ff", ...extra });
  handmade("handmade/rotated-shapes", [
    el("rectangle", { n: 1, angle: 0.4 }),
    el("diamond", { n: 2, x: 260, angle: -0.8, backgroundColor: "#ffc9c9" }),
    el("ellipse", { n: 3, x: 500, angle: 1.3, fillStyle: "solid" }),
    { ...textEl("Rotated text", { id: "t", x: 20, y: 200, angle: -0.5 }) },
  ]);
  handmade("handmade/opacity-stack", [
    el("rectangle", { n: 1, opacity: 100, fillStyle: "solid" }),
    el("rectangle", { n: 2, x: 80, y: 40, opacity: 60, fillStyle: "solid", backgroundColor: "#ffc9c9" }),
    el("rectangle", { n: 3, x: 140, y: 80, opacity: 30, fillStyle: "solid", backgroundColor: "#b2f2bb" }),
  ]);
  handmade("handmade/groups", [
    el("rectangle", { n: 1, groupIds: ["g1"] }),
    el("ellipse", { n: 2, x: 200, groupIds: ["g1"] }),
    el("diamond", { n: 3, x: 400, groupIds: ["g2", "g1"] }),
  ]);
  handmade("handmade/rotated-arrow-label", [
    { ...base, id: "a", type: "arrow", x: 40, y: 60, width: 220, height: 80, angle: 0.5, points: [[0, 0], [110, 70], [220, 20]], roundness: { type: 2 }, backgroundColor: "transparent", boundElements: [{ type: "text", id: "t" }], startArrowhead: "dot", endArrowhead: "arrow", lastCommittedPoint: null },
    textEl("rotated", { id: "t", containerId: "a", textAlign: "center", verticalAlign: "middle" }),
  ]);
  handmade("handmade/line-loops", [
    { ...base, id: "l1", type: "line", x: 20, y: 20, width: 100, height: 100, points: [[0, 0], [100, 0], [100, 100], [0, 100], [0, 0]], backgroundColor: "#a5d8ff", fillStyle: "hachure", lastCommittedPoint: null },
    { ...base, id: "l2", type: "line", x: 200, y: 20, width: 100, height: 100, points: [[0, 0], [100, 30], [60, 100], [0, 5]], backgroundColor: "#ffc9c9", fillStyle: "cross-hatch", roundness: { type: 2 }, lastCommittedPoint: null },
  ]);
  handmade("handmade/image-in-frame", [
    { ...base, id: "f", type: "frame", x: 0, y: 0, width: 220, height: 160, name: "Pictures", backgroundColor: "transparent", strokeColor: "#bbb" },
    { ...base, id: "i", type: "image", x: 20, y: 20, width: 100, height: 80, fileId: "abc", status: "saved", scale: [-1, 1], crop: null, frameId: "f", backgroundColor: "transparent", roundness: { type: 3 } },
  ], { files: { abc: { id: "abc", mimeType: "image/png", dataURL: PNG, created: 1 } } });

  // Doodles.
  const r = rng(321);
  const doodle = (n, step) => {
    const points = [[0, 0]];
    let x = 0, y = 0;
    for (let i = 1; i < n; i++) {
      x += (r() - 0.35) * step;
      y += (r() - 0.5) * step;
      points.push([Math.round(x * 100) / 100, Math.round(y * 100) / 100]);
    }
    return points;
  };
  for (let i = 0; i < 3; i++) {
    handmade(`handmade/doodle-${i}`, [
      { ...base, id: "d1", type: "freedraw", x: 20 + i * 5, y: 40, width: 100, height: 60, points: doodle(30 + i * 20, 9), pressures: [], simulatePressure: true, lastCommittedPoint: null, backgroundColor: "transparent", strokeColor: STROKES[i] },
      { ...base, id: "d2", type: "freedraw", x: 200, y: 100, width: 100, height: 60, points: doodle(25, 12), pressures: [], simulatePressure: true, lastCommittedPoint: null, backgroundColor: "transparent", strokeWidth: 1 + i, opacity: 80 },
    ]);
  }

  // Random mixes of everything.
  const pick = (a) => a[Math.floor(r() * a.length)];
  for (let s = 0; s < 14; s++) {
    const elements = [];
    for (let i = 0; i < 14; i++) {
      const common = { id: `r${i}`, x: Math.round((r() - 0.2) * 600), y: Math.round((r() - 0.2) * 400), angle: pick([0, 0, 0, 0.3, -1.1]), opacity: pick([100, 100, 70]), strokeColor: pick(STROKES), backgroundColor: pick(FILLS), fillStyle: pick(["hachure", "solid", "cross-hatch", "zigzag"]), strokeWidth: pick([1, 2, 4]), strokeStyle: pick(["solid", "solid", "dashed", "dotted"]), roughness: pick([0, 1, 2]), seed: 1 + Math.floor(r() * 2 ** 31 - 2), roundness: pick([null, null, { type: 3 }]) };
      const kind = pick(["rectangle", "diamond", "ellipse", "line", "arrow", "text", "freedraw"]);
      if (kind === "text") elements.push(textEl(pick(["tag", "two\nlines", "你好", "x & y"]), { ...common, roundness: null, fontFamily: pick([1, 3, 5, 6]), backgroundColor: "transparent" }));
      else if (kind === "line" || kind === "arrow") {
        const points = pick([[[0, 0], [80, 30]], [[0, 0], [40, 60], [90, 10]], [[0, 0], [30, 50], [70, 20], [100, 70]]]);
        elements.push({ ...base, ...common, type: kind, width: 100, height: 70, points, backgroundColor: "transparent", lastCommittedPoint: null, startArrowhead: kind === "arrow" ? pick([null, "dot", "bar"]) : null, endArrowhead: kind === "arrow" ? pick(["arrow", "triangle", "diamond", null]) : null, roundness: pick([null, { type: 2 }]) });
      } else if (kind === "freedraw") {
        elements.push({ ...base, ...common, type: "freedraw", width: 60, height: 40, points: doodle(12, 8), pressures: [], simulatePressure: true, lastCommittedPoint: null, roundness: null, backgroundColor: "transparent" });
      } else elements.push({ ...base, ...common, type: kind, width: pick([60, 120, 40]), height: pick([40, 90, 20]), roundness: kind === "ellipse" ? null : common.roundness });
    }
    handmade(`random/${s}`, elements);
  }
  // Scenes drawn in the real editor, kept as the files the editor wrote.
  const dir = join(root, "fixtures", "scenes");
  for (const file of readdirSync(dir).filter((f) => f.endsWith(".excalidraw")).sort()) {
    // Line endings follow the checkout (git may turn \n into \r\n on Windows), and
    // the fixture embeds the text, so make them the same everywhere.
    const raw = readFileSync(join(dir, file), "utf8").replace(/\r\n/g, "\n");
    cases.push({ name: `real/${file}`, scene: JSON.parse(raw), raw });
  }
  return cases;
}
