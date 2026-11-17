// Builds the demo page into an output folder:
//
//   moon build --target js --release          (from the repository root)
//   cd scripts && node build_demo.mjs [out-dir]     (default: ../demo-dist)
//
// The page's left side is the compiled MoonBit module; the right side is the
// official package, bundled here from the version pinned by package-lock.json.
import { buildSync } from "esbuild";
import { copyFileSync, existsSync, mkdirSync, readdirSync, rmSync, writeFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { checkVersions } from "./official_env.mjs";

const here = dirname(fileURLToPath(import.meta.url));
const root = join(here, "..");
const out = resolve(process.argv[2] ?? join(root, "demo-dist"));

const moonJs = join(root, "_build/js/release/build/web/web.js");
if (!existsSync(moonJs)) throw new Error(`${moonJs} not found; run: moon build --target js --release`);

checkVersions();
rmSync(out, { recursive: true, force: true });
mkdirSync(join(out, "examples"), { recursive: true });

copyFileSync(join(root, "demo/index.html"), join(out, "index.html"));
copyFileSync(join(root, "demo/app.js"), join(out, "app.js"));
copyFileSync(moonJs, join(out, "moon_excalidraw.js"));

// The page never exports with fonts, so the font files are left out of the bundle.
buildSync({
  entryPoints: [join(here, "node_modules/@excalidraw/excalidraw/dist/prod/index.js")],
  bundle: true,
  minify: true,
  platform: "browser",
  format: "esm",
  outfile: join(out, "official.js"),
  loader: { ".woff2": "empty", ".css": "empty" },
  logLevel: "error",
  define: { "process.env.NODE_ENV": '"production"' },
});

const dir = join(root, "examples/site/diagrams");
const list = [];
for (const file of readdirSync(dir).filter((f) => f.endsWith(".excalidraw")).sort()) {
  copyFileSync(join(dir, file), join(out, "examples", file));
  list.push({ name: file.replace(/\.excalidraw$/, ""), file });
}
writeFileSync(join(out, "examples/index.json"), JSON.stringify(list, null, 2) + "\n");
console.log(`wrote ${out}: ${list.length} examples`);
