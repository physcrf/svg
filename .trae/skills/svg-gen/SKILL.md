---
name: "svg-gen"
description: "Generates SVG vector graphics (shapes, paths, markers, LaTeX math, data plots) by running the CL-SVG Common Lisp library via SBCL. Invoke when the user wants to create SVG images, charts, diagrams, schematics, or vector illustrations from a description."
---

# SVG 生成（CL-SVG 库）

通过 Common Lisp 的 CL-SVG 库生成 SVG 矢量图形。库以复数表示 2D 坐标（实部=X，虚部=Y），内置形状、路径、变换、全局属性、标记（marker）、LaTeX 数学公式渲染与数据绘图帧。

## 何时使用

- 用户要求生成 SVG 图片、图表、示意图、矢量插画、数学公式图、数据曲线图
- 用户给出图形的文字描述，需要输出 `.svg` 文件

## 库位置与加载

- 库位于 `~/.quicklisp/local-projects/svg/`（即本工作区）
- 依赖：`alexandria cl-ppcre str trivia`；可选 `latex + dvisvgm`（仅 LaTeX 渲染需要）
- 运行前确认 `~/.sbclrc` 已加载 Quicklisp（本项目测试文件直接使用 `ql:quickload`）

## 标准工作流程

1. **写脚本**：把 `references/templates/generate.lisp` 复制到工作目录（或任意临时位置），将绘制内容填入 `with-svg` 的 body，修改输出路径。
2. **运行**：

   ```bash
   sbcl --non-interactive --load generate.lisp
   ```

   或带输出路径参数：

   ```bash
   sbcl --non-interactive --load generate.lisp -- /tmp/output.svg
   ```

3. **验证**：确认脚本打印 `Generated <路径>`，必要时用 Read 检查生成的 SVG 是否良构（有 `<?xml` 头、`<svg>` 闭合标签、`<defs>` 内的 marker）。

## 快速上手

```lisp
(ql:quickload :svg :silent t)
(in-package #:svg)

(with-svg ("/tmp/example.svg" 400 300)
  (rect (p 10 10) 100 60 :fill "#3498db")
  (circle (p 200 100) 30 :fill "#e74c3c")
  (text (p 150 200) "Hello SVG!" :font-size 24 :fill "black"))
```

## 核心 API 速览（详见 references/api.md）

| 类别 | 函数/宏 |
|------|---------|
| 坐标 | `(p x y)`、`(x p)`、`(y p)` |
| 形状 | `rect` `circle` `ellipse` `line` `polyline` `polygon` `text` |
| 帧 | `frame` `cartesian-frame` `plot-frame`（内部用 `(dp x y)` 转换数据坐标） |
| 路径 | `path` + `moveto` `lineto` `hlineto` `vlineto` `curveto` `smooth-curveto` `quadto` `smooth-quadto` `arc` `closepath`（相对版本带 `*` 后缀） |
| 变换 | `:translate` `:rotate` `:scale` `:skew-x` `:skew-y` `:matrix`（作为关键字属性传入） |
| 属性 | `*default-attributes*`、`with-attributes`、`set-default-attributes`、`clear-default-attributes` |
| 标记 | `define-arrow` `define-circle-dot` `define-square-dot` `define-diamond` `define-triangle` `define-cross` `define-arrow-open`、`define-marker`；用 `:marker-start`/`:marker-end` 引用 |
| LaTeX | `(latex (p x y) "$E=mc^2$")`、`set-latex-packages` |
| 单位 | `px` `in` `cm` `mm` `pt` `pc`（1in=96px） |
| 其他 | `title` `desc` `script` `viewbox` |

## 关键约定

- 所有形状函数接受 `&rest` 关键字属性，属性名用关键字（`:fill` `:stroke` `:stroke-width`），值可为数字/字符串/复数/列表。
- 变换关键字会被合并为单个 `transform` 属性并始终输出在最后。
- **`path` 的 commands 必须是字面命令列表**（如 `(path ((moveto ...) (lineto ...)) ...)`）；运行时动态生成的曲线用 `polyline` 或逐段 `line`，见 references/api.md 第 5 节。
- 属性优先级：函数实参 > `with-attributes` 作用域 > `*default-attributes*`。
- Marker 用 `fill="context-stroke"` 继承所附线条颜色；符号（如 `'my-arrow`）与关键字（`:my-arrow`）引用均可，大小写不敏感。
- `script` 内容按原文输出（不转义）；其余元素文本会自动 XML 转义。
- `with-svg` 即使 body 报错也会留下良构（部分）文件；`close-svg` 可重复调用。

