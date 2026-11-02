# moon_excalidraw MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 用 MoonBit 把 `.excalidraw` 文件渲染成和官方 `exportToSvg` 逐字节一致的 SVG，并提供命令行工具和对照 gallery。

**Architecture:** `model` 解析并规整文件，`shape` 生成 rough 图形和包围盒，`text` 处理字体和文字布局，`freehand` 生成笔迹，`svg` 负责序列化，`export` 编排全流程。所有预期值由锁定版本的官方包在 Node 中生成，内嵌为 `.mbt`。

**Tech Stack:** MoonBit（moon 0.1.20261016、moonc v0.10.16）、`sayoi7799/moon_rough`、Node 24、jsdom、esbuild。

**Spec:** `docs/superpowers/specs/2026-11-02-moon-excalidraw-design.md`

## Global Constraints

- 对照基准：`@excalidraw/excalidraw` 0.18.1、`perfect-freehand` 1.2.0、`roughjs` 4.6.4、`points-on-curve` 1.0.1。
- `moon test` 必须在 js、wasm-gc、native 三个后端通过。
- 每个小步骤跑 `moon check` 和 `moon test`，全部通过才继续，然后马上提交。
- 提交信息写清楚做了什么；不加 Co-Authored-By 署名；不做空提交；不为凑数拆分。
- 测试预期值不能手写，全部来自官方输出。自洽性断言（比如“返回错误”）除外。
- 不确定的 MoonBit 语法或标准库 API，查文档或写小测试验证。
- 每完成一个模块，用 3–5 句话向维护者解释核心逻辑。
- 推送、发布到 mooncakes、改动 moon_rough 的默认行为，都要先向维护者确认。
- 对照时不设数值容差。

**源码参考：** 按需把官方源码克隆到被 git 忽略的 `vendor/`：`git clone --filter=blob:none -b v0.18.1 https://github.com/excalidraw/excalidraw vendor/excalidraw`。下文路径相对于该仓库根。只参考规范和行为，用 MoonBit 重新实现。

## Review Focus

1. **非 BMP 字符和换行：** emoji 文字、截断时切到代理对中间的 frame 标题、`\r\n` 换行，都应和官方输出一致。测试放在 Task 9。
2. **图片引用不到文件：** `fileId` 在 `files` 里不存在时，和官方一样不绘制但计入画布，同时给出警告。测试放在 Task 10。
3. **类型错误的字段：** `elements` 不是数组、元素不是对象、`width` 是字符串、`points` 含非数字，以及文件开头带 UTF-8 BOM。前四种返回 `ParseError` 并指出元素 id，BOM 被跳过，都不能崩溃。测试放在 Task 5。
4. **规模：** 5000 个元素的场景和 10000 个点的 freedraw 要能在合理时间内完成，嵌套 100000 层的 JSON 要返回错误而不是栈溢出。测试放在 Task 12。
5. **退化几何：** 首尾点重合的箭头（方向向量是 NaN）、极小坐标（`1e-7`）和超大坐标（`1e21`）的数字格式，都要和官方一致。测试放在 Task 8 和 Task 4。

---

## 文件结构

```text
moon.mod                       模块定义，source = "src"
src/moon_excalidraw.mbt        根包，转出 parse_scene、export_to_svg 和相关类型
src/model/                     types.mbt、parse.mbt、restore.mbt、link.mbt
src/freehand/                  vec.mbt、stroke_points.mbt、outline.mbt、get_stroke.mbt
src/svg/                       node.mbt（序列化和转义）、number.mbt
src/text/                      fonts.mbt、layout.mbt、font_faces.mbt、font_faces_gen.mbt
src/shape/                     options.mbt、generate.mbt、arrowhead.mbt、bounds.mbt、linear.mbt、freedraw.mbt
src/export/                    export.mbt、render.mbt、frame.mbt、image.mbt、conformance_*_test.mbt
src/internal/jsnum/            hypot.mbt、atan2.mbt、pow.mbt
src/internal/conform/          diff.mbt、hex.mbt
src/internal/fixtures/         *_gen.mbt（脚本生成，不手改）
src/cmd/excalidraw2svg/        命令行工具
src/cmd/gallery/               生成对照页
scripts/                       package.json、package-lock.json、official_env.mjs、gen_fixtures.mjs、cases_*.mjs、browser_check.html、update_readme_stats.mjs
fixtures/scenes/*.excalidraw   编辑器画的真实场景，以及手写的旧版文件
vendor/                        moon_rough 工作副本和官方源码，被 git 忽略
```

## fixture 约定

`scripts/gen_fixtures.mjs` 输出 `src/internal/fixtures/*_gen.mbt`，每个文件不超过约 1 MB，超出就分片。`SceneCase` 定义在手写的 `src/internal/fixtures/types.mbt`：

```moonbit
pub(all) struct SceneCase {
  name : String
  input : String        // .excalidraw JSON
  fonts : String        // "none" 或 "url"
  expected : String?    // 官方 outerHTML；None 表示官方抛错
}
```

