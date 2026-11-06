# moon_excalidraw

用 MoonBit 读取 `.excalidraw` 文件，**不需要浏览器**，输出和 Excalidraw 官方 `exportToSvg` 逐字节一致的 SVG。

Excalidraw 是最流行的手绘风格白板，`.excalidraw` 文件是 JSON：每个元素记录位置、尺寸、颜色、填充样式、粗糙度和 seed，官方导出 SVG 时用 rough.js 画出手绘效果。本项目把这条导出流程用 MoonBit 重新实现，对照基准是 `@excalidraw/excalidraw` 0.18.1。

```text
$ excalidraw2svg diagram.excalidraw -o diagram.svg
```

> English: a MoonBit renderer for Excalidraw files. It reads `.excalidraw` JSON and writes the same SVG as Excalidraw 0.18.1's `exportToSvg`, byte for byte, without a browser. All expected outputs come from the pinned official package.

## 和其他项目的关系

| 项目 | 做什么 | 和本项目的关系 |
|---|---|---|
| [moon_rough](https://github.com/sayoi7799/moon_rough) | rough.js 4.6.6 的逐位一致移植 | **本项目依赖它**画所有手绘图形。Excalidraw 用的是 rough.js 4.6.4，所以在 moon_rough 里加了 `roughjs_464` 选项（默认关闭，不影响原有行为） |
| [mizchi/moonlight](https://github.com/mizchi/moonlight) | 一个“像 Excalidraw”的编辑器 | 用自己的数据模型，不读写 `.excalidraw` 格式；本项目只渲染官方格式，不做编辑 |
| [f4ah6o/papyr](https://github.com/f4ah6o/papyr) | 把 Excalidraw 数据当 JSON 原样放进 Markdown | 不渲染；本项目可以给它提供渲染 |
| perfect-freehand | Excalidraw 手绘笔迹的算法 | MoonBit 里原先没有实现，本项目移植了 `getStroke` |

rough 以外的部分都是新增的：元素模型、各类元素的图形生成规则、箭头和箭头样式、文字、手绘笔迹、分组和 frame、导出布局、SVG 序列化。

## 使用

命令行：

```bash
moon run --target js src/cmd/excalidraw2svg -- diagram.excalidraw -o diagram.svg
```

```text
excalidraw2svg <input.excalidraw> [options]
  -o, --output <file>  把 SVG 写到文件，而不是打印
  --no-fonts           SVG 里不带字体规则
  --strict             遇到画不了的元素就报错，而不是跳过
  -h, --help
```

跳过的元素和其他“和官方结果不会一致”的情况会作为 warning 打印到 stderr；出错时退出码非零。在 Windows 的 native 版本上，stdout 是文本模式，换行会变成 `\r\n`；要得到逐字节一致的文件请用 `-o`（js 和 native 写出的文件完全相同）。

作为库使用：

```moonbit
let scene = @moon_excalidraw.parse_scene(text) // 非法 JSON、坏字段会 raise ParseError
let result = @moon_excalidraw.export_to_svg(
  scene,
  fonts=None,                  // Url（默认）或 None
  on_unsupported=SkipWithWarning, // 或 Error
)
println(result.svg)
for w in result.warnings {
  println(w.message)
}
```

对比页：`moon run --target js src/cmd/gallery -- gallery/index.html`，每个场景并排放本库和官方的输出（仓库里的 [gallery/index.html](gallery/index.html) 已经生成好，290 个场景）。图片里的文字用浏览器的回退字体，因为 `<img>` 里的 SVG 不能加载外部字体。

### 把一个文件夹的图变成网页

```bash
moon run --target js src/cmd/excalidraw2site -- examples/site/diagrams -o examples/site/dist --title "我的图"
```

读取文件夹里所有 `.excalidraw` 文件，生成 `index.html`、每张图的 SVG 和源文件副本。某张图渲染失败时其余照常生成，命令以非零码退出。怎么接到 GitHub Pages 或 CI，让图在每次提交时自动更新：见 [examples/site](examples/site/README.md)（里面有可直接复制的工作流）。

## 支持范围

| 内容 | 状态 |
|---|---|
| 元素：rectangle、diamond、ellipse（含圆角） | 支持 |
| 元素：line、arrow（直线、曲线、12 种箭头样式） | 支持 |
| 元素：freedraw（含闭合后的填充） | 支持 |
| 元素：text（含绑定在矩形、菱形、椭圆、箭头里的文字）、image（含裁剪、翻转、圆角）、frame、magicframe | 支持 |
| 样式：strokeColor、backgroundColor、fillStyle（hachure、cross-hatch、solid、zigzag）、strokeWidth、strokeStyle、roughness、opacity、angle、seed、link | 支持 |
| 导出：画布大小、10px padding、背景色、元素顺序、frame 裁剪和标题、`<a>` 链接 | 支持 |
| 字体：`FontMode::Url`（官方取不到字体时的 `@font-face` URL 形式）、`FontMode::None`（对应 `skipInliningFonts`） | 支持 |
| 容错：`isDeleted`、缺字段的旧文件（`strokeSharpness`、`font`、`boundElementIds`、`draw` 等）、未知字段 | 支持 |
| embeddable、iframe、肘形箭头（elbowed）、未知元素类型 | 报错或跳过并警告，由调用方选择，**不会静默画错** |
| 编辑和交互、PNG、协作、`.excalidrawlib`、Obsidian 压缩格式、深色模式、`exportEmbedScene`、导出单个 frame、字体子集化 | 不做 |

## 和官方结果的差异

下面这些是**有意的**，或者官方自己不确定：

| 情况 | 官方 | 本库 |
|---|---|---|
| 字体 | 内联子集化后的 base64 字体 | 只能是 URL 引用或不带字体。逐字节对照的是官方“取不到字体”时的输出 |
| embeddable、iframe、肘形箭头 | 画占位框或肘形线 | 报错或跳过并警告；跳过的元素也不计入画布大小 |
| 未知元素类型 | 静默丢弃 | 同样不画，但给出警告 |
| 缺 `points` 的 line/arrow、缺 `pressures` 又没开 `simulatePressure` 的 freedraw | 抛 TypeError，或画到一半静默丢掉这个元素 | 整个文件返回 `ParseError` 并指出元素 id |
| `seed: 0` | 用 `Math.random`，每次结果不同 | 用 moon_rough 的固定回退序列，并给出警告 |
| 重复的元素 id | 随机生成新 id | 保留，并给出警告 |
| frame 标题的宽度 | 用浏览器 canvas 测量 | 默认按每个字符 `0.5 × 字号` 估算，调用方可以传入 `measure_text`。只影响过长标题在哪里被截断 |
| 标题截断时把一个代理对切成两半 | 字符串里留下孤立代理项，保存成文件后是 U+FFFD | 直接输出 U+FFFD |
| `Math.pow(x, 3)`（箭头标签位置用到） | V8 调用平台的 C 库，最后一位随平台变化 | 用正确舍入的立方；每次调用约有 0.04% 的概率和某个平台差最后一位 |
| 画布里有一个 `1e12` 宽的 hachure 填充矩形 | 内存耗尽（要画几十亿条线） | 同样的问题，没有额外保护 |

`FontMode::Url` 依赖官方包里的字体表（230 个字体文件及其 unicode-range）和 `containsCJK` 的字符集，字符集随生成 fixtures 的 Node 的 Unicode 版本而定。

## 对照结果

预期值全部来自官方包，由 `scripts/gen_fixtures.mjs` 生成，不是手写的。`moon test` 对每个场景比较整份 SVG 字符串，不设数值容差；下面的表由 `scripts/update_readme_stats.mjs` 根据测试输出生成。

<!-- stats:begin -->
| Suite | What it covers | Scenes | Byte-identical | Different |
|---|---|---:|---:|---:|
| single basic | Rectangles, diamonds, ellipses × fill, stroke, roughness, roundness | 252 | 252 | 0 |
| single linear | Lines, arrows, closed fills, all arrowhead styles | 341 | 341 | 0 |
| single text | Text: every font id, alignment, direction, bound to shapes and arrows | 200 | 200 | 0 |
| single misc | Freedraw, images, frames, links | 78 | 78 | 0 |
| fonts | Font rules (`FontMode::Url`) for each family and character set | 185 | 185 | 0 |
| combined | Diagrams (editor API, hand-made, random, and 3 drawn in the real editor) | 55 | 55 | 0 |
| edge cases | Empty and degenerate scenes, extreme numbers, old formats, official errors | 65 | 65 | 0 |
| **Total** | | **1176** | **1176** | **0** |

| Lower-level check | Cases | Different |
|---|---:|---:|
| perfect-freehand outlines, every number compared by bit pattern | 322 | 0 |
| `restoreElements` normalisation of old and partial elements | 50 | 0 |
| JSON numbers read like V8 does | 10000 | 0 |
| `Math.hypot` | 5256 | 0 |
| `Math.atan2` | 5256 | 0 |
| x³ correctly rounded (V8's `Math.pow(x, 3)` varies by platform) | 8000 | 0 |
<!-- stats:end -->

“Different”按差异类型分为结构不同、属性不同、数值不同，测试失败时会列出前几个失败场景的名字。

场景的来源：

- `editor-api/`：用官方 `convertToExcalidrawElements`（编辑器自己用来生成流程图的函数）构造，包括带标签的绑定箭头、frame、分组。
- `handmade/`、`random/`：脚本写出的 JSON，包括旋转、透明度、固定种子的随机混合场景。
- `real/`：**3 个用鼠标在 excalidraw.com 上画出来的**场景（流程图、frame、一个被删掉 frame 后遗留的混合场景），原样取自编辑器的存储。它们带有 0.18.1 之后才有的字段，官方 0.18.1 导出和本库都会忽略。详见 [fixtures/scenes/SOURCES.md](fixtures/scenes/SOURCES.md)。
- 没有 10 张手画图：用鼠标画图又慢又容易出错，所以手画的只有 3 张。

## 设计

依赖方向从上到下。

| 包 | 核心逻辑 |
|---|---|
| `export` | 编排整个流程：过滤元素、给 frame 加标题文字、算画布大小（frame 里的元素不计入）、写根节点、裁剪路径、背景，再按顺序画每个元素，绑定文字紧跟它的容器 |
| `shape` | 把元素样式变成 rough 选项（线宽、虚线、小图形降低粗糙度），每类元素对应一次 rough 调用；箭头头部的方向取自 rough 画出的第一段或最后一段贝塞尔曲线，所以和 seed 有关；包围盒来自 rough 的路径 |
| `freehand` | perfect-freehand 的 `getStroke`：先平滑输入点，再把笔迹向两侧偏移、加端帽，连成一个多边形 |
| `text` | 字体 id 到字体名和度量的表、基线位置的公式、RTL 判断、官方 `@font-face` 规则的选择 |
| `svg` | 一棵很小的 SVG 树，按 `outerHTML` 的规则序列化（属性顺序、转义） |
| `model` | 读 JSON，丢掉已删除的元素，套用官方 `restore` 的规则补齐旧文件缺的字段 |
| `internal/jsnum` | `Math.hypot`、`atan2`、`parseFloat` 等 V8 行为，逐位对照 |

一个容易忽略的细节：官方导出里，一个线性元素的“绝对坐标”取决于它的 rough 形状**有没有被生成过**（没生成过就用点估算，生成过就用真实曲线），所以导出结果依赖元素的绘制顺序。`shape.ShapeCache` 专门记录这个状态。

## 开发

```bash
moon check --deny-warn
moon fmt --check
moon test --target all     # js、wasm-gc、native
```

重新生成 fixtures（需要 Node 24）：

```bash
cd scripts
npm ci
node gen_fixtures.mjs          # 全部；也可以只跑某一组，如 `node gen_fixtures.mjs edge`
cd .. && moon fmt              # 生成的 .mbt 要格式化，之后和提交的应该完全一致
node scripts/update_readme_stats.mjs
```

fixtures 的来源：`scripts/package-lock.json` 锁定 `@excalidraw/excalidraw` **0.18.1**、`perfect-freehand` **1.2.0**，并检查 `roughjs` 是 4.6.4、`points-on-curve` 是 1.0.1（官方 0.18.1 依赖的版本）。`scripts/official_env.mjs` 用 esbuild 打包官方发布的 bundle，在 jsdom 里运行，并补上 canvas、`FontFace`、`Path2D` 等几个桩。wasm-gc 后端读不了文件，所以生成的 fixtures 是内嵌在 `src/internal/fixtures/` 里的 `.mbt` 文件。生成过程是可复现的：连续生成两次得到完全相同的文件。

验证过 jsdom 的输出和真实 Chromium 一致：21 个覆盖所有元素类型的场景逐字节相同（`scripts/browser_check.mjs`）。

CI 见 [.github/workflows/check.yml](.github/workflows/check.yml)：在 Linux、macOS、Windows 上跑 `moon check --deny-warn`、`moon build`、`moon test`（都带 `--target all`）、`moon fmt --check`，再确认 `moon info` 之后 `git diff` 为空；另有一个 job 安装 Node，重新生成 fixtures 并要求和仓库里的完全一致，同时检查 README 的对照表。Node 版本固定在 [scripts/.nvmrc](scripts/.nvmrc)（24.20.0），因为 `containsCJK` 的字符集随 Node 的 Unicode 版本而定。

### 依赖 moon_rough 的未发布版本

官方用 rough.js 4.6.4，moon_rough 对应 4.6.6，两者在三处不同：`hachureGap` 是否取整、3 点曲线的填充算法、2 点曲线的画法。moon_rough 的 `roughjs_464` 选项还原了 4.6.4 的行为（8148 个数值逐位一致）。在这个选项发布之前，本仓库通过被 git 忽略的 `moon.work` 使用本地的 moon_rough 副本；发布 moon_rough 的新版本之后，把 `moon.mod` 里的依赖版本改成新版本即可。

## 参考来源和许可证

本项目以 MIT 许可证发布（见 [LICENSE](LICENSE)）。

只参考了下列项目的规范和行为，用 MoonBit 重新实现，没有复制它们的源文件。原作者的版权声明和许可证全文保留在 [THIRD_PARTY_LICENSES](THIRD_PARTY_LICENSES)：

- [excalidraw](https://github.com/excalidraw/excalidraw)（MIT）：元素模型、图形生成、SVG 导出
- [perfect-freehand](https://github.com/steveruizok/perfect-freehand)（MIT）：手绘笔迹轮廓
- [@braintree/sanitize-url](https://github.com/braintree/sanitize-url)（MIT）：链接清理
- [V8](https://github.com/v8/v8)（BSD-3-Clause，其中的 fdlibm 例程）：`Math.atan2`、`Math.hypot`
- [roughjs](https://github.com/rough-stuff/rough)（MIT）：通过 moon_rough 使用

这个项目用到了 AI 工具辅助开发。所有预期值来自官方包的真实输出，不是 AI 生成的。
