// Inputs for the LZ-String tests. The expected output is what lz-string 1.5.0,
// the package the Obsidian Excalidraw plugin uses, makes of them.
import { readdirSync, readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import LZString from "lz-string";
import { rng } from "./mbt.mjs";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");

export function lzInputs() {
  const r = rng(7);
  const pick = (alphabet, n) => {
    const chars = [...alphabet];
    let s = "";
    for (let i = 0; i < n; i++) s += chars[Math.floor(r() * chars.length)];
    return s;
  };
  const inputs = [
    ["empty", ""],
    ["one char", "a"],
    ["two chars", "ab"],
    ["repeat", "a".repeat(1000)],
    ["repeat pair", "ab".repeat(700)],
    ["sentence", "The quick brown fox jumps over the lazy dog. ".repeat(20)],
    ["latin-1", "café über naïve ÿ"],
    ["code unit 255 and 256", "ÿĀÿĀ"],
    ["cjk", "你好，世界。这是一个测试。".repeat(30)],
    ["emoji", "😀 smile 😀 smile 🚀🚀🚀".repeat(10)],
    ["mixed", "abc 中文 😀 def é\n\t\"quoted\" \\ back".repeat(25)],
    ["json", JSON.stringify({ type: "excalidraw", version: 2, elements: [{ id: "a", text: "café 中" }] }, null, "\t")],
    ["newlines", "line\r\nline\r\nline\n".repeat(50)],
    ["ascii noise", pick("abcdefghijklmnopqrstuvwxyz0123456789 ", 3000)],
    ["byte noise", pick(String.fromCharCode(...Array.from({ length: 256 }, (_, i) => i)), 3000)],
    ["bmp noise", pick("αβγδεζηθ中文字符测试日本語한국어абвгд", 3000)],
    ["dictionary growth", Array.from({ length: 4000 }, (_, i) => String.fromCharCode(32 + ((i * 7) % 90)) + String.fromCharCode(32 + ((i * 13) % 90))).join("")],
  ];
  // Whole files: the scenes the tests render, as the plugin writes them
  // (tab-indented JSON).
  for (const dir of ["examples/site/diagrams", "fixtures/scenes"]) {
    for (const f of readdirSync(join(root, dir)).filter((f) => f.endsWith(".excalidraw")).sort()) {
      const scene = JSON.parse(readFileSync(join(root, dir, f), "utf8"));
      inputs.push([`scene ${f}`, JSON.stringify(scene, null, "\t")]);
    }
  }
  return inputs;
}

export function lzCases() {
  return lzInputs().map(([name, input]) => ({ name, input, compressed: LZString.compressToBase64(input) }));
}
