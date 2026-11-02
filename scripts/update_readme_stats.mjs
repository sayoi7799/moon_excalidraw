// Runs the conformance tests and rewrites the table between the stats markers in
// README.md, so the numbers there are the ones the tests print.
//
//   cd scripts && node update_readme_stats.mjs [--check]
//
// --check exits with 1 if the README table is out of date instead of writing it.
import { execSync } from "node:child_process";
import { readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const readme = join(root, "README.md");
const BEGIN = "<!-- stats:begin -->";
const END = "<!-- stats:end -->";

const run = (pkg) =>
  execSync(`moon test --target js -p sayoi7799/moon_excalidraw/${pkg}`, { cwd: root, encoding: "utf8", maxBuffer: 1 << 28, stdio: ["ignore", "pipe", "pipe"] });

const out = ["export", "freehand", "model", "svg", "internal/jsnum", "internal/conform"].map(run).join("\n");

const rows = [];
for (const m of out.matchAll(/\[conformance\] suite=(.+?) total=(\d+) identical=(\d+) structural=(\d+) attribute=(\d+) numeric=(\d+) max_delta=(\S+)/g)) {
  const [, suite, total, identical, structural, attribute, numeric, delta] = m;
  rows.push({ suite, total: +total, identical: +identical, other: +structural + +attribute + +numeric, delta });
}
if (!rows.length) throw new Error("no conformance lines in the test output");
const order = ["single basic", "single linear", "single text", "single misc", "fonts", "combined", "edge cases"];
rows.sort((a, b) => order.indexOf(a.suite) - order.indexOf(b.suite));
const label = {
  "single basic": "Rectangles, diamonds, ellipses × fill, stroke, roughness, roundness",
  "single linear": "Lines, arrows, closed fills, all arrowhead styles",
  "single text": "Text: every font id, alignment, direction, bound to shapes and arrows",
  "single misc": "Freedraw, images, frames, links",
  fonts: "Font rules (`FontMode::Url`) for each family and character set",
  combined: "Diagrams (editor API, hand-made, random, and 3 drawn in the real editor)",
  "edge cases": "Empty and degenerate scenes, extreme numbers, old formats, official errors",
};
const lines = [
  "| Suite | What it covers | Scenes | Byte-identical | Different |",
  "|---|---|---:|---:|---:|",
  ...rows.map((r) => `| ${r.suite} | ${label[r.suite] ?? ""} | ${r.total} | ${r.identical} | ${r.other} |`),
];
const total = rows.reduce((n, r) => n + r.total, 0);
const same = rows.reduce((n, r) => n + r.identical, 0);
lines.push(`| **Total** | | **${total}** | **${same}** | **${total - same}** |`);

const pick = (re) => {
  const m = out.match(re);
  if (!m) throw new Error(`missing line ${re}`);
  return m;
};
const [, fhTotal, fhBad] = pick(/\[freehand\] total=(\d+) mismatched=(\d+)/);
const [, rsTotal, rsBad] = pick(/\[restore\] total=(\d+) mismatched=(\d+)/);
const jsnum = ["hypot", "atan2", "cube", "parse_float"].map((n) => {
  const m = out.match(new RegExp(`\\[jsnum\\] ${n}: total=(\\d+) mismatched=(\\d+)`));
  return m ? { n, total: +m[1], bad: +m[2] } : null;
}).filter(Boolean);
const [, jdTotal, jdBad] = pick(/\[json doubles\] total=(\d+) mismatched=(\d+)/);

lines.push(
  "",
  "| Lower-level check | Cases | Different |",
  "|---|---:|---:|",
  `| perfect-freehand outlines, every number compared by bit pattern | ${fhTotal} | ${fhBad} |`,
  `| \`restoreElements\` normalisation of old and partial elements | ${rsTotal} | ${rsBad} |`,
  `| JSON numbers read like V8 does | ${jdTotal} | ${jdBad} |`,
  ...jsnum.map((j) => {
    const name = j.n === "cube" ? "x³ correctly rounded (V8's `Math.pow(x, 3)` varies by platform)" : j.n === "parse_float" ? "`parseFloat`" : `\`Math.${j.n}\``;
    return `| ${name} | ${j.total} | ${j.bad} |`;
  }),
);
const table = `${BEGIN}\n${lines.join("\n")}\n${END}`;

const text = readFileSync(readme, "utf8");
const a = text.indexOf(BEGIN);
const b = text.indexOf(END);
if (a < 0 || b < 0) throw new Error("stats markers not found in README.md");
const next = text.slice(0, a) + table + text.slice(b + END.length);
if (process.argv.includes("--check")) {
  if (next !== text) {
    console.error("README stats are out of date; run: node scripts/update_readme_stats.mjs");
    process.exit(1);
  }
  console.log("README stats are up to date");
} else {
  writeFileSync(readme, next);
  console.log(table);
}