**官方端的调用固定如下：**
- 先过滤 `isDeleted`。
- appState 只传 `{ exportBackground, viewBackgroundColor }`。
- `fonts == "none"` 时传 `skipInliningFonts: true`。
- `fonts == "url"` 时让 `fetch` 抛错，得到回退 URL。
- `measureText` 打桩为 `[...text].length * 7`。

MoonBit 端的 `measure_text` 用同样的规则（按码点计数 × 7）。

---

### Task 1: 项目骨架和官方生成环境

**Files:**
- Create: `moon.mod`、`src/moon.pkg`、`src/moon_excalidraw.mbt`、`LICENSE`
- Create: `scripts/package.json`、`scripts/package-lock.json`、`scripts/official_env.mjs`、`scripts/browser_check.html`
- Create: `src/internal/conform/moon.pkg`、`src/internal/conform/hex.mbt`、`src/internal/conform/hex_test.mbt`
- Modify: `.gitignore`（加入 `vendor/`）

**Interfaces:**
- Produces: `official_env.mjs` 导出 `loadOfficial(): Promise<{ exportToSvg, setFetchFails(bool) }>` 和 `exportScene(sceneJson, { fonts }): Promise<string>`
- Produces: `pub fn hex_to_double(StringView) -> Double`

- [ ] **Step 1: 建模块。** `moon.mod` 写 `name = "sayoi7799/moon_excalidraw"`、`source = "src"`、`license = "MIT"`、`preferred_target = "js"`。根包先放一个空的公开占位函数。
- [ ] **Step 2: 锁定 Node 依赖。** `scripts/package.json` 精确固定 `@excalidraw/excalidraw@0.18.1`、`perfect-freehand@1.2.0`、`jsdom`、`esbuild`，并提交 lockfile。启动时断言 `roughjs` 解析到 4.6.4，否则退出。
- [ ] **Step 3: 写 `official_env.mjs`。** 打包参数：`--bundle --platform=browser --format=esm --loader:.woff2=dataurl --loader:.css=empty --define:process.env.NODE_ENV="production"`。打桩项见 Spec 的“对照基准”。参考 `D:\Temp\claude\D--moon-excalidraw\b4389c8f-e325-49a4-bb96-954345efc696\scratchpad\npm\probe\probe2.mjs`。
- [ ] **Step 4: 运行冒烟。** 用一个矩形场景调用 `exportScene`。预期输出以 `<svg version="1.1"` 开头，两次结果相同。
- [ ] **Step 5: Chromium 抽查。** `browser_check.html` 加载同一个 bundle，在 20 个覆盖全部元素类型的场景上调用 `exportToSvg`（不打桩 DOM）。用内置浏览器打开，把结果和 jsdom 输出比较。预期全部相同，frame 标题的测宽值用同一个桩。**有差异就停下向维护者报告。**
- [ ] **Step 6: JSON 精度验证。** 写测试 `json double parse matches V8`：Node 生成 10000 个随机 double 的 `JSON.stringify` 文本和位模式，MoonBit 用 `@json.parse` 读取后逐位比较，三个后端都跑。**不一致就停下报告。**
- [ ] **Step 7: 原生构建验证。** 运行 `moon build --target native`。记录结果；失败时按 Spec 让 CLI 先走 js 后端，native 构建放到 CI。
- [ ] **Step 8: 运行 `moon check` 和 `moon test --target all`。** 预期全部通过。
- [ ] **Step 9: 提交。** `git commit -m "Scaffold module and official fixture environment"`

### Task 2: moon_rough 的 4.6.4 兼容选项

在 `vendor/moon_rough`（完整克隆，分支 `compat-roughjs-464`）里完成。这个任务不提交到 moon_excalidraw 仓库。

**Files（moon_rough 仓库）:**
- Modify: `src/core/types.mbt`、`src/core/generator.mbt`、`src/core/renderer.mbt`、`src/hachure/` 中计算 gap 的代码
- Create: `scripts/gen_fixtures_464.mjs`、`src/core/compat_464_fixtures_test.mbt`

**Interfaces:**
- Produces: `Options::new(..., roughjs_464? : Bool)`，默认 false。`ResolvedOptions` 增加 `roughjs_464 : Bool`。

- [ ] **Step 1: 写失败的测试。** `scripts/gen_fixtures_464.mjs` 用 roughjs 4.6.4 生成：`strokeWidth` 1.3（`hachureGap` 5.2）的三种图案填充；3 点 `curve` 的三种图案填充；2 点 `curve` 带填充；单点 `curve`。测试 `roughjs 4.6.4 compat matches official` 逐项比较 ops。
- [ ] **Step 2: 运行确认失败。** 运行 `moon test -p sayoi7799/moon_rough/core`。预期新测试失败。
- [ ] **Step 3: 实现兼容分支。** 开启时：
  - `hachureGap` 不取整（`scan-line-hachure.js`）；
  - `curve` 的填充要求 `points.length >= 3`，且图案填充直接用 `curveToBezier(points)`（`generator.js`）；
  - `_curve` 在 `len === 2` 时用 `_doubleLine`（`renderer.js`）。

  差异细节见 `roughjs` 4.6.4 和 4.6.6 的 `bin/` diff。