## 环境与故障排查

- 若 `ql:quickload` 失败：确认 Quicklisp 已安装且 `~/.sbclrc` 中有 `(load "~/quicklisp/setup.lisp")`。
- 若 `latex` 无输出并打印 warning：`latex`/`dvisvgm` 未安装（`sudo apt install texlive dvisvgm`），不影响其他元素。
- 中文文本需在 SVG 查看器中用支持中文字体渲染；文本方向与字号用 `:font-size` `:text-anchor` 控制。
- `cartesian-frame` 内文本会上下翻转，标签请放到帧外。

## 实战经验：单位与字号（px vs pt，重要）

**1 px = 0.75 pt**（CSS 约定 1in=96px，印刷 1in=72pt）。SVG→PDF 链条（`rsvg-convert`）严格按此折算：

```
LaTeX 10pt --dvisvgm(1pt→1px)--> 10px --rsvg(×0.75)--> 7.5pt PDF
```

- 要让图中文字在 PDF 里达到 10pt，LaTeX 需 `:scale 1.33`（或 text `:font-size 13`）。
- `width="N"` 的 SVG 嵌入 PDF 后宽 = N×0.75pt；8.6cm ≙ 325px。
- 若用根 `viewBox` 缩放内容（如 620 逻辑→325 输出），所有字号也被同步缩放，计算最终显示字号时别漏乘这个因子。

## 实战经验：latex 命令的坑

1. **`:rotate` 与 `:scale` 混用**：`latex` 输出为 `translate scale rotate` 顺序，`scale` 绕**原点**缩放。若传 `:rotate (list -90 (p cx cy))`（带中心），旋转后再被原点 scale 放大，内容会被推出画布外（y 轴竖排标签"消失"的根因）。**竖排标签请用 `:rotate -90`（不带中心）**，配合 latex 自带的 `translate(X,Y)` 落位。
2. **latex 不支持 `:text-anchor`**：渲染的是路径，没有锚点居中。需要居中时，先独立渲染一次并测量宽度（如转 PNG 后数暗像素），再用 `x = center - width/2` 手动定位。
3. **latex 锚点在基线**：`(latex (p x y) ...)` 的 y 是文字**基线**，字形主体在 y 上方。因此：① 与文字配对的水平样本线要画在 `(- y 3.5)`（≈10pt 字的视觉中心），画在 y 上会贴字底；② y 刻度数字等 text 元素同理，基线需下移 ~`fontsize/2` 才与刻度线光学居中（无下降部数字如 "0.3" 与带负号的 "-1" 观感还差 1–2px，取折中值即可）。
4. **`text` 元素里的 `$...$` 不会渲染数学**，只会原样显示。需要数学排版必须用 `latex` 命令，别把内容误写进 `text`。
5. **每次调用 latex 都会起一次 `latex`+`dvisvgm` 子进程**，图内标签多时生成明显变慢，属正常。
6. **颜色名兼容性**：librsvg 只认 CSS 标准色名（`red`/`blue`…）。gnuplot/X11 扩展名如 `dark-violet`、`dark-violet red` 会被**静默渲染成白色**（无警告）。一律用十六进制（如 dark-violet ≙ `#9467bd`），颜色是否生效可用转 PNG 后数该 RGB 像素数来验证。

## 实战经验：cl-ppcre 替换陷阱（文本后处理时）

- `regex-replace-all` 的**字符串替换模板**（`"\\g<1>..."`）在带引号嵌套的 SVG 文本里极易被字面输出（生成 `\g<1>` 垃圾）。要用捕获组重建字符串时，优先 `ppcre:scan` + `subseq` 手动拼接。
- `ppcre:do-scans` 绑定宏参数写法易错（报 `Error while parsing arguments to DEFMACRO DO-SCANS`）；用 `multiple-value-bind (ms me rs re) (ppcre:scan sc s :start pos)` 循环更稳。
- 后处理直接改 SVG 文本时，根级插入 `<g>` 要注意：① 跳过 `<?xml?>` 声明（从 `search "<svg"` 后找第一个 `>`）；② 闭合插在**最后一个** `</svg>` 前（`search :from-end t`），因为嵌套 `plot-frame` 也是 `<svg>` 标签。

