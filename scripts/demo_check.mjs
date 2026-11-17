// Checks what the demo page shows: the compiled JavaScript module renders each
// example and each scene drawn in the real editor to the same SVG as the
// official export. The official side runs under jsdom, as for the fixtures.
//
//   moon build --target js --release        (from the repository root)
//   cd scripts && node demo_check.mjs
import { readdirSync, readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import { exportScene } from "./official_env.mjs";

const here = dirname(fileURLToPath(import.meta.url));
const root = join(here, "..");
const { render } = await import(pathToFileURL(join(root, "_build/js/release/build/web/web.js")).href);

const files = ["examples/site/diagrams", "fixtures/scenes"].flatMap((dir) =>
  readdirSync(join(root, dir))
    .filter((f) => f.endsWith(".excalidraw"))
    .sort()
    .map((f) => join(dir, f)),
);

let failed = 0;
for (const file of files) {
  const text = readFileSync(join(root, file), "utf8");
  const ours = JSON.parse(render(text, "none"));
  const official = await exportScene(JSON.parse(text), { fonts: "none" });
  let verdict = "identical";
  if (!ours.ok) verdict = `ours failed: ${ours.error}`;
  else if (ours.svg !== official) {
    let i = 0;
    while (ours.svg[i] === official[i]) i++;
    verdict = `different at ${i}: ours …${ours.svg.slice(i - 20, i + 40)}… official …${official.slice(i - 20, i + 40)}…`;
  }
  if (verdict !== "identical") failed++;
  console.log(`${verdict === "identical" ? "ok  " : "FAIL"} ${file}: ${verdict}`);
}
console.log(`${files.length - failed}/${files.length} identical`);
process.exit(failed ? 1 : 0);