- [ ] **Step 4: 运行全部测试。** 运行 `moon test --target all`。预期新旧 fixtures 全部通过，默认行为没有变化。
- [ ] **Step 5: 在 moon_rough 分支提交。** `git commit -m "Add roughjs 4.6.4 compatibility option"`
- [ ] **Step 6: 接入。** 让 moon_excalidraw 用路径依赖指向 `vendor/moon_rough`。路径依赖在 `moon.mod` 里的写法要查文档确认。moon_excalidraw 仓库提交 `moon.mod` 变更。

### Task 3: jsnum 数学函数

**Files:**
- Create: `src/internal/jsnum/moon.pkg`、`hypot.mbt`、`atan2.mbt`、`pow.mbt`、`jsnum_test.mbt`
- Create: `scripts/gen_fixtures.mjs`（从这个任务开始增量扩展）、`src/internal/fixtures/types.mbt`、`src/internal/fixtures/jsnum_gen.mbt`

**Interfaces:**
- Produces: `pub fn hypot(Double, Double) -> Double`、`pub fn atan2(Double, Double) -> Double`、`pub fn pow(Double, Double) -> Double`

- [ ] **Step 1: 生成 fixtures。** 每个函数 5000 组输入和输出（位模式），覆盖随机值、0、负零、NaN、Infinity、极大极小值。`pow` 重点覆盖指数 2 和 3。
- [ ] **Step 2: 写失败的测试。** `hypot matches V8`、`atan2 matches V8`、`pow matches V8`，都逐位比较。
- [ ] **Step 3: 实现。** `hypot` 按 V8 算法：取绝对值的最大值作缩放因子，对平方做 Kahan 求和，结果是 `sqrt(sum) * max`。`atan2` 和 `pow` 用 fdlibm 算法移植，不调用后端 C 库。
- [ ] **Step 4: 运行 `moon test --target all`。** 预期三个后端逐位一致，失败数为 0。
- [ ] **Step 5: 提交。** `git commit -m "Add V8-compatible hypot, atan2 and pow"`

### Task 4: perfect-freehand

**Files:**
- Create: `src/freehand/moon.pkg`、`vec.mbt`、`stroke_points.mbt`、`outline.mbt`、`get_stroke.mbt`、`freehand_test.mbt`
- Create: `scripts/cases_freehand.mjs`、`src/internal/fixtures/freehand_gen.mbt`

**Interfaces:**
- Consumes: `@jsnum.hypot`、`@jsnum.pow`、`@jsmath.sin`、`@jsmath.cos`
- Produces:

```moonbit
pub(all) struct StrokeOptions {
  size : Double; thinning : Double; smoothing : Double; streamline : Double
  simulate_pressure : Bool; last : Bool
  easing : (Double) -> Double
  start : TaperOptions; end : TaperOptions
}
pub fn get_stroke(points : Array[(Double, Double, Double?)], options : StrokeOptions) -> Array[(Double, Double)]
pub fn excalidraw_options(stroke_width : Double, simulate_pressure : Bool, last : Bool) -> StrokeOptions
```

`excalidraw_options` 的取值：`size = stroke_width * 4.25`、`thinning = 0.6`、`smoothing = 0.5`、`streamline = 0.5`、`easing = t => sin(t * PI / 2)`。

- [ ] **Step 1: 生成 fixtures。** 300 组以上：随机点序列（1、2、3、10、500 个点；有无 pressure）× 多组 size、thinning、smoothing、streamline、last、taper 组合，再加 Excalidraw 自己的参数。种子固定。输出全部用位模式。外加重合点序列和含 `1e-7` 的序列。上游源码用 npm 包 `perfect-freehand@1.2.0` 的 `dist/esm/index.js` 做权威。
- [ ] **Step 2: 写失败的测试。** `get_stroke matches perfect-freehand 1.2.0`：数量相同且每个 double 位模式相同。
- [ ] **Step 3: 实现。** 按 `getStrokePoints`、`getStrokeRadius`、`getStrokeOutlinePoints`、`getStroke` 的结构拆文件。
- [ ] **Step 4: 运行 `moon test --target all`。** 预期差异数为 0。
- [ ] **Step 5: 提交，并向维护者解释 freehand 模块。** `git commit -m "Port perfect-freehand getStroke"`

### Task 5: model 解析和 restore

**Files:**
- Create: `src/model/moon.pkg`、`types.mbt`、`parse.mbt`、`restore.mbt`、`link.mbt`、`model_test.mbt`
- Create: `scripts/cases_restore.mjs`、`src/internal/fixtures/restore_gen.mbt`
- Modify: `src/moon_excalidraw.mbt`（转出 `parse_scene` 和类型）

**Interfaces:**
- Produces:

```moonbit
pub(all) struct Roundness { kind : Int; value : Double? }
pub(all) struct BoundElement { id : String; kind : String }
pub(all) struct Linear {
  points : Array[(Double, Double)]
  start_arrowhead : String?; end_arrowhead : String?
  elbowed : Bool
}
pub(all) struct FreeDraw { points : Array[(Double, Double)]; pressures : Array[Double]; simulate_pressure : Bool }
pub(all) struct TextData {
  text : String; original_text : String; font_size : Double; font_family : Int
  text_align : String; vertical_align : String; container_id : String?; line_height : Double
}
pub(all) struct Crop { x : Double; y : Double; width : Double; height : Double; natural_width : Double; natural_height : Double }
pub(all) struct ImageData { file_id : String?; scale : (Double, Double); crop : Crop? }
pub(all) enum Kind {
  Rectangle; Diamond; Ellipse; Line(Linear); Arrow(Linear); Freedraw(FreeDraw)
  Text(TextData); Image(ImageData); Frame(String?); MagicFrame(String?); Unsupported(String)
}
pub(all) struct Element {
  id : String; kind : Kind; x : Double; y : Double; width : Double; height : Double
  angle : Double; stroke_color : String; background_color : String; fill_style : String
  stroke_width : Double; stroke_style : String; roughness : Double; opacity : Double
  seed : Int; roundness : Roundness?; bound_elements : Array[BoundElement]
  frame_id : String?; link : String?; is_deleted : Bool
}
pub(all) struct FileData { id : String; mime_type : String; data_url : String }
pub(all) struct Scene { elements : Array[Element]; export_background : Bool; view_background_color : String; files : Map[String, FileData] }
pub suberror ParseError { InvalidJson(String); NotAScene(String); InvalidElement(String, String) }
pub fn parse_scene(StringView) -> Scene raise ParseError
pub fn normalize_link(String) -> String
```

- [ ] **Step 1: 生成 fixtures。** Node 脚本调用官方 `restoreElements(elements, null)`，把规整后的关键字段输出为 JSON 作为预期值。覆盖：缺字段矩形；`strokeSharpness`；`boundElementIds`；`font: "24px Cascadia"`；没有 `lineHeight` 的文字；空文字；`type: "draw"`；首点非零的 line；负宽高；单点 arrow；`link` 的 `javascript:`、带引号、空格。
- [ ] **Step 2: 写失败的测试。** `restore matches official` 逐字段比较，再加这些断言：

```moonbit
test "invalid json raises" { assert_true(try? parse_scene("{oops") is Err(InvalidJson(_))) }
test "elements not array raises" { assert_true(try? parse_scene("{\"elements\":1}") is Err(NotAScene(_))) }
test "wrong field type names element" {
  let r = try? parse_scene("{\"elements\":[{\"id\":\"e\",\"type\":\"rectangle\",\"width\":\"x\"}]}")
  assert_true(r is Err(InvalidElement("e", _)))
}
test "arrow without points raises" {
  let r = try? parse_scene("{\"elements\":[{\"id\":\"a\",\"type\":\"arrow\",\"x\":0,\"y\":0}]}")
  assert_true(r is Err(InvalidElement("a", _)))
}
test "utf8 bom skipped" { assert_true(try? parse_scene("\u{FEFF}{\"elements\":[]}") is Ok(_)) }
test "unknown fields tolerated" { assert_true(try? parse_scene("{\"elements\":[],\"wat\":1}") is Ok(_)) }
```

- [ ] **Step 3: 实现。**
  - restore 规则按 `packages/excalidraw/data/restore.ts`，默认值按 `constants.ts` 的 `DEFAULT_ELEMENT_PROPS`。
  - `normalize_link` 移植 `data/url.ts` 和 `@braintree/sanitize-url` 6.0.2 的行为。
  - 重复 id 的元素保留并在 `export` 给警告。
  - `elbowed: true` 保留数据，由 `export` 判定为不支持。
  - `selection` 被丢弃。
  - 未知类型映射到 `Unsupported`。
- [ ] **Step 4: 运行 `moon test --target all`。** 预期全部通过。
- [ ] **Step 5: 提交，并向维护者解释 model 模块。** `git commit -m "Parse scenes and apply restore rules"`

### Task 6: svg 序列化和差异工具

**Files:**
- Create: `src/svg/moon.pkg`、`node.mbt`、`number.mbt`、`svg_test.mbt`
- Create: `src/internal/conform/diff.mbt`、`diff_test.mbt`

**Interfaces:**
- Produces:

```moonbit
pub struct Node
pub fn Node::element(String) -> Node
pub fn Node::set(Self, String, String) -> Unit      // 保持插入顺序，重复设置时原位覆盖
pub fn Node::append(Self, Node) -> Unit
pub fn Node::prepend(Self, Node) -> Unit
pub fn Node::text(String) -> Node
pub fn Node::comment(String) -> Node
pub fn Node::to_html(Self) -> String
pub fn num(Double) -> String   // JS 的 String(number)，包装 @jsmath.number_to_string

pub enum DiffKind { Identical; Structural; Attribute; Numeric(Double) }
pub fn classify(actual : String, expected : String) -> DiffKind
pub(all) struct Stats { total : Int; identical : Int; failed : Int; structural : Int; attribute : Int; numeric : Int; max_delta : Double }
// render 返回 None 表示本库返回错误；expected 也为 None 时算一致
pub fn run(Array[@fixtures.SceneCase], (@fixtures.SceneCase) -> String?) -> Stats
```

- [ ] **Step 1: 写失败的测试。** 预期值从 Node 生成一小份 fixture，覆盖：文本里的 `&`、`<`、`>`、U+00A0（转成 `&nbsp;`）、`"` 不转义；属性里的 `&`、`"`、U+00A0；`<style>` 内的文本不转义（HTML 序列化规则）；注释；空元素写成 `<path></path>`。再加 `classify` 对相同、结构不同、属性不同、数值不同（返回最大偏差）四种情况的断言。
- [ ] **Step 2: 确认失败。** 运行 `moon test -p sayoi7799/moon_excalidraw/svg`。预期因为函数未定义而失败。
- [ ] **Step 3: 实现。** 输出用 `StringBuilder`。这个 HTML 序列化形式要和 `outerHTML` 一致，不走 XML 规则。
- [ ] **Step 4: 运行 `moon test --target all`。** 预期全部通过。
- [ ] **Step 5: 提交。** `git commit -m "Add outerHTML-compatible SVG writer and diff classifier"`

### Task 7: 基础图形的第一条完整链路

打通矩形、菱形、椭圆从输入到完整 SVG 的路径。

**Files:**
- Create: `src/shape/moon.pkg`、`options.mbt`、`generate.mbt`、`bounds.mbt`
- Create: `src/export/moon.pkg`、`export.mbt`、`render.mbt`、`conformance_single_test.mbt`
- Create: `scripts/cases_single.mjs`、`src/internal/fixtures/single_gen_*.mbt`
- Modify: `src/moon_excalidraw.mbt`

**Interfaces:**
- Consumes: `Scene`、`Element`（Task 5），`Node`、`num`（Task 6）
- Produces:

```moonbit
// shape
pub fn rough_options(Element, continuous_path? : Bool) -> @moon_rough.Options
pub fn generate(Element, canvas_background : String) -> Array[@moon_rough.Drawable]
pub fn element_bounds(Element, Map[String, Element]) -> (Double, Double, Double, Double)
pub fn absolute_coords(Element, Map[String, Element]) -> (Double, Double, Double, Double, Double, Double)
pub fn common_bounds(Array[Element], Map[String, Element]) -> (Double, Double, Double, Double)

// export
pub enum FontMode { Url; None }
pub enum UnsupportedPolicy { Error; SkipWithWarning }
pub(all) struct Warning { element_id : String?; message : String }
pub(all) struct ExportResult { svg : String; warnings : Array[Warning] }
pub suberror ExportError { Unsupported(String, String) }
pub fn export_to_svg(
  @model.Scene,
  fonts? : FontMode = Url,
  on_unsupported? : UnsupportedPolicy = SkipWithWarning,
  measure_text? : (String, String) -> Double,
) -> ExportResult raise ExportError
```

- [ ] **Step 1: 生成 fixtures。** 三种图形 × 四种 fillStyle × 三种 strokeStyle × roughness 0、1、2 × strokeWidth 1、2、4 × 圆角（3 种 roundness，椭圆除外）做成对覆盖；UI 常用值（strokeWidth 1、2、4，roughness 0、1、2，hachure 和 solid）做全组合；再加旋转、opacity、透明背景、小尺寸（触发 `adjustRoughness`）、`strokeWidth` 1.3。全部 `fonts: "none"`。
- [ ] **Step 2: 写失败的测试。**

```moonbit
test "single basic shapes match official" {
  // render 是本测试文件里的辅助函数：解析 c.input，注入 7 × 码点数的 measure_text，再调 export_to_svg
  let stats = @conform.run(@fixtures.single_basic, render)
  println("[conformance] " + stats.to_string())
  assert_eq(stats.failed, 0)
}
```

- [ ] **Step 3: 实现。**
  - 所有 rough 调用都开启 `roughjs_464`，生成 SVG 时用 `ops_to_path(set, fixed_decimals=2)`。
  - 按 `Shape.ts` 实现 `generateRoughOptions` 和 `_generateElementShape`。
  - 按 `staticSvgScene.ts` 写节点，属性顺序不能变。
  - `RoughSVG.draw` 的属性写法见 `roughjs/bin/svg.js`（`fillPath` 在 curve 和 polygon 上带 `fill-rule="evenodd"`）。
  - 根节点顺序按 `scene/export.ts`：注释、metadata、defs、背景。
- [ ] **Step 4: 运行 `moon test --target all`。** 预期 `failed` 为 0。
- [ ] **Step 5: 提交，并向维护者解释 shape 和 export 骨架。** `git commit -m "Render rectangles, diamonds and ellipses identically to official export"`

