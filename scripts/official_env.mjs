// Runs the official @excalidraw/excalidraw prod bundle under Node + jsdom.
// The bundle needs esbuild (its ESM imports don't resolve in plain Node) and a
// few DOM stubs. Everything is pinned by package-lock.json.
import { execFileSync } from "node:child_process";
import { existsSync, mkdirSync, readFileSync } from "node:fs";
import { createRequire } from "node:module";
import { dirname, join } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import { JSDOM } from "jsdom";

const here = dirname(fileURLToPath(import.meta.url));
export const bundlePath = join(here, ".cache", "excalidraw.bundle.mjs");

const require = createRequire(import.meta.url);

export function checkVersions() {
  const version = (name) =>
    JSON.parse(readFileSync(join(here, "node_modules", name, "package.json"), "utf8")).version;
  const expected = {
    "@excalidraw/excalidraw": "0.18.1",
    "perfect-freehand": "1.2.0",
    roughjs: "4.6.4",
    "points-on-curve": "1.0.1",
  };
  for (const [name, want] of Object.entries(expected)) {
    const got = version(name);
    if (got !== want) throw new Error(`${name}: expected ${want}, found ${got}`);
  }
}

export function buildBundle() {
  if (existsSync(bundlePath)) return bundlePath;
  mkdirSync(dirname(bundlePath), { recursive: true });
  const esbuild = require.resolve("esbuild/bin/esbuild");
  execFileSync(
    process.execPath,
    [
      esbuild,
      join(here, "node_modules/@excalidraw/excalidraw/dist/prod/index.js"),
      "--bundle",
      "--platform=browser",
      "--format=esm",
      `--outfile=${bundlePath}`,
      "--loader:.woff2=dataurl",
      "--loader:.css=empty",
      "--log-level=error",
      '--define:process.env.NODE_ENV="production"',
    ],
    { stdio: "inherit" },
  );
  return bundlePath;
}

/** The deterministic text metric both sides use: 7px per code point. */
export const measureWidth = (text) => [...text].length * 7;

let loaded = null;
let fetchFails = false;

function installDom() {
  const dom = new JSDOM("<!doctype html><html><body></body></html>", {
    url: "http://localhost/",
    pretendToBeVisual: true,
  });
  const g = globalThis;
  for (const k of ["window", "document", "HTMLElement", "Element", "Node", "SVGElement", "DOMParser", "XMLSerializer", "Image", "Blob", "FileReader", "getComputedStyle", "devicePixelRatio", "requestAnimationFrame", "cancelAnimationFrame", "localStorage", "HTMLCanvasElement", "File"]) {
    if (dom.window[k] !== undefined) {
      Object.defineProperty(g, k, { value: dom.window[k], configurable: true, writable: true });
    }
  }
  Object.defineProperty(g, "navigator", { value: dom.window.navigator, configurable: true });
  g.Path2D = g.window.Path2D = class { constructor(d) { this.d = d; } };
  g.FontFace = g.window.FontFace = class {
    constructor(family, src, desc) { Object.assign(this, { family, src, ...desc }); }
    load() { return Promise.resolve(this); }
  };
  document.fonts = { add() {}, has() { return false; }, check() { return true; }, load: async () => [], ready: Promise.resolve(), addEventListener() {}, removeEventListener() {} };
  g.matchMedia = g.window.matchMedia = () => ({ matches: false, addListener() {}, removeListener() {}, addEventListener() {}, removeEventListener() {} });
  g.ResizeObserver = class { observe() {} unobserve() {} disconnect() {} };
  dom.window.HTMLCanvasElement.prototype.getContext = function () {
    return { filter: "none", font: "", measureText: (t) => ({ width: measureWidth(t) }) };
  };
  const realFetch = g.fetch;
  g.fetch = g.window.fetch = (...args) => (fetchFails ? Promise.reject(new Error("offline")) : realFetch(...args));
}

export async function loadOfficial() {
  if (loaded) return loaded;
  checkVersions();
  buildBundle();
  installDom();
  const quiet = console.error;
  console.error = () => {};
  const mod = await import(pathToFileURL(bundlePath).href);
  console.error = quiet;
  loaded = { ...mod, setFetchFails: (v) => { fetchFails = v; } };
  return loaded;
}

/**
 * Exports a parsed scene the way the fixtures define it: deleted elements are
 * filtered first, and appState only carries the two fields we support.
 * `fonts` is "none" (skipInliningFonts) or "url" (fetch fails, so the official
 * code falls back to @font-face URLs). Throws if the official code throws.
 */
export async function exportScene(scene, { fonts = "none" } = {}) {
  const { exportToSvg, setFetchFails } = await loadOfficial();
  const appState = scene.appState ?? {};
  const options = {
    elements: (scene.elements ?? []).filter((e) => !e.isDeleted),
    appState: {
      exportBackground: appState.exportBackground ?? true,
      viewBackgroundColor: appState.viewBackgroundColor ?? "#ffffff",
    },
    files: scene.files ?? {},
  };
  setFetchFails(fonts === "url");
  const quiet = console.error;
  console.error = () => {};
  try {
    if (fonts === "none") options.skipInliningFonts = true;
    return (await exportToSvg(options)).outerHTML.toWellFormed();
  } finally {
    console.error = quiet;
    setFetchFails(false);
  }
}
