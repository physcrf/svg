# SVG - a Common Lisp SVG 生成库

一个AI生成的 Common Lisp 库，用于生成 SVG (Scalable Vector Graphics) 文件，支持 LaTeX 数学公式渲染和自定义标记系统。

## ✨ 特性

- **复数坐标系统** - 使用复数表示 2D 坐标点，简洁直观
- **全局 SVG 流模式** - 无需显式传递 SVG 对象
- **with-svg 宏** - 自动管理文件打开和关闭
- **直接 Transform 属性** - 使用 `:translate`、`:rotate`、`:scale` 等关键字
- **路径宏语法** - 直观的路径命令组合
- **全局属性系统** - 支持全局默认属性，可动态修改
- **标记系统** - 内置多种标记类型，支持缩放和自定义
- **LaTeX 公式渲染** - 通过 dvisvgm 将 LaTeX 转换为 SVG

## 📦 安装

### 依赖

- `alexandria` - 通用工具库
- `cl-ppcre` - 正则表达式
- `str` - 字符串处理
- `trivia` - 模式匹配

### 安装步骤

将此库放置在 Quicklisp 的 `local-projects` 目录中：

```bash
cd ~/.quicklisp/local-projects
# 将 svg 文件夹放在这里
```

然后在 SBCL 中加载：

```lisp
(ql:quickload :svg)
```

### LaTeX 前置要求

如需使用 LaTeX 功能，请确保系统已安装：

## 🚀 快速开始

### 使用 with-svg 宏（推荐）

```lisp
(in-package :svg)

(with-svg ("output.svg" 400 300)
  (rect (p 10 10) 100 60 :fill "#3498db")
  (circle (p 200 100) 30 :fill "#e74c3c")
  (text (p 150 200) "Hello SVG!" :font-size 24 :fill "black"))
```

### 使用 open-svg/close-svg

```lisp
(in-package :svg)

(open-svg "output.svg" 400 300)
(rect (p 10 10) 100 60 :fill "#3498db")
(circle (p 200 100) 30 :fill "#e74c3c")
(close-svg)
```

### 复数坐标系统

```lisp
;; 创建点
(p x y)           ; 创建复数点 (如 (p 10 20))
(x point)         ; 获取 X 坐标（实部）
(y point)         ; 获取 Y 坐标（虚部）

;; 示例
(let ((center (p 150 100)))
  (circle center 50))  ; 在 (150, 100) 绘制半径为 50 的圆
```

## 📐 图形元素

### 基础形状

所有形状函数支持 `&key &rest &allow-other-keys`，可接受任意 SVG 属性。

#### rect - 矩形

```lisp
(rect position width height &key rx ry &rest attrs &allow-other-keys)
```

**参数：**
- `position` - 左上角位置（复数）
- `width` - 宽度
- `height` - 高度
- `:rx`, `:ry` - 圆角半径（可选关键字参数）
- `attrs` - 其他 SVG 属性

**示例：**
```lisp
(rect (p 10 10) 100 60 :fill "#3498db")              ; 普通矩形
(rect (p 20 20) 80 80 :rx 10 :ry 10 :fill "#e74c3c") ; 圆角矩形
```

#### circle - 圆形

```lisp
(circle center radius &key &rest attrs &allow-other-keys)
```

**示例：**
```lisp
(circle (p 100 100) 50 :fill "#e74c3c" :stroke "#2c3e50" :stroke-width 2)
```

#### ellipse - 椭圆

```lisp
(ellipse center rx ry &key &rest attrs &allow-other-keys)
```

**示例：**
```lisp
(ellipse (p 150 100) 80 40 :fill "#2ecc71")
```

#### line - 直线

```lisp
(line start end &key &rest attrs &allow-other-keys)
```

**示例：**
```lisp
(line (p 0 0) (p 100 100) :stroke "#2c3e50" :stroke-width 2)
```

#### polyline - 折线

```lisp
(polyline points-list &key &rest attrs &allow-other-keys)
```

