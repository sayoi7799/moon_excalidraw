# 把一个文件夹的 .excalidraw 变成网页

`diagrams/` 里放着几个 `.excalidraw` 文件。一条命令生成一个网页，页面里是所有图的 SVG：

```bash
moon run --target js src/cmd/excalidraw2site -- examples/site/diagrams -o examples/site/dist
```

也可以用 `--target native`（不需要 Node）。命令的选项：

| 选项 | 作用 |
|---|---|
| `-o, --output <dir>` | 输出到哪个文件夹，默认 `dist` |
| `--title <text>` | 页面标题，默认 `Diagrams` |
| `--no-fonts` | SVG 里不带字体规则 |

## 生成了什么

```text
dist/
  index.html          所有图的页面，按文件名排序
  svg/flowchart.svg   每张图一个 SVG，可以单独打开、链接或下载
  src/flowchart.excalidraw   每张图的源文件副本，页面上有链接
```

- 页面里每张图用 `<object>` 嵌入对应的 `.svg`。这样每张图自成一个文档，不会撞 id；
  SVG 里的 `@font-face` 也能加载，文字显示成手写字体。用 `<img>` 的话字体加载不了。
- 某个文件渲染不出来（JSON 坏了、不是 Excalidraw 文件）时，页面上那张卡片会写明原因，
  其余的图照常生成，命令最后以非零退出码结束，CI 能发现。
- 画不了的元素（embeddable、iframe、肘形箭头）被跳过，原因写在那张卡片上。
- 文件夹里没有 `.excalidraw` 文件也会报错退出，免得发布一个空页面。
- 只读文件夹本身，不递归子文件夹。

## 接到 GitHub Pages：每次提交自动更新

[github-pages.yml](github-pages.yml) 是一个可以直接用的工作流，复制到你自己仓库的
`.github/workflows/diagrams.yml`：

1. 把图放在仓库的 `diagrams/` 文件夹（改 `DIAGRAMS` 可以换文件夹）。
2. 在仓库的 Settings → Pages → Build and deployment，把 Source 选成 **GitHub Actions**。
3. 提交并推送。之后每次推送到 `main` 且改动了 `diagrams/` 里的文件，工作流就会重新生成
   并发布，页面地址是 `https://<用户名>.github.io/<仓库名>/`。

它做的事：检出你的仓库，再检出固定版本的 moon_excalidraw，安装 MoonBit，运行上面那条命令把站点
生成到 `_site/`，然后用官方的 `upload-pages-artifact` 和 `deploy-pages` 发布。
`MOON_EXCALIDRAW_REF` 固定了画图用的版本，升级是你自己提交的改动，图不会无缘无故变。

这个工作流还没在 GitHub 上跑过，用之前先在你的仓库里手动触发一次（Actions → Diagrams site →
Run workflow）确认。moon_excalidraw 需要先发布它依赖的 moon_rough 新版本，之后这个工作流才能构建它。

## 只想让 CI 检查、不发布页面

不需要 Pages 也可以：在任何 CI 里跑同一条命令，生成失败（有图渲染不出来）时命令的退出码非零，
这一步就会让 CI 变红，等于检查所有 `.excalidraw` 文件都是好的。

```yaml
- name: Diagrams still render
  run: moon run --target native src/cmd/excalidraw2site -- diagrams -o "$RUNNER_TEMP/site"
```

## 想把生成的 SVG 提交进仓库

如果你的 README 要用 `![](diagrams/flow.svg)` 引用图，需要把 SVG 也放进仓库。用
`excalidraw2svg` 一张张生成，再让 CI 检查它们没有过期：

```bash
moon run --target native src/cmd/excalidraw2svg -- diagrams/flow.excalidraw --no-fonts -o diagrams/flow.svg
```

```yaml
- name: SVGs are up to date
  run: |
    for f in diagrams/*.excalidraw; do
      moon run --target native src/cmd/excalidraw2svg -- "$f" --no-fonts -o "${f%.excalidraw}.svg"
    done
    git diff --exit-code -- 'diagrams/*.svg'
```

`--no-fonts` 让 SVG 里不带外链字体，在 README 里显示时也不会请求外部网站（用 `<img>` 显示时字体本来就
加载不了）。输出是确定的，同样的输入永远得到同样的字节，所以 `git diff` 只会在图真的改了的时候出现差异。
