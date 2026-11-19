# 答辩要点

一句话：读 `.excalidraw`（或 Obsidian 的 `.excalidraw.md`），不用浏览器，输出和官方 `exportToSvg`（`@excalidraw/excalidraw` 0.18.1）逐字节相同的 SVG。下面五点是被问到时要讲清楚的。

## 1. 从 `.excalidraw` 元素到 SVG 的流程

入口是 `export_to_svg`（`src/export/export.mbt`），分几步。

1. **读文件**：`parse_scene`（`src/model`）读 JSON，丢掉已删除的元素，套用官方 `restore` 的规则补齐旧文件缺的字段。Obsidian 的文件先由 `src/obsidian` 取出里面的 JSON，再走同一条路。
2. **筛元素**：embeddable、iframe、肘形箭头、未知类型按调用方的选择报错或跳过并警告。
3. **算画布**：给 frame 加上标题文字，求所有"根"元素的包围盒（frame 里的元素不撑大画布），宽高等于包围盒加上两边各 10px 的留白。
4. **写骨架**：`<svg>` 根节点、版本注释、`<defs>`（frame 的裁剪路径、字体规则）、背景矩形。
5. **画元素**：按顺序，每个元素由 `src/shape` 把样式变成 rough 选项，调用 moon_rough 画出手绘线条，得到 SVG 节点；绑定在容器里的文字紧跟容器输出。
6. **序列化**：`src/svg` 按浏览器 `outerHTML` 的规则输出（属性顺序、转义）。

一个容易忽略的地方：官方里一个线性元素的"绝对坐标"取决于它的 rough 形状有没有被生成过，所以包围盒依赖绘制顺序。`shape.ShapeCache` 就是用来记住这个状态的。

## 2. 为什么能逐字节一致

输出由很多浮点数拼成，差最后一位也算不一致，所以每一处和 JavaScript 不同的地方都要对上，而且都用官方包生成的预期值来验证，不设数值容差。

- **`roughjs_464`**：官方用 rough.js 4.6.4，moon_rough 默认是 4.6.6，两者有三处不同：`hachureGap` 是否取整、3 点曲线的填充算法、2 点曲线的画法。我给 moon_rough 加了 `roughjs_464` 选项（默认关闭，不影响别人），已发布在 0.3.0；用 4.6.4 生成的 8148 个数值逐位对照。
- **V8 的数学函数**（`src/internal/jsnum`）：`Math.hypot` 两个参数时走 V8 的快速路径，不是通用的循环；`Math.atan2` 移植 V8 带的 fdlibm；`Math.pow(x, 3)` 在 V8 里调用平台的 C 库，最后一位随平台变化，没法逐平台复刻，所以用正确舍入的立方，并在 README 里写明这是差异。对照用例：`hypot` 5256 个、`atan2` 5256 个、立方 8000 个，都按位比较。`parseFloat` 也单独移植（估算 frame 标题宽度时，官方用它从字体字符串里取字号，例如 `"14px Helvetica"`），有 50 个用例。
- **JSON 数字的读法**：MoonBit 的 JSON 解析读出的 double 要和 V8 的 `JSON.parse` 相同。我用 10000 个数（随机位模式、很大很小的数、带小数的数）对照，全部按位相同，所以没有另写解析器。
- **perfect-freehand 的移植**（`src/freehand`）：MoonBit 里没有，我照 1.2.0 的 `getStroke` 移植，322 个笔迹的轮廓、每个数都按十六进制位模式对照。

## 3. 测试方法：官方结果怎么来的，为什么可信