## 实战经验：plot-frame 嵌套坐标系（最重要陷阱）

`plot-frame` 会生成嵌套 `<svg x=X y=Y viewBox>`，体内 `(dp x y)` 把数据坐标转为**嵌套像素坐标**。由此：

1. **根坐标元素必须放在 plot-frame 闭合之后**：刻度数字、轴标签、图例等若以画布根坐标定位，却写在 plot-frame 体内，会被嵌套 svg 整体平移 (X,Y)——且**不报错、曲线正常**，只表现为"位置偏了"。fig1 曾因括号层级错误让 plot-frame 推迟到函数末尾才闭合，全部刻度数字右移 42px。
2. **括号层级错误不一定报错**：Lisp 中未闭合的 `let`/`destructuring-bind` 会静默扩大作用域（例如把后续画线吞进循环体，同一元素画 N 次）。图形错位/重复时先数括号、再 grep 生成的 SVG 看嵌套 `</svg>` 出现在哪一行。
3. **诊断三板斧**：① grep SVG 中 `<svg`/`</svg>` 的行号确认嵌套边界；② grep 元素坐标（如 dasharray 线的 x1）换算数据位置核对；③ `rsvg-convert -z 3` 放大转 PNG 肉眼检查对齐。
4. **刻度裁剪**：tics spec 用 gnuplot 三元组 `(start interval end)` 时（记得加引号 `'(0 0.4 1.6)`），终点超出数据范围的刻度会被 `draw-x-tic`/`draw-y-tic` 的范围检查裁掉（gnuplot 行为，2026-08 加入）；需要显示该刻度就得同步扩 xrange/yrange。
5. **轴标签居中**：latex 无 text-anchor，xlabel 先按实测宽度定位（10pt @1.33 缩放的 "imaginary bias γ (units of Δ)" ≈170px 宽，325 画布中心 x=162.5，起点 77.5）。

## 实战经验：期刊图线宽基准（2026-08 定稿）

325px (8.6cm) 画布：数据曲线 0.94–1.05、图例样本 1.57（22px 线长，画在 `(- y 3.5)`）、**外框 1、刻度 1**（postprocess 不再加粗）、虚线参考线 1.2（dasharray "4,3"）。

## 实战经验：期刊图完整管线（绘→嵌→编译）

制作用于 LaTeX 稿件（如 PRA）的图，推荐管线与参数（实测有效）：

1. **绘图目标宽度直接用物理尺寸**：`width = cm目标 × 96/2.54`（8.6cm ≙ 325px）。源坐标即真实画布坐标，**避免事后 viewBox/g-scale 缩放层**——字号、线宽所见即所得。
2. **LaTeX 稿件中 `\includegraphics` 不带 `width=`**，用图的自然尺寸（PDF 页面已按 325px=8.6cm 生成）。若图宽超过 `\columnwidth`，要么缩图（字号随之变小，需按 px→pt 折算补偿），要么用 `figure*` 跨栏。
3. **SVG→PDF**：`rsvg-convert -f pdf -o out.pdf in.svg`。会打印 `pdfTeX warning: PDF inclusion: mult...` 类无害警告，可忽略。
4. **线宽基准**（325px 画布）：数据曲线 1.0–1.05、图例样本 1.5、外框 1、刻度 1（2026-08 定稿，外框不再加粗到 1.5）。
5. **整链自动化**：绘图脚本末尾内嵌后处理（加粗框/刻度），再用 Makefile 串联 `sbcl → rsvg → pdflatex+bibtex`，图更新后 `make` 一键完成。
6. **次刻度（mtics）**：`plot-frame` 内置 `:xmtics`/`:ymtics N`——每两个主刻度之间插 N 个次刻度，长度自动为主刻度一半。显式 `:tic-length`（px）控制主刻度长。期刊图常用 `:tic-length 6~7`。
