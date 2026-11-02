# moon_excalidraw MVP 设计

日期：2026-11-02。状态：等待审阅。

## 目标

用 MoonBit 读取官方 `.excalidraw` 文件，不依赖浏览器，输出和 Excalidraw 官方 `exportToSvg` 一致的 SVG。手绘图形依赖 `sayoi7799/moon_rough`，其余部分都是新增实现。

成功标准：

- 除“不可对照项”外，整份 SVG 和官方输出逐字节一致。
- `moon test` 在 js、wasm-gc、native 三个后端都通过。
- 提供命令行工具 `excalidraw2svg` 和并排对照的 gallery。
- 配置 CI，并发布到 mooncakes.io（黑客松验收要求）。

## 范围

**支持的元素：** rectangle、diamond、ellipse（含圆角）、line、arrow（含曲线和全部箭头样式）、freedraw、text（含绑定文字）、image（含裁剪）、frame、magicframe（与 frame 走同一套代码）。

**支持的样式：** strokeColor、backgroundColor、fillStyle（hachure、cross-hatch、solid、zigzag）、strokeWidth、strokeStyle、roughness、opacity、angle、seed、link。

`link` 不在最初列出的范围内。不处理会画错，所以纳入。

**不做：** 编辑和交互、PNG、协作、`.excalidrawlib`、Obsidian 压缩格式、肘形箭头、字体子集化、深色模式、`exportEmbedScene`、`exportingFrame`。

**固定的导出参数：** `exportScale` 为 1，`exportPadding` 为 10，frame 的 enabled、clip、name、outline 都开启。`exportBackground` 默认开启，`viewBackgroundColor` 取自文件。

## 对照基准

| 依赖 | 版本 | 说明 |
|---|---|---|
| `@excalidraw/excalidraw` | 0.18.1 | npm latest |
| `perfect-freehand` | 1.2.0 | 官方固定使用的版本 |
| `roughjs` | 4.6.4 | 官方依赖的版本 |
| `points-on-curve` | 1.0.1 | 官方 `simplify` 使用，算法与 0.2.0 相同 |

fixtures 生成链路：`scripts/package-lock.json` 锁定版本，esbuild 打包官方 prod bundle，再在 jsdom 中运行，并补上 `Path2D`、`FontFace`、`document.fonts`、`matchMedia`、`ResizeObserver` 和 canvas 的 `getContext`。

## moon_rough 的版本差异

moon_rough 对应 roughjs 4.6.6，官方用 4.6.4。1160 个场景的实测中有 138 个输出不同，来自两处：

1. 4.6.6 把 `hachureGap` 取整，`strokeWidth × 4` 非整数且用图案填充时不同。
2. 3 点曲线的图案填充算法不同。

处理方式：给 moon_rough 增加一个 4.6.4 兼容选项，默认行为不变，用 roughjs 4.6.4 的 fixtures 验证后发新版。开发期间用本地路径依赖，发布后切换到版本依赖。发布前会再向维护者确认。

## 架构

依赖方向从上到下：

```text
cmd/excalidraw2svg, cmd/gallery   命令行和对照页（js、native）
export     流程编排：过滤、画布大小、frame、元素顺序、警告
shape      rough 选项、元素生成规则、箭头头部、包围盒
text       字体表、度量、行拆分、RTL、@font-face 选择
freehand   perfect-freehand 的 getStroke，不依赖其他业务包
svg        节点写入、HTML 序列化转义、JS 数字格式
model      JSON 解析、容错、restore 规则
internal/jsnum  hypot、atan2 等 moon_rough/jsmath 没有的函数
```

### 公开接口

```moonbit
pub fn parse_scene(StringView) -> Scene raise ParseError
pub fn export_to_svg(
  Scene,
  fonts? : FontMode,
  on_unsupported? : UnsupportedPolicy,
  measure_text? : (String, String) -> Double,
) -> ExportResult raise ExportError

pub struct ExportResult { svg : String; warnings : Array[Warning] }
pub enum FontMode { Url; None }
pub enum UnsupportedPolicy { Error; SkipWithWarning }
```

默认值是 `FontMode::Url` 和 `UnsupportedPolicy::SkipWithWarning`。具体类型名可以在实现时按 MoonBit 习惯调整，语义不变。

### 数据流

1. `model`：解析 JSON，不认识的字段直接忽略。
2. `export`：先过滤 `isDeleted`，再走 restore 规则。
3. `shape`：算根元素的包围盒，得到画布大小和偏移。
4. `export`：加入 frame 标题，写根节点、裁剪路径、字体块、背景。
5. `export`：先画非 iframe 类元素，绑定文字紧跟容器输出。

## 必须保持的官方行为