### Task 8: line、arrow 和箭头头部

**Files:**
- Create: `src/shape/arrowhead.mbt`、`src/shape/linear.mbt`、`scripts/cases_linear.mjs`、`src/internal/fixtures/linear_gen_*.mbt`
- Modify: `src/shape/generate.mbt`、`src/shape/bounds.mbt`、`src/export/render.mbt`、`src/export/conformance_single_test.mbt`

**Interfaces:**
- Produces:

```moonbit
pub fn arrowhead_points(Element, Array[@moon_rough.Drawable], String, String) -> Array[Double]?
pub fn bound_text_position(Element, Element, Map[String, Element]) -> (Double, Double)
pub fn is_path_a_loop(Array[(Double, Double)]) -> Bool
```

- [ ] **Step 1: 生成 fixtures。** line 和 arrow × 尖角和圆角 × 2、3、4、5 点 × 全部 13 种箭头样式组合（`arrow`、`bar`、`dot`、`circle`、`circle_outline`、`triangle`、`triangle_outline`、`diamond`、`diamond_outline`、`crowfoot_one`、`crowfoot_many`、`crowfoot_one_or_many` 和 `null`，起点和终点都测）× strokeStyle × 闭合填充。再加旋转、3 点闭合图案填充、**首尾点重合的箭头**、线段极短的箭头。
- [ ] **Step 2: 写失败的测试。** `single linear match official`，断言同 Task 7。
- [ ] **Step 3: 实现。**
  - 箭头头部按 `getArrowheadPoints`（`element/bounds.ts:572`）和 `getArrowheadShapes`（`Shape.ts:156`）。
  - **`options` 必须按共享可变语义传递**，起点箭头的修改要带到终点。
  - 曲线包围盒按 `getMinMaxXYFromCurvePathOps`、`getCubicBezierCurveBound`。
  - 中点按 `LinearElementEditor.getSegmentMidPoint`、`getBoundTextElementPosition`，贝塞尔长度和插值都用 `@jsnum`。
  - 带绑定文字时画 mask，属性按 `staticSvgScene.ts:276`。
- [ ] **Step 4: 运行 `moon test --target all`。** 预期 `failed` 为 0。
- [ ] **Step 5: 提交。** `git commit -m "Render lines, arrows and arrowheads"`

### Task 9: 文字

**Files:**
- Create: `src/text/moon.pkg`、`fonts.mbt`、`layout.mbt`、`scripts/cases_text.mjs`、`src/internal/fixtures/text_gen.mbt`
- Modify: `src/export/render.mbt`、`src/export/conformance_single_test.mbt`

**Interfaces:**
- Produces:

```moonbit
pub fn font_family_string(Int) -> String
pub fn vertical_offset(font_family : Int, font_size : Double, line_height_px : Double) -> Double
pub fn split_lines(String) -> Array[String]
pub fn is_rtl(String) -> Bool
```

- [ ] **Step 1: 生成 fixtures。** 全部字体编号（1、2、3、5、6、7、8、9 和未知值）× 对齐方式 × 单行和多行；旋转、透明度；矩形和菱形内的绑定文字；箭头绑定文字（2、3、4 点，尖角和圆角）；没有反向记录的绑定；RTL 和数字开头的 RTL；中文、**emoji**、**`\r\n`**、`&<>` 和 U+00A0；缺 `lineHeight`；空文字计入包围盒。
- [ ] **Step 2: 写失败的测试。** `single text match official`，断言同 Task 7。
- [ ] **Step 3: 实现。** 字体度量表取自 `fonts/FontMetadata.ts`。主循环的绑定文字跳过和紧随输出按 `renderSceneToSvg`。RTL 判定移植 `utils.ts` 的 `RE_RTL_CHECK`，不引入正则库。
- [ ] **Step 4: 运行 `moon test --target all`。** 预期 `failed` 为 0。
- [ ] **Step 5: 提交，并向维护者解释 text 模块。** `git commit -m "Render text and bound text"`

### Task 10: freedraw、image、frame、link

**Files:**
- Create: `src/shape/freedraw.mbt`、`src/export/frame.mbt`、`src/export/image.mbt`、`scripts/cases_misc.mjs`、`src/internal/fixtures/misc_gen.mbt`
- Modify: `src/shape/generate.mbt`、`src/export/render.mbt`、`src/export/export.mbt`、`src/export/conformance_single_test.mbt`

**Interfaces:**
- Produces: `pub fn freedraw_path(Element) -> String`、`pub fn trim_path_decimals(String) -> String`
- Consumes: `get_stroke`、`excalidraw_options`（Task 4）；`simplify` 来自 `sayoi7799/moon_rough/curve`

