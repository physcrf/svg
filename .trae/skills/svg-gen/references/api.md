# CL-SVG 完整 API 速查

> 本文件由 `svg-gen` skill 引用。所有函数均导出自 `:svg` 包，使用前先 `(in-package #:svg)`。
> 文档与源码一致：`src/` 下 utils.lisp、attributes.lisp、marker.lisp、core.lisp、shapes.lisp、path.lisp、latex.lisp、plot.lisp。

## 1. 坐标（复数点）

点以复数表示：实部为 X、虚部为 Y。

```lisp
(p x y)       ; 创建点，如 (p 10 20) => #C(10 20)
(x point)     ; 取 X（realpart）
(y point)     ; 取 Y（imagpart）
```

## 2. 单位转换（SVG 标准 1in = 96px）

```lisp
(px x)   ; 像素，原样返回
(in x)   ; 英寸   ×96
(cm x)   ; 厘米   ×96/2.54
(mm x)   ; 毫米   ×96/25.4
(pt x)   ; 磅     ×96/72
(pc x)   ; 皮卡   ×16
```

示例：`(rect (p 10 10) (cm 2) (cm 1) :fill "red")`

## 3. 形状元素

所有形状接受 `&rest` 关键字属性，直接作为 SVG 属性输出。属性值可以是数字、字符串、复数、列表。

```lisp
(rect (p x y) width height &key rx ry &rest attrs)
(circle (p cx cy) r &rest attrs)
(ellipse (p cx cy) rx ry &rest attrs)
(line (p x1 y1) (p x2 y2) &rest attrs)
(polyline (list (p x1 y1) ...) &rest attrs)
(polygon  (list (p x1 y1) ...) &rest attrs)
(text (p x y) content &rest attrs)   ; content 会被 XML 转义
```

- `rect` 仅给 `:rx` 时自动补 `:ry = rx`。
- `polyline`/`polygon` 要求 points 为 list。

示例：

```lisp
(rect (p 10 10) 100 60 :fill "#3498db")
(rect (p 20 20) 80 80 :rx 10 :fill "#e74c3c")   ; rx=ry=10
(circle (p 100 100) 50 :fill "#e74c3c" :stroke "#2c3e50" :stroke-width 2)
(text (p 100 200) "Hello" :font-size 24 :text-anchor "middle")
```

## 4. 帧与坐标系

### frame —— 子视口

```lisp
(frame (:x 50 :y 50 :width 150 :height 150 :viewbox "0 0 100 100")
  ...body...)
```

- 创建嵌套 `<svg>`，属性值与普通元素一致（`:x :y :width :height :viewbox :id :class`）。
- 属性值会被求值；viewBox 简写 `(0 0 100 100)`（裸列表）按字面处理。
- 可嵌套。

### cartesian-frame —— Y 轴向上

```lisp
(cartesian-frame (:x 50 :y 50 :width 200 :height 200 :viewbox (0 0 100 100))
  ...body...)
```

- 自动包一层 `<g transform="translate(0,h) scale(1,-1)">` 翻转 Y。
- 注意：内部文本会上下翻转，标签放帧外。

### plot-frame —— 数据绘图帧

```lisp
(plot-frame (&key x y width height xmin xmax ymin ymax
                  xtics ytics (xmtics 0) (ymtics 0) tic-length)
  ...body...)
```

- `:xtics`/`:ytics`：数字（间隔）或 `(start interval end)` 列表。
- `:xmtics`/`:ymtics`：两主刻度之间的次刻度数。
- `:tic-length`：主刻度像素长度，默认 `max(3, round(min(w,h)/40))`。
- body 内用 `(dp x y)` 把数据坐标转为像素坐标；视觉尺寸（圆半径、线宽）仍为像素。
- 自动绘制边框与向内刻度线。

示例：

```lisp
(plot-frame (:x 50 :y 50 :width 500 :height 300
                :xmin 0 :xmax 10 :ymin -1.5 :ymax 1.5
                :xtics 2 :ytics 0.5)
  (path ((moveto (dp 0 0)) (lineto (dp 1 0.841)) (closepath))
        :stroke "#d32f2f" :stroke-width 2 :fill "none")
  (circle (dp 1.57 1.0) 4 :fill "#d32f2f"))
```

## 5. 路径命令

`path` 宏：`(path (commands...) &rest attrs)`。命令分绝对（大写）与相对（带 `*` 后缀）。

| 绝对 | 相对 | 参数 |
|------|------|------|
| `(moveto (p x y))` | `(moveto* (dpoint))` | 移动 |
| `(lineto (p x y))` | `(lineto* (dpoint))` | 直线 |
| `(hlineto x)` | `(hlineto* dx)` | 水平线 |
| `(vlineto y)` | `(vlineto* dy)` | 垂直线 |
| `(curveto p1 p2 p3)` | `(curveto* dp1 dp2 dp3)` | 三次贝塞尔 |
| `(smooth-curveto p2 p3)` | `(smooth-curveto* dp2 dp3)` | 平滑三次贝塞尔 |
| `(quadto p1 p2)` | `(quadto* dp1 dp2)` | 二次贝塞尔 |
| `(smooth-quadto point)` | `(smooth-quadto* dpoint)` | 平滑二次贝塞尔 |
| `(arc radii point &key x-axis-rotation large-arc-flag sweep-flag)` | `(arc* radii dpoint ...)` | 圆弧 |
| `(closepath)` | — | 闭合 |

