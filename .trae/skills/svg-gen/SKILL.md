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
