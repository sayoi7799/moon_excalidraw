// Scenes for the font modes. The official @font-face rules depend on the
// families used and on which characters each family has to draw.
import { base, doc } from "./cases_single.mjs";
import { textEl } from "./cases_text.mjs";

const FAMILIES = [1, 2, 3, 5, 6, 7, 8, 9, 100, 1000, 4, 99];

export function fontScenes() {
  const cases = [];
  const add = (name, elements, fonts = "url") => cases.push({ name, scene: doc(elements), fonts });
  const t = (text, extra = {}) => textEl(text, extra);
  const at = (i, el) => ({ ...el, id: `t${i}`, y: 30 + i * 40 });

  add("none/no-text", [{ ...base, id: "r", type: "rectangle", x: 0, y: 0, width: 50, height: 50 }]);
  add("none/empty-text", [t("")]);
  for (const text of ["Hello", "Ünïcödé ÿ", "Привет мир", "Γειά σου", "Việt Nam", "Ą ę ł", "→ ∑ ≠", "  ", "a\tb", "ﬁ ligature", "ツ"]) {
    for (const fontFamily of FAMILIES) {
      add(`family/${fontFamily}/${[...text].map((c) => c.codePointAt(0).toString(16)).join("-")}`, [t(text, { fontFamily })]);
    }
  }
  // Excalifont draws CJK through Xiaolai.
  for (const text of ["你好", "こんにちは", "カタカナ", "한국어", "，。", "＄", "ー", "々", "你好 hello", "hello 世界 привет", "😀 你", "😀"]) {
    for (const fontFamily of [5, 6, 3]) {
      add(`cjk/${fontFamily}/${[...text].map((c) => c.codePointAt(0).toString(16)).join("-")}`, [t(text, { fontFamily })]);
    }
  }
  add("mixed/5-6-3", [at(0, t("Hello", { fontFamily: 5 })), at(1, t("Привет", { fontFamily: 6 })), at(2, t("code", { fontFamily: 3 }))]);
  add("mixed/6-then-5-cjk", [at(0, t("Привет", { fontFamily: 6 })), at(1, t("你好", { fontFamily: 5 }))]);
  add("mixed/5-twice", [at(0, t("abc", { fontFamily: 5 })), at(1, t("世界 xyz", { fontFamily: 5 }))]);
  add("mixed/5-cjk-and-100", [at(0, t("世界", { fontFamily: 5 })), at(1, t("字", { fontFamily: 100 }))]);
  add("mixed/100-then-5-cjk", [at(0, t("字", { fontFamily: 100 })), at(1, t("世界", { fontFamily: 5 }))]);
  add("mixed/all", FAMILIES.map((fontFamily, i) => at(i, t("Aé→", { fontFamily }))));
  add("mixed/same-family-different-chars", [at(0, t("abc", { fontFamily: 6 })), at(1, t("ñ ü", { fontFamily: 6 })), at(2, t("Привет", { fontFamily: 6 }))]);
  add("original-text/cjk", [t("x", { originalText: "世界", fontFamily: 5 })]);
  add("original-text/latin", [t("世界", { originalText: "x", fontFamily: 5 })]);
  add("empty/text-and-family", [at(0, t("", { fontFamily: 6 })), at(1, t("hi", { fontFamily: 3 }))]);
  add("frame/label-is-local", [{ ...base, id: "f", type: "frame", x: 0, y: 0, width: 200, height: 100, name: "Frame", backgroundColor: "transparent" }]);
  add("frame/label-and-text", [{ ...base, id: "f", type: "frame", x: 0, y: 0, width: 200, height: 100, name: "Frame", backgroundColor: "transparent" }, t("hi", { fontFamily: 5 })]);
  add("legacy-font", [t("a", { font: "24px Cascadia", fontSize: undefined, fontFamily: undefined, lineHeight: 1.2 })]);
  add("bound-text", [
    { ...base, id: "c", type: "rectangle", x: 10, y: 10, width: 200, height: 100, boundElements: [{ type: "text", id: "t" }] },
    t("世界", { containerId: "c", fontFamily: 5 }),
  ]);
  // The same scenes without fonts must stay empty.
  add("none/with-text", [t("你好 hello", { fontFamily: 5 })], "none");
  return cases;
}
