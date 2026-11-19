// The demo page. The left side calls only ./moon_excalidraw.js, the compiled
// MoonBit module. The official package is ./official.js and is loaded on its own;
// it draws the right side and nothing else.
import { render } from "./moon_excalidraw.js";

const $ = (id) => document.getElementById(id);
const verdict = $("verdict");

// Both sides measure text with 7px per code point, the metric the test suite
// uses. In a browser the official export would otherwise measure with the real
// font; this only matters for frame titles.
const measureWidth = (text) => [...text].length * 7;
CanvasRenderingContext2D.prototype.measureText = function (text) {
  return { width: measureWidth(text) };
};

let official = null;
async function loadOfficial() {
  if (!official) {
    window.EXCALIDRAW_ASSET_PATH = new URL("./", location.href).href;
    official = import("./official.js");
  }
  return official;
}

function runOurs(text) {
  const out = JSON.parse(render(text, "none"));
  return out.ok ? { svg: out.svg, warnings: out.warnings } : { error: out.error };
}

async function runOfficial(text) {
  let scene;
  try {
    scene = JSON.parse(text);
  } catch (e) {
    return { error: `not valid JSON (${e.message})` };
  }
  try {
    const { exportToSvg } = await loadOfficial();
    const appState = scene.appState ?? {};
    const svg = await exportToSvg({
      elements: (scene.elements ?? []).filter((e) => !e.isDeleted),
      appState: {
        exportBackground: appState.exportBackground ?? true,
        viewBackgroundColor: appState.viewBackgroundColor ?? "#ffffff",
      },
      files: scene.files ?? {},
      skipInliningFonts: true,
    });
    const html = svg.outerHTML;
    return { svg: html.toWellFormed ? html.toWellFormed() : html };
  } catch (e) {
    return { error: String(e && e.message ? e.message : e) };
  }
}

const urls = {};
function show(side, result) {
  const view = $(`${side}-view`);
  const meta = $(`${side}-meta`);
  const src = $(`${side}-src`);
  if (urls[side]) URL.revokeObjectURL(urls[side]);
  urls[side] = null;
  view.replaceChildren();
  if (result.svg) {
    urls[side] = URL.createObjectURL(new Blob([result.svg], { type: "image/svg+xml" }));
    const img = document.createElement("img");
    img.alt = `${side} rendering`;
    img.src = urls[side];
    view.append(img);
    src.textContent = result.svg;
    const w = result.warnings ?? [];
    meta.textContent = `${result.svg.length.toLocaleString()} characters` + (w.length ? `, ${w.length} warning(s): ${w.join(" | ")}` : "");
  } else {
    const msg = document.createElement("div");
    msg.className = "msg";
    msg.textContent = result.error;
    view.append(msg);
    src.textContent = "";
    meta.textContent = "No SVG";
  }
}

function firstDifference(a, b) {
  let i = 0;
  while (i < a.length && i < b.length && a[i] === b[i]) i++;
  return i;
}

function compare(ours, theirs) {
  verdict.className = "";
  if (ours.svg && theirs.svg) {
    if (ours.svg === theirs.svg) {
      verdict.className = "ok";
      verdict.innerHTML = "The two SVGs are identical, byte for byte.<small></small>";
      verdict.querySelector("small").textContent = `${ours.svg.length.toLocaleString()} characters on both sides.`;
      return;
    }
    const i = firstDifference(ours.svg, theirs.svg);
    verdict.className = "bad";
    verdict.innerHTML = "The two SVGs are different.<small></small>";
    const skipped = ours.warnings?.length ? ` This library skipped something it does not draw (see the warning under the left preview).` : "";
    verdict.querySelector("small").textContent =
      `First difference at character ${i}. ours: …${ours.svg.slice(Math.max(0, i - 30), i + 50)}…  official: …${theirs.svg.slice(Math.max(0, i - 30), i + 50)}…${skipped}`;
    return;
  }
  if (!ours.svg && !theirs.svg) {
    verdict.className = "ok";
    verdict.innerHTML = "Neither side can render this file.<small></small>";
    verdict.querySelector("small").textContent = `ours: ${ours.error}  official: ${theirs.error}`;
    return;
  }
  verdict.className = "bad";
  verdict.innerHTML = "Only one side could render this file.<small></small>";
  verdict.querySelector("small").textContent = ours.svg ? `official: ${theirs.error}` : `ours: ${ours.error}`;
}

async function run(text) {
  verdict.className = "";
  verdict.textContent = "Rendering…";
  const ours = runOurs(text);
  show("ours", ours);
  const theirs = await runOfficial(text);
  show("official", theirs);
  compare(ours, theirs);
}

async function runFile(file) {
  for (const b of document.querySelectorAll("#examples button")) b.setAttribute("aria-pressed", "false");
  await run(await file.text());
}

async function main() {
  const list = await (await fetch("./examples/index.json")).json();
  const bar = $("examples");
  for (const [i, ex] of list.entries()) {
    const button = document.createElement("button");
    button.textContent = ex.name;
    button.setAttribute("aria-pressed", "false");
    button.addEventListener("click", async () => {
      for (const b of bar.children) b.setAttribute("aria-pressed", "false");
      button.setAttribute("aria-pressed", "true");
      await run(await (await fetch(`./examples/${ex.file}`)).text());
    });
    bar.append(button);
    if (i === 0) button.click();
  }
  $("file").addEventListener("change", (e) => {
    const file = e.target.files[0];
    if (file) runFile(file);
  });
  const drop = $("drop");
  for (const type of ["dragenter", "dragover"]) {
    drop.addEventListener(type, (e) => {
      e.preventDefault();
      drop.classList.add("over");
    });
  }
  for (const type of ["dragleave", "drop"]) {
    drop.addEventListener(type, (e) => {
      e.preventDefault();
      drop.classList.remove("over");
    });
  }
  // A file dropped anywhere on the page is accepted, the drop zone included.
  window.addEventListener("dragover", (e) => e.preventDefault());
  window.addEventListener("drop", (e) => {
    e.preventDefault();
    const file = e.dataTransfer.files[0];
    if (file) runFile(file);
  });
}

main().catch((e) => {
  verdict.className = "bad";
  verdict.textContent = `The page failed to start: ${e && e.message ? e.message : e}`;
});