**示例：**
```lisp
(polyline (list (p 10 10) (p 50 30) (p 90 10))
          :stroke "#3498db" :fill "none")
```

#### polygon - 多边形

```lisp
(polygon points-list &key &rest attrs &allow-other-keys)
```

**示例：**
```lisp
(polygon (list (p 50 10) (p 90 90) (p 10 90))
         :fill "#f39c12")
```

### 文本元素

#### text - 文本

```lisp
(text position content &rest attrs)
```

**示例：**
```lisp
(text (p 100 200) "Hello, World!"
      :font-size 24 :font-family "Arial" :fill "#2c3e50")

(text (p 100 250) "中文测试"
      :font-size 18 :fill "darkblue")

(text (p 100 300) "Bold Text"
      :font-size 16 :font-weight "bold" :fill "red")
```

#### tspan - 文本片段

```lisp
(tspan content &rest attrs)
```

**特殊关键字参数：**
- `:position` - 位置（复数）
- `:dx`, `:dy` - 相对偏移
- `:rotate` - 旋转角度

**示例：**
```lisp
(text (p 100 250) nil :font-size 16)
(tspan "Bold text" :font-weight "bold" :fill "#e74c3c")
(tspan " normal text" :font-weight "normal")
```

## 🎨 路径命令

使用 `path` 宏创建复杂的路径：

```lisp
(path (commands...) &rest attrs)
```

### 绝对路径命令

| 命令 | 参数 | 说明 |
|------|------|------|
| `moveto` | `(point)` | 移动到点 |
| `lineto` | `(point)` | 画直线到点 |
| `hlineto` | `(x)` | 水平线到 x |
| `vlineto` | `(y)` | 垂直线到 y |
| `curveto` | `(p1 p2 p3)` | 三次贝塞尔曲线 |
| `smooth-curveto` | `(p2 p3)` | 平滑三次贝塞尔 |
| `quadto` | `(p1 p2)` | 二次贝塞尔曲线 |
| `smooth-quadto` | `(point)` | 平滑二次贝塞尔 |
| `arc` | `(radii point &key ...)` | 圆弧 |
| `closepath` | 无 | 闭合路径 |

### 相对路径命令（带 * 后缀）

| 命令 | 参数 | 说明 |
|------|------|------|
| `moveto*` | `(dpoint)` | 相对移动 |
| `lineto*` | `(dpoint)` | 相对画线 |
| `hlineto*` | `(dx)` | 相对水平线 |
| `vlineto*` | `(dy)` | 相对垂直线 |
| `curveto*` | `(dp1 dp2 dp3)` | 相对三次贝塞尔 |
| `smooth-curveto*` | `(dp2 dp3)` | 相对平滑三次贝塞尔 |
| `quadto*` | `(dp1 dp2)` | 相对二次贝塞尔 |
| `smooth-quadto*` | `(dpoint)` | 相对平滑二次贝塞尔 |
| `arc*` | `(radii dpoint &key ...)` | 相对圆弧 |

### 使用示例

```lisp
;; 三角形
(path ((moveto (p 150 160))
       (lineto (p 190 220))
       (lineto (p 110 220))
       (closepath))
      :fill "#9b59b6"
      :opacity 0.7)

;; 贝塞尔曲线心形
(path ((moveto (p 320 180))
       (curveto (p 350 160) (p 370 190) (p 340 210))
       (curveto (p 310 230) (p 270 200) (p 270 170))
       (curveto (p 270 140) (p 310 110) (p 340 130))
       (curveto (p 370 150) (p 350 180) (p 320 180))
       (closepath))
      :fill "#e74c3c"
      :stroke "#c0392b")

;; 二次贝塞尔 + 圆弧
(path ((moveto (p 50 100))
       (quadto (p 100 50) (p 150 100))
       (arc (p 25 25) (p 125 75) :large-arc-flag 1 :sweep-flag 1)
       (closepath))
      :fill "#1abc9c"
      :stroke "#16a085")
```