- 过滤 `isDeleted` 后才计算包围盒。官方 `exportToSvg` 本身不过滤，官方编辑器的导出路径会先过滤，fixtures 生成时也先过滤。
- 空文字在 restore 中才被标记为已删除，仍然计入包围盒。
- line 和 arrow 的包围盒来自 rough 生成的路径，生成时使用同一个 seed。
- 起点箭头对共享 options 的修改会带到终点箭头。
- frame 裁剪的 `rotate()` 直接写弧度值。
- 文字有 `containerId` 但容器没有反向记录时，不输出这段文字。
- `groupIds` 不影响输出。
- 宽高都为 0 的非线性元素、少于 2 个点的线性元素和 freedraw 会被丢弃。
- 坐标输出用 `+toFixed(2)` 的语义，再按 JS 规则转字符串。
- freedraw 路径按官方正则的语义截断小数，不四舍五入。

## 和官方的有意差异

| 情况 | 官方 | 本库 |
|---|---|---|
| embeddable、iframe、肘形箭头 | 绘制 | 报错，或跳过并警告；跳过的元素不计入画布大小 |
| 未知元素类型 | 静默丢弃 | 同样不绘制，但给出警告或报错 |
| 没有 `points` 的 line、arrow | 抛 TypeError | 返回错误 |
| `seed: 0` | 使用 `Math.random`，结果不确定 | 使用 moon_rough 的固定回退序列并警告 |
| 字体内联 | base64 子集 | URL 引用或不含字体 |
| 非法 JSON | 由调用方的 `JSON.parse` 报错 | 抛 `ParseError`，不崩溃 |

## 字体

`FontMode::None` 对应官方 `skipInliningFonts`，输出空的字体块。

`FontMode::Url` 输出官方拉取字体失败时的回退形式，也就是指向 `esm.sh/@excalidraw/excalidraw@0.18.1/dist/prod/fonts/...` 的 `@font-face`。分片的 unicode-range 表由脚本从官方数据生成。

实现前先弄清一个未解释的现象：Nunito、Cascadia、Helvetica 混排时，官方回退输出里只有 Nunito。Helvetica 是本地字体，符合预期；Cascadia 的原因还要查。

## frame 标题的测量

标题宽度是导出流程里唯一要现场测量的值。它影响是否截断和 `rotate(0 cx cy)` 的中心值。

`measure_text` 可以由调用方注入。默认按每个字符 `0.5 × fontSize` 估算，并在 README 中说明。对照测试中官方和本库注入同一个确定性函数：每个字符宽 7。

## 对照与误差

| 对象 | 要求 |
|---|---|
| 整份 SVG（`FontMode::None`） | 逐字节一致 |
| `FontMode::Url` 的字体块 | 逐字节一致 |
| perfect-freehand 轮廓 | 每个 double 按十六进制逐位一致 |

**不可对照项：** 内联字体的 base64 数据；真实系统字体下的 frame 标题测量值；`seed: 0`；重复元素 id（官方随机生成新 id）。

失败时报告差异分类（结构、属性、数值）和最大数值偏差。统计结果写入 README。

## 测试

预期值全部来自官方，由 `scripts/gen_fixtures.mjs` 生成并内嵌为 `.mbt`。

1. **perfect-freehand：** 随机点序列和多组参数，逐项对照。
2. **单元素：** 元素 × 样式的成对覆盖（约 200 个），加上 UI 常用值的全组合。
3. **组合场景：** 至少 50 个，包括用官方编辑器画的真实图约 10 张，来源分别标注。
4. **边界情况：** 空场景、只有已删除元素、宽高为 0、超大坐标、缺字段的旧文件、非法 JSON。
5. **差异统计：** 输出到测试报告并写入 README。

实施早期要先验证三件事：

- 用 Chromium 抽查 jsdom 生成的结果是否和真实浏览器一致。
- MoonBit 解析 JSON 得到的 double 是否和 V8 一致。
- 原生构建 CLI 需要什么编译器。这台机器没有 gcc 和 cl，必要时 CLI 先走 js 后端，native 构建放到 CI。

这三项如果有结果不符合预期，先向维护者报告，再决定如何调整。

## 工作方式

- 每个小步骤都跑 `moon check` 和 `moon test`，通过后马上提交。
- 提交信息写清楚做了什么，不加 Co-Authored-By 署名，不做空提交。
- 每完成一个模块，用 3–5 句话解释核心逻辑，方便答辩。

## 交付

- README：定位、和 moon_rough、moonlight 的关系、支持范围表、和官方的差异、重新生成 fixtures 的方法、参考来源和许可证。
- 项目许可证为 MIT，保留 excalidraw 和 perfect-freehand 的版权声明。
- `excalidraw2svg` 命令行工具和 gallery。
- CI（check、build、test）和 mooncakes.io 发布。