- **预期值的来源**：`scripts/gen_fixtures.mjs` 在 Node 里运行官方包。`package-lock.json` 固定了 `@excalidraw/excalidraw` 0.18.1、`perfect-freehand` 1.2.0 和依赖（roughjs 4.6.4）。esbuild 把官方的发布版 bundle 打成一个文件，放在 jsdom 里运行，再补上 jsdom 没有的东西：`Path2D`、`FontFace`、canvas 的 `getContext`、`matchMedia`、`ResizeObserver`。生成的结果以 `.mbt` 文件的形式内嵌在 `src/internal/fixtures/`，因为 wasm-gc 后端读不了文件。
- **可复现**：种子固定，换行统一成 LF；CI 里有一个任务重新生成全部夹具，要求和仓库里的完全一致。
- **jsdom 的输出为什么可信**：我写了 `scripts/browser_check.mjs`，在真实的 Chromium 里对 21 个覆盖所有元素类型的场景重新导出，和 jsdom 的结果逐字节相同。更直接的证据是线上演示页：官方包在访问者的浏览器里运行，和本库当场对照，我在线上页面验证过 4 张示例图都一致；CI 里的 `scripts/demo_check.mjs` 对示例图和真实编辑器画的图做同样的对照，发布页面之前必须通过。
- **覆盖**：1216 个场景（元素 × 样式的组合、字体、组合图、边界情况、Obsidian 文件），js、wasm-gc、native 三个后端都通过；其中 3 张是用鼠标在 excalidraw.com 上画的。

## 4. 和 moon_rough 的关系

moon_rough 是 rough.js 的 MoonBit 移植，我之前做的，也已发布。它只管"手绘"：给一个形状（线、矩形、椭圆、多边形、曲线、路径）和选项，生成带抖动的线条和各种填充（hachure、cross-hatch、zigzag 等），输出成 SVG 或 canvas 的操作序列。它不认识 Excalidraw 的任何概念。

本项目在它之上新增的是 Excalidraw 本身：文件解析和 `restore`、元素到 rough 选项的规则、箭头和 12 种箭头样式、文字布局和字体规则、frame、图片、自由画笔、画布和导出布局、SVG 序列化，还有命令行、站点生成器、演示页和 Obsidian 文件读取。

代码量（只数 `.mbt` 源文件的行数，不含测试、生成的夹具和性能测试）：

| | 行数 | 包括 |
|---|---:|---|
| moon_rough | 约 5,070 | `core` 1,965、`jsmath` 1,031、`path_data` 610、`canvas` 590、`curve` 315、`hachure` 258、`svg` 115、`random` 105 等 |
| 本项目：渲染库 | 约 4,400 | `shape` 1,263、`model` 1,058、`export` 928、`freehand` 481、`text` 274、`jsnum` 241、`svg` 126 |
| 本项目：Obsidian | 588 | `src/obsidian`（其中 LZ-String 移植和 Markdown 解析） |
| 本项目：命令行、站点、演示用的 `web` | 约 900 | `site` 358、`cmd` 351、`cli` 153、`web` 42 |
| 本项目：测试基础设施 | 约 230 | `internal/conform` 等 |

另外，本项目有约 1,440 行手写的测试、约 28,800 行生成的夹具和字体表，1,900 行生成夹具用的 JavaScript，和 300 行演示页。两个项目的规模相近，本项目的渲染库部分并不比 moon_rough 大，难点在于每一处都要和官方对上，不在代码多。

## 5. 和 moonlight、papyr 的区别

这两个项目我是看了它们在 mooncakes.io 上的页面和 moonlight 的 README 得出的，没有读源码。

- **moonlight**（`mizchi/moonlight`，MIT）：用 MoonBit 和 Luna 写的轻量 SVG 编辑器，受 Excalidraw 启发，有自己的 `Element`、`Style` 数据模型，存取的是 SVG；它的说明里没有提到读写 `.excalidraw`。它是**编辑器**，本项目是**渲染器**：只读官方格式，输出官方的 SVG，不做编辑。两者不重叠。
- **papyr**（`f4ah6o/papyr`，Apache-2.0）：文档平台（文档模型、Markdown 渲染、页面生成），0.1.0 已被作者标记为不再维护。它把 Excalidraw 块作为 `papyr-excalidraw` 围栏里的 JSON 存进 Markdown，但不渲染。本项目可以给这类文档提供渲染。

## 已知的差异和没做的

- 字体：官方内联 base64 子集字体，本库只能写 URL 引用或不带字体，对照的是官方"取不到字体"时的输出。
- embeddable、iframe、肘形箭头不画，由调用方选择报错或警告。
- frame 标题的宽度官方用浏览器测量，本库默认估算，可以传入测量函数。
- Obsidian 文件里库内的图片和公式取不到，会跳过并警告。
- 不做：编辑、PNG、协作、`.excalidrawlib`、字体子集化。

完整的差异表在 README 的"和官方结果的差异"里。