## 🔄 Transform 属性

所有图形函数都支持 transform 属性，会自动合并为 SVG 的 `transform` 属性：

### 可用的 Transform 关键字

| 关键字 | 参数类型 | 示例 | 生成的 SVG |
|--------|----------|------|------------|
| `:translate` | 复数 | `:translate (p 10 20)` | `translate(10,20)` |
| `:rotate` | 数字或列表 | `:rotate 45` | `rotate(45)` |
| | | `:rotate (list 45 (p cx cy))` | `rotate(45 cx,cy)` |
| `:scale` | 数字或列表 | `:scale 2` | `scale(2)` |
| | | `:scale (list 2 3)` | `scale(2,3)` |
| `:skew-x` | 数字 | `:skew-x 15` | `skewX(15)` |
| `:skew-y` | 数字 | `:skew-y 15` | `skewY(15)` |
| `:matrix` | 列表 | `:matrix (list a b c d e f)` | `matrix(a b c d e f)` |

### 使用示例

```lisp
;; 单个变换
(circle (p 100 100) 50 :fill "#e74c3c" :translate (p 20 30))

;; 组合多个变换（按顺序应用）
(rect (p 50 50) 100 80 :fill "#3498db"
      :translate (p 10 10)
      :rotate 45
      :scale (list 1.5 1.5))

;; 带中心点的旋转
(ellipse (p 200 150) 60 40 :fill "#2ecc71"
         :rotate (list 30 (p 200 150)))
```

## 🎯 全局属性系统

### 使用 setf 设置全局属性

```lisp
;; 设置全局属性
(setf (getf *default-attributes* :stroke) "red")
(setf (getf *default-attributes* :stroke-width) 3)

;; 之后的所有图形都会继承这些属性
(line (p 50 100) (p 150 100) 
      :marker-end (marker-url 'my-arrow))  ; 自动获得 stroke="red" stroke-width="3"

;; 清除全局属性
(clear-default-attributes)
```

### 设置全局变换

```lisp
;; 全局平移
(setf (getf *default-attributes* :translate) (complex 100 50))

;; 全局旋转
(setf (getf *default-attributes* :rotate) 15)

;; 全局缩放
(setf (getf *default-attributes* :scale) 1.5)
```

### with-attributes 宏

临时覆盖或扩展默认属性：

```lisp
(with-attributes (:fill "#e74c3c" :stroke "none")
  ;; 这个块内的图形使用 :fill "#e74c3c" 和 :stroke "none"
  (rect (p 10 10) 100 100)
  (circle (p 200 200) 50))
```

### 属性优先级

1. **最高优先级** - 函数调用时传入的属性
2. **中等优先级** - `with-attributes` 宏设置的属性
3. **最低优先级** - 全局默认属性（`*default-attributes*`）

### 全局属性对 Marker 的影响

全局 `stroke` 属性会影响 marker 的颜色，因为 marker 使用 `fill="context-stroke"`：

```lisp
(define-arrow my-arrow)
(setf (getf *default-attributes* :stroke) "purple")
(line (p 50 100) (p 150 100) :marker-end (marker-url 'my-arrow))
;; 箭头会变成紫色
```

## 🏷️ 标记系统

### 内置标记类型

| 宏 | 说明 |
|----|------|
| `define-arrow` | 箭头 |
| `define-circle-dot` | 圆点 |
| `define-square-dot` | 方点 |
| `define-diamond` | 菱形 |
| `define-triangle` | 三角形 |
| `define-cross` | 十字 |
| `define-arrow-open` | 空心箭头 |
| `define-arrow-filled` | 实心箭头 |

### 定义标记

```lisp
;; 基本定义
(define-arrow my-arrow)

;; 带参数定义
(define-arrow big-arrow :markerwidth 15 :markerheight 15 :scale 2)

;; 缩放标记
(define-arrow small-arrow :scale 0.5)
(define-arrow wide-arrow :scale '(3 1))   ; x 放大 3 倍，y 不变
(define-arrow tall-arrow :scale '(1 3))   ; x 不变，y 放大 3 倍
```

