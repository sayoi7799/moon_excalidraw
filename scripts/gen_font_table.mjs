// Writes src/text/font_faces_gen.mbt: the official font table, read from the
// FontFace objects the package creates, and the CJK character set its fallback
// check uses, computed with the same Unicode regular expression.
import { str, writeGen } from "./mbt.mjs";
import { exportScene } from "./official_env.mjs";
import { doc } from "./cases_single.mjs";
import { textEl } from "./cases_text.mjs";

const IDS = { Virgil: 1, Helvetica: 2, Cascadia: 3, Excalifont: 5, Nunito: 6, "Lilita One": 7, "Comic Shanns": 8, "Liberation Sans": 9, Xiaolai: 100, "Segoe UI Emoji": 1000 };

// The four groups of `CJK_REGEX_SOURCES` in the package, joined into one class.
const CJK_SOURCES = [
  String.raw`\p{Script=Han}\p{Script=Hiragana}\p{Script=Katakana}\p{Script=Hangul}｀＇＾〃〰〆＃＆＊＋－ー／＼＝｜￤〒￢￣`,
  "（［｛〈《｟｢「『【〖〔〘〚＜〝",
  "）］｝〉》｠｣」』】〗〕〙〛＞。．，、〟‥？！：；・〜〞",
  "￥￦￡￠＄",
];

export async function writeFontTable() {
  // Any export that draws text makes the package register its fonts.
  await exportScene(doc([textEl("a")]), { fonts: "url" });
  const rows = [];
  for (const face of globalThis.__fontFaces) {
    const urls = [...String(face.src).matchAll(/url\(([^)]*)\)/g)].map((m) => m[1]);
    if (!urls.length) continue; // local fonts have no file to point at
    if (!(face.family in IDS)) throw new Error(`unknown font family ${face.family}`);
    const ranges = face.unicodeRange.split(/,\s*/).flatMap((part) => {
      if (part.includes("?")) throw new Error(`wildcard unicode range ${part}`);
      const [lo, hi] = part.replace("U+", "").split("-");
      return [parseInt(lo, 16), parseInt(hi ?? lo, 16)];
    });
    rows.push(`  { family: ${str(face.family)}, font: ${IDS[face.family]}, url: ${str(urls.at(-1))}, ranges: [${ranges.join(", ")}] },`);
  }
  const cjk = new RegExp(`[${CJK_SOURCES.join("")}]`, "u");
  const spans = [];
  let start = -1;
  for (let cp = 0; cp <= 0x110000; cp++) {
    const hit = cp <= 0x10ffff && !(cp >= 0xd800 && cp <= 0xdfff) && cjk.test(String.fromCodePoint(cp));
    if (hit && start < 0) start = cp;
    if (!hit && start >= 0) {
      spans.push(start, cp - 1);
      start = -1;
    }
  }
  const note = `Node ${process.versions.node}, ICU ${process.versions.icu}, Unicode ${process.versions.unicode}`;
  writeGen(
    "src/text/font_faces_gen.mbt",
    `///|\npub let font_face_table : Array[FaceData] = [\n${rows.join("\n")}\n]\n\n///|\n/// Code point ranges (low, high) of the official containsCJK, as ${note}.\npub let cjk_ranges : Array[Int] = [${spans.join(", ")}]\n`,
  );
}
