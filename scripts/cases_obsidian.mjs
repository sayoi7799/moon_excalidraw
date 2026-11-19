// Test files in the layout of the Obsidian Excalidraw plugin's `.excalidraw.md`.
// The layout is the one the plugin documents and its files show; nothing here is
// the plugin's code. The compression is lz-string 1.5.0, which the plugin uses,
// and the JSON is written with tab indentation, as the plugin writes it.
import { readdirSync, readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import LZString from "lz-string";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");

const BANNER =
  "==⚠  Switch to EXCALIDRAW VIEW in the MORE OPTIONS menu of this document. ⚠== You can decompress Drawing data with the command palette: 'Decompress current Excalidraw file'. For more info check in plugin settings under 'Saving'\n\n";

/** The drawing, in 256 character pieces with a blank line between them. */
function chunked(text) {
  const parts = [];
  for (let i = 0; i < text.length; i += 256) parts.push(text.slice(i, i + 256));
  return parts.join("\n\n");
}

/**
 * One file. `texts` are the lines of "## Text Elements", `embedded` those of
 * "## Embedded Files". Options: `compress`, `commented` (the text section sits
 * inside a %% comment), `mode` (front matter), `eol`, `oneLine` (the payload is
 * not cut into pieces).
 */
export function markdown(scene, { texts = {}, embedded = {}, compress = true, commented = true, mode = "raw", eol = "\n", oneLine = false } = {}) {
  const json = JSON.stringify(scene, null, "\t");
  const payload = compress ? (oneLine ? LZString.compressToBase64(json) : chunked(LZString.compressToBase64(json))) : json;
  let md = `---\nexcalidraw-plugin: ${mode}\ntags: [excalidraw]\n\n---\n${BANNER}`;
  if (commented) md += "%%\n";
  md += "# Excalidraw Data\n\n## Text Elements\n";
  for (const [id, text] of Object.entries(texts)) md += `${text} ^${id}\n\n`;
  const files = Object.entries(embedded);
  if (files.length) {
    md += "## Embedded Files\n";
    for (const [id, path] of files) md += `${id}: [[${path}]]\n\n`;
  }
  md += `${commented ? "" : "%%\n"}## Drawing\n\`\`\`${compress ? "compressed-json" : "json"}\n${payload}\n\`\`\`\n%%`;
  return md.replace(/\n/g, eol);
}

/** The scenes the files are made from: the examples and the real-editor scenes. */
function sceneFiles() {
  const out = [];
  for (const dir of ["examples/site/diagrams", "fixtures/scenes"]) {
    for (const f of readdirSync(join(root, dir)).filter((f) => f.endsWith(".excalidraw")).sort()) {
      out.push({ name: f.replace(/\.excalidraw$/, ""), scene: JSON.parse(readFileSync(join(root, dir, f), "utf8").replace(/\r\n/g, "\n")) });
    }
  }
  return out;
}

const base = { version: 1, versionNonce: 1, isDeleted: false, fillStyle: "solid", strokeWidth: 2, strokeStyle: "solid", roughness: 1, opacity: 100, angle: 0, strokeColor: "#1e1e1e", backgroundColor: "transparent", seed: 4242, groupIds: [], frameId: null, roundness: null, boundElements: null, updated: 1, link: null, locked: false };
const text = (id, t, extra = {}) => ({ ...base, type: "text", id, x: 10, y: 10 + (extra.row ?? 0) * 40, width: 160, height: 25, text: t, originalText: t, fontSize: 20, fontFamily: 5, textAlign: "left", verticalAlign: "top", containerId: null, lineHeight: 1.25, ...extra.fields });
const withApp = (elements, files = {}) => ({ type: "excalidraw", version: 2, source: "https://excalidraw.com", elements, appState: { gridSize: null, viewBackgroundColor: "#ffffff" }, files });

/** A scene whose texts have 8 character ids, as the plugin's own ids do. */
function textScene() {
  const lines = [
    ["aB3dE5gH", "Plain text"],
    ["cD4eF6hJ", "Two lines\nof text"],
    ["eF5gH7jK", "Links [[Some note]] and 中文 😀 & <b>"],
  ];
  return withApp(lines.map(([id, t], i) => text(id, t, { row: i })));
}

/**
 * The cases for the tests. `scene` is the drawing as written in the file;
 * `official` is the scene whose official export the file must render to.
 * `texts` are what the Text Elements section must hold.
 */
export function obsidianCases() {
  const cases = [];
  const add = (name, sceneName, scene, options, { official = scene, texts = {}, embedded = {} } = {}) => {
    cases.push({ name, sceneName, scene, official, md: markdown(scene, { texts, embedded, ...options }), texts, embedded });
  };
  const scenes = sceneFiles();
  for (const { name, scene } of scenes) add(`${name}`, name, scene, {});
  const flow = scenes.find((s) => s.name === "flowchart");
  const frame = scenes.find((s) => s.name === "frame");
  add("flowchart, uncompressed", "flowchart", flow.scene, { compress: false });
  add("frame, uncompressed", "frame", frame.scene, { compress: false });
  add("flowchart, CRLF", "flowchart", flow.scene, { eol: "\r\n" });
  add("flowchart, one line", "flowchart", flow.scene, { oneLine: true });
  add("flowchart, parsed mode", "flowchart", flow.scene, { mode: "parsed" });
  add("flowchart, text section not commented", "flowchart", flow.scene, { commented: false });

  // Texts with the plugin's 8 character ids, written in the Text Elements section.
  const ts = textScene();
  const written = Object.fromEntries(ts.elements.map((e) => [e.id, e.originalText]));
  add("texts", "texts", ts, {}, { texts: written });
  add("texts, CRLF", "texts", ts, { eol: "\r\n" }, { texts: written });
  add("texts, uncompressed", "texts", ts, { compress: false }, { texts: written });

  // A text the drawing holds empty, which only the Text Elements section has.
  const emptied = withApp(ts.elements.map((e) => (e.id === "cD4eF6hJ" ? { ...e, text: "", originalText: "" } : e)));
  add("texts, one empty in the drawing", "texts", emptied, {}, { official: ts, texts: written });

  // The section was edited by hand: the drawing as last saved is shown.
  add("texts, section edited", "texts", ts, {}, { texts: { ...written, aB3dE5gH: "Edited by hand" } });

  // An image that lives in the vault, which the drawing has no data for.
  const image = { ...base, type: "image", id: "img00001", x: 0, y: 100, width: 80, height: 60, fileId: "f1a2b3c4d5e6f7a8", status: "saved", scale: [1, 1], crop: null };
  const withImage = withApp([...ts.elements, image]);
  add("texts and an image in the vault", "texts", withImage, {}, { official: withImage, texts: written, embedded: { f1a2b3c4d5e6f7a8: "Pasted image 20260101.png" } });
  return cases;
}