### 使用标记

```lisp
;; 在线条端点使用标记
(line (p 50 100) (p 150 100) 
      :stroke "black" :stroke-width 2
      :marker-start (marker-url 'my-dot)
      :marker-end (marker-url 'my-arrow))
```

### 标记属性

| 属性 | 说明 | 默认值 |
|------|------|--------|
| `:refx` | 参考点 X | 0 (arrow) / 5 (dot) |
| `:refy` | 参考点 Y | 5 |
| `:markerwidth` | 标记宽度 | 10 |
| `:markerheight` | 标记高度 | 10 |
| `:viewbox` | 视图框 | "0 0 width height" |
| `:orient` | 方向 | "auto" |
| `:scale` | 缩放 | 1 |

### scale 属性

`scale` 可以接受：
- **单一数值** - x 和 y 使用相同缩放
- **一对数值** - 分别指定 x 和 y 缩放

```lisp
(define-arrow s1 :scale 0.5)      ; 等比缩小
(define-arrow s2 :scale 2)        ; 等比放大
(define-arrow s3 :scale '(3 1))   ; 宽箭头
(define-arrow s4 :scale '(1 3))   ; 高箭头
```

### 自定义标记

```lisp
(define-marker my-marker
    "<circle cx=\"5\" cy=\"5\" r=\"5\" fill=\"context-stroke\" />"
  :refx 5 :refy 5
  :markerwidth 10 :markerheight 10
  :scale 1.5)
```

### 标记管理函数

```lisp
(clear-all-markers)   ; 清除所有已定义的标记
(reset-markers)       ; 重置已使用的标记列表
(find-marker 'name)   ; 查找标记
(use-marker 'name)    ; 使用标记（添加到已使用列表）
(marker-url 'name)    ; 生成 url(#name) 字符串
```

## 🔢 LaTeX 数学公式渲染

通过 `latex` 函数将 LaTeX 数学公式渲染为 SVG 元素。

### latex 函数

```lisp
(latex position formula &rest attrs)
```

**参数：**
- `position` - 公式位置（复数）
- `formula` - LaTeX 字符串
- `:scale` - 缩放比例（可选）

**内置宏包：** `amsmath`, `amssymb`, `physics`

**示例：**

```lisp
;; 简单公式
(latex (p 160 40) "$E = mc^2$")

;; 积分公式
(latex (p 160 90) "$\\int_0^\\infty e^{-x^2} dx = \\frac{\\sqrt{\\pi}}{2}$"
       :scale 0.8)

;; 麦克斯韦方程组
(latex (p 160 140) "$\\nabla \\times \\vec{E} = -\\frac{\\partial \\vec{B}}{\\partial t}$"
       :scale 0.7)
```

### 设置 LaTeX 宏包

```lisp
(set-latex-packages "amsmath,amssymb" "physics" "tikz")
(get-latex-packages)  ; 获取当前宏包列表
```

### with-latex-env 宏

自动管理 LaTeX 临时文件的生命周期：

```lisp
(with-latex-env
  (with-svg ("output-with-math.svg" 400 300)
    (rect (p 0 0) 400 300 :fill "white")
    (latex (p 200 150) "$\\sum_{i=1}^{n} x_i^2$")))
;; 自动清理所有临时文件
```

### 清理函数

```lisp
(cleanup-all-latex)  ; 清理所有 LaTeX 临时目录和文件
```

## 🔧 工具函数

### 坐标和格式化

```lisp
(p x y)              ; 创建复数点
(x point)            ; 获取 X 坐标
(y point)            ; 获取 Y 坐标
(fmt number)         ; 格式化数字（整数无小数，浮点数保留2位）
```

### Transform 辅助函数

```lisp
(translate tx ty)    ; 生成 translate(tx,ty) 字符串
(rotate angle &optional cx cy)  ; 生成 rotate 字符串
(scale sx &optional sy)         ; 生成 scale 字符串
(skew-x angle)      ; 生成 skewX 字符串
(skew-y angle)      ; 生成 skewY 字符串
(matrix a b c d e f) ; 生成 matrix 字符串
```