- [ ] **Step 1: 生成 fixtures。**
  - freedraw：模拟压力和真实压力；开放和闭合（带填充）；极短笔迹。
  - image：有无圆角、裁剪、翻转 scale、复用同一文件；**`fileId` 找不到文件**。
  - frame：有无成员、超出部分被裁剪、成员不计入包围盒、**长标题截断（含 emoji）**、frame 的 opacity、旋转的 frame。
  - 其他：`link` 包裹 `<a>`。
- [ ] **Step 2: 写失败的测试。** `single misc match official`，断言同 Task 7，再加：

```moonbit
test "missing image file warns" {
  let r = export_to_svg(@model.parse_scene(MISSING_FILE_SCENE), fonts=None)
  assert_true(r.warnings.iter().any(fn(w) { w.element_id == Some("img") }))
}
```

- [ ] **Step 3: 实现。**
  - `trim_path_decimals` 手写扫描器，语义等于 `/(\s?[A-Z]?,?-?[0-9]*\.[0-9]{0,2})(([0-9]|e|-)*)/g` 替换成 `$1`。用针对这个正则的 fixture 验证，包括 `1e-7` 这种数字。
  - `simplify` 的距离是 0.75。
  - frame 标题的默认 `measure_text` 按每个字符 `0.5 × fontSize` 估算。
  - 截断的 `slice` 按 UTF-16 码元切。
  - 裁剪路径的 `rotate` 直接写弧度值。
  - frame 的 `FRAME_STYLE` 见 `constants.ts`。
  - 图片的 `symbol` 按 `prepend` 进 `defs`。
- [ ] **Step 4: 运行 `moon test --target all`。** 预期 `failed` 为 0。
- [ ] **Step 5: 提交。** `git commit -m "Render freedraw, images, frames and links"`

### Task 11: 字体模式

**Files:**
- Create: `src/text/font_faces.mbt`、`src/text/font_faces_gen.mbt`、`scripts/gen_font_faces.mjs`、`scripts/cases_fonts.mjs`、`src/internal/fixtures/fonts_gen.mbt`
- Modify: `src/export/export.mbt`、`src/export/conformance_single_test.mbt`

**Interfaces:**
- Produces: `pub fn font_face_declarations(Array[@model.Element]) -> Array[String]`

- [ ] **Step 1: 查清 Cascadia 的问题。** 用官方环境打印 `Fonts.registered` 里各字体的 URL 和 unicode-range，弄清为什么 Nunito、Cascadia、Helvetica 混排时只输出 Nunito。把结论写进提交信息。如果原因是打包方式（比如 woff2 被 esbuild 内联）造成的假象，就先修正 `official_env.mjs` 再继续。
- [ ] **Step 2: 生成字体分片表。** `gen_font_faces.mjs` 从官方数据导出每个 family 的 `{url, unicode_range}` 到 `font_faces_gen.mbt`。
- [ ] **Step 3: 生成 fixtures。** 每种字体的拉丁文字；Excalifont 的中文（触发 Xiaolai）；多种字体混排；只有 Helvetica；无文字场景。全部 `fonts: "url"`。
- [ ] **Step 4: 写失败的测试。** `font url mode matches official fallback`，比较整份 SVG；再加 `font none mode has empty style block`。
- [ ] **Step 5: 实现。** family 顺序、CJK 回退放最前、去重、按 unicode-range 筛选，按 `Fonts.generateFontFaceDeclarations` 和 `ExcalidrawFontFace.toCSS`。字符集取自 `originalText`。
- [ ] **Step 6: 运行 `moon test --target all`。** 预期 `failed` 为 0。
- [ ] **Step 7: 提交。** `git commit -m "Add URL and none font modes"`

### Task 12: 组合场景、边界情况和差异统计

**Files:**
- Create: `fixtures/scenes/*.excalidraw`、`fixtures/scenes/SOURCES.md`、`scripts/cases_combo.mjs`、`scripts/cases_edge.mjs`、`src/internal/fixtures/combo_gen_*.mbt`、`src/internal/fixtures/edge_gen.mbt`
- Create: `src/export/conformance_combo_test.mbt`、`src/export/conformance_edge_test.mbt`、`src/export/scale_test.mbt`

- [ ] **Step 1: 收集真实场景。** 用内置浏览器在 excalidraw.com 上画约 10 张（流程图、架构图、带文字的箭头、旋转、透明度、分组、frame），导出 JSON 存到 `fixtures/scenes/`。来源、日期写进 `SOURCES.md`。这些文件的预期值同样由 0.18.1 生成，因为线上编辑器是 master 版本，可能带新字段。
- [ ] **Step 2: 生成至少 40 个程序化组合场景。** 用官方 `convertToExcalidrawElements` 或固定种子构造，总数不少于 50。名称标注 `real/` 或 `generated/`。
- [ ] **Step 3: 生成边界 fixtures。** 空场景、只有已删除元素、宽高为 0（单边和双边）、超大坐标（`1e21`、`-1e15`）、缺字段的旧文件、已删除 frame 的成员。`expected` 为 None 的用例断言本库返回错误。非法 JSON 和不支持类型单独写断言：