```lisp
(path ((moveto (p 150 160))
       (lineto (p 190 220))
       (lineto (p 110 220))
       (closepath))
      :fill "#9b59b6" :opacity 0.7)
```

> **注意**：`path` 是宏，`commands` 必须是**字面命令列表**（宏展开时每个命令形式被当作函数调用求值）。不能用运行时计算的表达式（如 `(cons ...)`/`(mapcar ...)` 构造的命令列表）——那样符号会被当作未定义变量。需要动态生成折线/曲线的点时，改用 `polyline`（接受运行时点列表）或逐段 `line`。


## 6. 变换

### 作为关键字属性传入（推荐）

```lisp
:translate (p 10 20)             ; translate(10,20)
:rotate 45                       ; rotate(45)
:rotate (list 45 (p cx cy))      ; rotate(45 cx,cy)
:scale 2                         ; scale(2)
:scale (list 2 3)                ; scale(2,3)
:skew-x 15                       ; skewX(15)
:skew-y 15                       ; skewY(15)
:matrix (list a b c d e f)       ; matrix(a b c d e f)
```

- 多个变换关键字会合并为一个 `transform` 属性，始终最后输出。
- 用户显式传 `:transform "..."` 也会并入同一个属性。

```lisp
(rect (p 50 50) 100 80 :fill "#3498db"
      :translate (p 10 10) :rotate 45 :scale (list 1.5 1.5))
```

### 变换辅助函数（返回字符串）

```lisp
(translate tx ty)
(rotate angle &optional cx cy)
(scale sx &optional sy)
(skew-x angle)
(skew-y angle)
(matrix a b c d e f)
```

## 7. 全局属性系统

```lisp
*default-attributes*            ; 全局默认属性（属性列表）
(set-default-attributes &rest attrs)   ; 整体替换
(clear-default-attributes)            ; 清空
(with-attributes (:fill "#e74c3c" :stroke "none")
  ...body...)                          ; 作用域内临时默认

(setf (getf *default-attributes* :stroke) "red")   ; 逐项设置
```

优先级：**函数实参 > with-attributes > *default-attributes***。
全局 `stroke` 同时驱动 marker 颜色（`fill="context-stroke"`）。

## 8. Marker 标记系统

### 内置定义宏

| 宏 | 图形 |
|----|------|
| `(define-arrow name ...)` | 实心箭头 |
| `(define-circle-dot name ...)` | 实心圆点 |
| `(define-square-dot name ...)` | 实心方块 |
| `(define-diamond name ...)` | 实心菱形 |
| `(define-triangle name ...)` | 实心三角 |
| `(define-cross name ...)` | 十字 |
| `(define-arrow-open name ...)` | 空心箭头 |

### 通用自定义

```lisp
(define-marker name content
  :refx 5 :refy 5 :markerwidth 10 :markerheight 10 :orient "auto" :scale 1.5)
```

### 引用

```lisp
(line (p 50 100) (p 150 100) :marker-start 'my-dot :marker-end 'my-arrow)
(line (p 50 200) (p 150 200) :marker-end :my-arrow)          ; 关键字亦可
(line (p 50 150) (p 150 150) :marker-end (marker-url 'my-arrow))
```

- `:scale`：数字或 `'(sx sy)`；会同时缩放 marker 盒与参考点。
- `(clear-all-markers)` 清空全部；`(marker-url name)` 生成 `url(#...)`。
- marker 内容默认使用 `context-stroke` 继承线条颜色。
- 用过的 marker 会自动写入文档 `<defs>`。

## 9. LaTeX 数学渲染（可选，需 TeX + dvisvgm）

```lisp
(latex (p 160 40) "$E = mc^2$")
(latex (p 160 90) "$\\int_0^\\infty e^{-x^2} dx = \\frac{\\sqrt{\\pi}}{2}$" :scale 0.8)

(set-latex-packages "amsmath,amssymb" "physics" "tikz")  ; 设置包
(get-latex-packages)                                     ; 查看
```

- `:scale` 控制缩放。默认包 `("amsmath,amssymb" "physics")`。
- 临时文件自动清理；TeX/dvisvgm 缺失时仅告警、不影响其余输出。

## 10. 元数据与工具元素

```lisp
(title "文本")          ; <title>
(desc "描述")           ; <desc>
(script "js代码")       ; <script>，内容原样输出（不转义）
(viewbox 0 0 100 100)   ; 生成 "0 0 100 100" 字符串
```

## 11. 文档生命周期

```lisp
(with-svg ("out.svg" 400 300) ...)      ; 推荐：自动开/关、写 <defs>
(open-svg "out.svg" 400 300)            ; 手动控制
...                                     ; 绘制
(close-svg)                             ; 收尾：<defs> + </svg> + 关流
```

- `with-svg` 使用 `unwind-protect`：body 报错也留下良构（部分）文件。
- `close-svg` 可重复调用（幂等）；嵌套 `with-svg` 正确保存/恢复当前文档。