### 辅助元素

```lisp
(title "文本")        ; 添加 <title> 元素
(desc "描述")        ; 添加 <desc> 元素
(script content)     ; 添加 <script> 元素
(viewbox min-x min-y width height)  ; 生成 viewBox 字符串
```

## 📝 完整示例

```lisp
(ql:quickload :svg)
(in-package :svg)

;; 定义标记
(define-arrow my-arrow :scale 1.5)
(define-circle-dot my-dot)

;; 创建 SVG 文件
(with-svg ("example.svg" 500 400)
  
  ;; 添加标题和描述
  (title "My First SVG Drawing")
  (desc "A demonstration of the CL-SVG library")
  
  ;; 设置全局属性
  (setf (getf *default-attributes* :stroke-width) 2)
  
  ;; 绘制背景
  (rect (p 0 0) 500 400 :fill "#f0f0f0" :stroke "none")
  
  ;; 绘制装饰性圆形（带变换）
  (dolist (i '(0 72 144 216 288))
    (let ((angle (* i (/ pi 180)))
          (center (p 250 200)))
      (circle center 40 
              :fill (format nil "hsl(~a,70%,60%)" i)
              :rotate (list angle center))))
  
  ;; 绘制星形路径
  (path ((moveto (p 250 80))
         (lineto (p 270 140))
         (lineto (p 330 140))
         (lineto (p 285 180))
         (lineto (p 305 240))
         (lineto (p 250 205))
         (lineto (p 195 240))
         (lineto (p 215 180))
         (lineto (p 170 140))
         (lineto (p 230 140))
         (closepath))
        :fill "#f1c40f"
        :stroke "#f39c12")
  
  ;; 绘制带标记的线条
  (setf (getf *default-attributes* :stroke) "purple")
  (line (p 50 350) (p 200 350) 
        :marker-start (marker-url 'my-dot)
        :marker-end (marker-url 'my-arrow))
  
  (setf (getf *default-attributes* :stroke) "blue")
  (line (p 300 350) (p 450 350)
        :marker-end (marker-url 'my-arrow))
  
  ;; 添加 LaTeX 公式
  (latex (p 250 320) "$E = mc^2$" :scale 0.8)
  
  ;; 添加文本标签
  (text (p 250 380) "Star Shape + LaTeX + Markers"
        :font-size 14 :text-anchor "middle" :fill "#333333")
  
  ;; 清理全局属性
  (clear-default-attributes))
```

## 📁 项目结构

```
svg/
├── svg.asd          # ASDF 系统定义 (v0.3.0)
├── package.lisp     # 包定义和导出
├── utils.lisp       # 工具函数
├── core.lisp        # 核心功能（open/close/with-svg/serialize）
├── attributes.lisp  # 属性系统
├── shapes.lisp      # 基础形状
├── text.lisp        # 文本元素
├── path.lisp        # 路径命令
├── latex.lisp       # LaTeX 渲染支持
├── marker.lisp      # 标记系统
└── test/            # 测试文件
    ├── test-shapes.lisp
    ├── test-text.lisp
    ├── test-path.lisp
    ├── test-transforms.lisp
    ├── test-markers.lisp
    ├── test-marker-scale.lisp
    └── test-global-attributes.lisp
```

## 🎓 设计理念

1. **简洁性** - 最少的样板代码，直观的 API
2. **一致性** - 所有函数使用统一的复数坐标系统和属性传递方式
3. **灵活性** - 支持 transform、样式继承、LaTeX、标记等高级特性
4. **可组合性** - 路径宏允许自由组合各种路径命令
5. **顺序保证** - 属性输出顺序可预测，transform 始终在最后

---

*本项目由 [TRAE](https://www.trae.ai) 与 [GLM-5](https://www.zhipuai.cn/) 生成*