```moonbit
test "unsupported strict raises" {
  let s = @model.parse_scene(EMBEDDABLE_SCENE)
  assert_true(try? export_to_svg(s, on_unsupported=Error) is Err(Unsupported(_, _)))
}
test "unsupported skip warns and excludes from bounds" {
  let r = export_to_svg(@model.parse_scene(EMBEDDABLE_SCENE), fonts=None)
  assert_eq(r.warnings.length(), 1)
}
test "seed zero warns" {
  let r = export_to_svg(@model.parse_scene(SEED_ZERO_SCENE), fonts=None)
  assert_true(r.warnings.iter().any(fn(w) { w.element_id == Some("r") }))
}
```

- [ ] **Step 4: 写规模测试。** `scale 5000 rectangles`、`scale 10000 point freedraw` 能完成并输出；`deeply nested json raises` 对 100000 层嵌套返回 `InvalidJson` 而不崩溃。三个后端都跑。如果 `@json.parse` 无法保证不溢出，就先加一层深度预检查。
- [ ] **Step 5: 运行 `moon test --target all`。** 预期全部通过。对失败用例逐个定位，不许把用例标记为跳过。真正无法对照的情况要加入 Spec 的“不可对照项”，并告知维护者。
- [ ] **Step 6: 输出差异统计。** `@conform.run` 打印 `[conformance] suite=... total=... identical=... structural=... attribute=... numeric=... max_delta=...`。`scripts/update_readme_stats.mjs` 从 `moon test` 输出生成 README 的统计表。
- [ ] **Step 7: 提交。** `git commit -m "Add combined and edge-case conformance suites"`

### Task 13: 命令行工具和 gallery

**Files:**
- Create: `src/cmd/excalidraw2svg/moon.pkg`、`main.mbt`、`args.mbt`、`args_test.mbt`
- Create: `src/cmd/gallery/moon.pkg`、`main.mbt`

**Interfaces:**
- Produces: `excalidraw2svg <input> [-o <output>] [--no-fonts] [--strict]`。不带 `-o` 时输出到 stdout，警告写 stderr。

- [ ] **Step 1: 写失败的测试。** 参数解析是纯函数：`parse_args` 覆盖正常用法、缺输入、未知参数。这些测试三个后端都跑。
- [ ] **Step 2: 实现。** 文件读写的可选依赖是 `moonbitlang/x/fs`，这两个 `cmd` 包只在 js 和 native 上构建（`moon.pkg` 的限定写法查文档）。
- [ ] **Step 3: 手动验收。** 运行下面的命令，把输出和 `fixtures` 里的官方 SVG 比较：

```bash
moon run --target js src/cmd/excalidraw2svg -- fixtures/scenes/flowchart.excalidraw --no-fonts
```

  文件不存在、非法 JSON、`--strict` 遇到 embeddable 这三种情况都要退出码非零并输出可读信息。
- [ ] **Step 4: 实现 gallery。** 从 fixtures 生成单文件 HTML，每个场景并排放本库和官方的结果，并标明是否一致。SVG 用百分号编码的 `<img src="data:image/svg+xml,...">` 放置，避免页面内的 id 冲突。输出到 `gallery/index.html`。
- [ ] **Step 5: 在浏览器里看一遍。** 用内置浏览器打开 `gallery/index.html`，确认图片都能显示，没有全部“不一致”这类异常。
- [ ] **Step 6: 提交。** `git commit -m "Add excalidraw2svg CLI and comparison gallery"`

### Task 14: README、CI 和发布准备

**Files:**
- Create: `README.md`、`CHANGELOG.md`、`THIRD_PARTY_LICENSES`、`.github/workflows/ci.yml`
- Modify: `moon.mod`

- [ ] **Step 1: 写 README。** 包含：定位；和 moon_rough、moonlight 的关系（也提 papyr）；支持范围表；和官方的差异（Spec 的“有意差异”和“不可对照项”）；差异统计；重新生成 fixtures 的命令和版本号；参考来源和许可证。
- [ ] **Step 2: 写版权声明。** `THIRD_PARTY_LICENSES` 保留 excalidraw、perfect-freehand、`@braintree/sanitize-url` 的版权和 MIT 全文。
- [ ] **Step 3: 写 CI。** `moon check`、`moon test --target all`、`moon fmt --check`、`moon build`，以及 lockfile 下重新生成 fixtures 后 `git diff --exit-code`。
- [ ] **Step 4: 严格检查。** 运行 `moon check --deny-warn`、`moon fmt`、`moon info`，修复问题。统计有效 MoonBit 代码行数（不含生成文件），和活动说明的 4000–10000 行参考值比较后告知维护者。
- [ ] **Step 5: 提交。** `git commit -m "Add README, licenses and CI"`
- [ ] **Step 6: 请维护者确认发布。** 依次确认：推送并发布 moon_rough 新版；把依赖切到版本号；推送 moon_excalidraw；运行 `moon publish`。每一项都单独确认，切换依赖后再跑一遍 `moon test --target all` 并提交。
