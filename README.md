# SVG - A Common Lisp SVG Generation Library

An AI-generated Common Lisp library for generating SVG (Scalable Vector Graphics) files with LaTeX math formula rendering and custom marker system.

## ✨ Features

- **Complex Number Coordinates** - Use complex numbers to represent 2D coordinate points, clean and intuitive
- **Global SVG Stream Mode** - No need to explicitly pass SVG objects
- **with-svg Macro** - Automatic file opening and closing management
- **Nested SVG Frames** - Create sub-viewport with independent coordinate systems
- **Cartesian Frame** - Dedicated macro for Cartesian (y-up) coordinate system
- **Direct Transform Attributes** - Use `:translate`, `:rotate`, `:scale` keywords directly
- **Path Macro Syntax** - Intuitive path command composition
- **Global Attributes System** - Support global default attributes with dynamic modification
- **Marker System** - Built-in marker types with scaling and customization
- **LaTeX Formula Rendering** - Convert LaTeX to SVG via dvisvgm
- **Pattern Matching** - Elegant pattern matching using trivia library
- **Library Leveraging** - Built on alexandria, cl-ppcre, str, trivia

## 📦 Installation

### Dependencies

- `alexandria` - Common utilities
- `cl-ppcre` - Regular expressions
- `str` - String processing
- `trivia` - Pattern matching

### Installation Steps

Place this library in Quicklisp's `local-projects` directory:

```bash
cd ~/.quicklisp/local-projects
# Place the svg folder here
```

Then load in SBCL:

```lisp
(ql:quickload :svg)
```

### LaTeX Prerequisites

For LaTeX functionality, ensure latex and dvisvgm are installed.

## 🚀 Quick Start

### Using `with-svg` (Recommended)

```lisp
(in-package :svg)

(with-svg ("output.svg" 400 300)
  (rect (p 10 10) 100 60 :fill "#3498db")
  (circle (p 200 100) 30 :fill "#e74c3c")
  (text (p 150 200) "Hello SVG!" :font-size 24 :fill "black"))
```

### Using `open-svg` / `close-svg` (Manual Control)

```lisp
(in-package :svg)

(open-svg "output.svg" 400 300)

(rect (p 10 10) 100 60 :fill "#3498db")
(circle (p 200 100) 30 :fill "#e74c3c")
(text (p 150 200) "Hello SVG!" :font-size 24 :fill "black")

(close-svg)
```

`open-svg` and `close-svg` are useful when you need fine-grained control over the SVG lifecycle, such as generating SVG content across multiple functions or in REPL-driven workflows.

### Complex Number Coordinate System

```lisp
(p x y)           ; Create complex point (e.g., (p 10 20))
(x point)         ; Get X coordinate (real part)
(y point)         ; Get Y coordinate (imaginary part)

;; Example
(let ((center (p 150 100)))
  (circle center 50))  ; Draw circle with radius 50 at (150, 100)
```

## 📐 Shape Elements

All shape functions support `&key &rest &allow-other-keys`, accepting SVG attributes.

### rect - Rectangle

```lisp
(rect position width height &key rx ry &rest attrs &allow-other-keys)
```

**Parameters:**

- `position` - Top-left corner position (complex number)
- `width` - Width
- `height` - Height
- `:rx`, `:ry` - Corner radius (optional keyword arguments)
- `attrs` - Other SVG attributes

**Examples:**

```lisp
(rect (p 10 10) 100 60 :fill "#3498db")
(rect (p 20 20) 80 80 :rx 10 :ry 10 :fill "#e74c3c")
```

### circle - Circle

```lisp
(circle center radius &key &rest attrs &allow-other-keys)
```

```lisp
(circle (p 100 100) 50 :fill "#e74c3c" :stroke "#2c3e50" :stroke-width 2)
```

### ellipse - Ellipse

```lisp
(ellipse center rx ry &key &rest attrs &allow-other-keys)
```

```lisp
(ellipse (p 150 100) 80 40 :fill "#2ecc71")
```

### line - Line

```lisp
(line start end &key &rest attrs &allow-other-keys)
```

```lisp
(line (p 0 0) (p 100 100) :stroke "#2c3e50" :stroke-width 2)
```

### polyline - Polyline

```lisp
(polyline points-list &key &rest attrs &allow-other-keys)
```

```lisp
(polyline (list (p 10 10) (p 50 30) (p 90 10)) :stroke "#3498db" :fill "none")
```

### polygon - Polygon

```lisp
(polygon points-list &key &rest attrs &allow-other-keys)
```

```lisp
(polygon (list (p 50 10) (p 90 90) (p 10 90)) :fill "#f39c12")
```

### text - Text

```lisp
(text position content &rest attrs &key &allow-other-keys)
```

```lisp
(text (p 100 200) "Hello, World!" :font-size 24 :font-family "Arial")
(text (p 100 250) "中文测试" :font-size 18 :fill "darkblue")
(text (p 100 300) "Bold Text" :font-size 16 :font-weight "bold" :fill "red")
```

### frame - Sub-viewport

Create a nested SVG viewport with its own coordinate system.

```lisp
(frame attributes &body body)
```

**Common Attributes:**

- `:x`, `:y` - Position in parent viewport
- `:width`, `:height` - Size of the viewport
- `:viewbox` - Internal coordinate system (e.g., "0 0 100 100")
- `:id`, `:class` - Standard SVG attributes

**Examples:**

```lisp
;; Create a sub-viewport with independent coordinates
(frame (:x 50 :y 50 :width 150 :height 150 :viewbox "0 0 100 100")
  (rect (p 0 0) 100 100 :fill "#e3f2fd")
  (circle (p 50 50) 30 :fill "#ff5722")
  (text (p 50 80) "Frame 1" :font-size 12 :text-anchor "middle"))

;; Nested frames
(frame (:x 50 :y 220 :width 300 :height 60 :viewbox "0 0 300 60")
  (rect (p 0 0) 300 60 :fill "#f3e5f5")
  
  ;; Nested sub-frame
  (frame (:x 10 :y 10 :width 80 :height 40 :viewbox "0 0 40 20")
    (rect (p 0 0) 40 20 :fill "#e1bee7")
    (text (p 20 14) "Nested" :font-size 8 :text-anchor "middle"))
  
  (text (p 150 35) "Outer frame" :font-size 12 :text-anchor "middle"))
```

**Use Cases:**

- Create reusable components with local coordinate systems
- Scale content independently using viewBox
- Organize complex SVGs into logical groups
- Apply transformations to entire sections

### cartesian-frame - Cartesian Coordinate Frame

Create a nested SVG viewport with a Cartesian (y-up) coordinate system. Content inside uses mathematical convention where y increases upward.

```lisp
(cartesian-frame attributes &body body)
```

**Common Attributes:**

- `:x`, `:y` - Position in parent viewport
- `:width`, `:height` - Size of the viewport
- `:viewbox` - Internal coordinate system (e.g., `(0 0 100 100)` or `"0 0 100 100"`)
- `:id`, `:class` - Standard SVG attributes

**Examples:**

```lisp
;; With viewBox — origin at bottom-left
(cartesian-frame (:x 50 :y 50 :width 200 :height 200 :viewbox (0 0 100 100))
  (rect (p 0 0) 100 100 :fill "#fff3e0")
  (circle (p 50 50) 30 :fill "#ff5722")
  (text (p 50 95) "y=0 at bottom" :font-size 10 :text-anchor "middle"))

;; Without viewBox — uses pixel coordinates with y-up
(cartesian-frame (:x 50 :y 300 :width 200 :height 100)
  (rect (p 0 0) 200 100 :fill "#fce4ec")
  (circle (p 100 50) 20 :fill "#c2185b"))
```

**How It Works:**

`cartesian-frame` is a macro that wraps content with `<svg>` and applies `transform="translate(0, height) scale(1, -1)"`, flipping the y-axis so that y=0 is at the bottom and positive y goes upward. Text inside cartesian frames will be rendered upside down — use labels sparingly or place them outside the frame.

## 🎨 Path Commands

Use the `path` macro to compose complex paths:

```lisp
(path (commands...) &rest attrs &key &allow-other-keys)
```

### Absolute / Relative Path Commands

| Absolute         | Relative          | Parameters                                           | Description             |
| ---------------- | ----------------- | ---------------------------------------------------- | ----------------------- |
| `moveto`         | `moveto*`         | `(point)` / `(dpoint)`                               | Move to point           |
| `lineto`         | `lineto*`         | `(point)` / `(dpoint)`                               | Draw line to point      |
| `hlineto`        | `hlineto*`        | `(x)` / `(dx)`                                       | Horizontal line         |
| `vlineto`        | `vlineto*`        | `(y)` / `(dy)`                                       | Vertical line           |
| `curveto`        | `curveto*`        | `(p1 p2 p3)` / `(dp1 dp2 dp3)`                       | Cubic Bezier curve      |
| `smooth-curveto` | `smooth-curveto*` | `(p2 p3)` / `(dp2 dp3)`                              | Smooth cubic Bezier     |
| `quadto`         | `quadto*`         | `(p1 p2)` / `(dp1 dp2)`                              | Quadratic Bezier        |
| `smooth-quadto`  | `smooth-quadto*`  | `(point)` / `(dpoint)`                               | Smooth quadratic Bezier |
| `arc`            | `arc*`            | `(radii point &key ...)` / `(radii dpoint &key ...)` | Arc                     |
| `closepath`      | —                 | None                                                 | Close path              |

The absolute and relative command pairs share the same format string, generated by the `def-path-cmd` macro.

### Usage Examples

```lisp
;; Triangle
(path ((moveto (p 150 160))
       (lineto (p 190 220))
       (lineto (p 110 220))
       (closepath))
      :fill "#9b59b6" :opacity 0.7)

;; Bezier heart shape
(path ((moveto (p 320 180))
       (curveto (p 350 160) (p 370 190) (p 340 210))
       (curveto (p 310 230) (p 270 200) (p 270 170))
       (curveto (p 270 140) (p 310 110) (p 340 130))
       (curveto (p 370 150) (p 350 180) (p 320 180))
       (closepath))
      :fill "#e74c3c" :stroke "#c0392b")

;; Quadratic Bezier + Arc
(path ((moveto (p 50 100))
       (quadto (p 100 50) (p 150 100))
       (arc (p 25 25) (p 125 75) :large-arc-flag 1 :sweep-flag 1)
       (closepath))
      :fill "#1abc9c" :stroke "#16a085")
```

## 🔄 Transform Attributes

All shape functions support transform attributes, automatically merged into SVG's `transform`:

| Keyword      | Parameter      | Example                       | Generated             |
| ------------ | -------------- | ----------------------------- | --------------------- |
| `:translate` | Complex number | `:translate (p 10 20)`        | `translate(10,20)`    |
| `:rotate`    | Number or list | `:rotate 45`                  | `rotate(45)`          |
| <br />       | <br />         | `:rotate (list 45 (p cx cy))` | `rotate(45 cx,cy)`    |
| `:scale`     | Number or list | `:scale 2`                    | `scale(2)`            |
| <br />       | <br />         | `:scale (list 2 3)`           | `scale(2,3)`          |
| `:skew-x`    | Number         | `:skew-x 15`                  | `skewX(15)`           |
| `:skew-y`    | Number         | `:skew-y 15`                  | `skewY(15)`           |
| `:matrix`    | List           | `:matrix (list a b c d e f)`  | `matrix(a b c d e f)` |

```lisp
(circle (p 100 100) 50 :fill "#e74c3c" :translate (p 20 30))

(rect (p 50 50) 100 80 :fill "#3498db"
      :translate (p 10 10) :rotate 45 :scale (list 1.5 1.5))

(ellipse (p 200 150) 60 40 :fill "#2ecc71"
         :rotate (list 30 (p 200 150)))
```

## 🎯 Global Attributes System

```lisp
;; Set global attributes
(setf (getf *default-attributes* :stroke) "red")
(setf (getf *default-attributes* :stroke-width) 3)

;; All subsequent shapes inherit
(line (p 50 100) (p 150 100) :marker-end 'my-arrow)

;; Clear
(clear-default-attributes)

;; Global transforms
(setf (getf *default-attributes* :translate) (complex 100 50))
(setf (getf *default-attributes* :rotate) 15)
(setf (getf *default-attributes* :scale) 1.5)
```

### with-attributes Macro

```lisp
(with-attributes (:fill "#e74c3c" :stroke "none")
  (rect (p 10 10) 100 100)
  (circle (p 200 200) 50))
```

### Attribute Priority

1. **Highest** - Function call attributes
2. **Medium** - `with-attributes` block
3. **Lowest** - Global `*default-attributes*`

Global `stroke` affects marker color (via `fill="context-stroke"`):

```lisp
(define-arrow my-arrow)
(setf (getf *default-attributes* :stroke) "purple")
(line (p 50 100) (p 150 100) :marker-end 'my-arrow)
```

## 🏷️ Marker System

### Built-in Marker Types

| Macro               | Description |
| ------------------- | ----------- |
| `define-arrow`      | Arrow       |
| `define-circle-dot` | Circle dot  |
| `define-square-dot` | Square dot  |
| `define-diamond`    | Diamond     |
| `define-triangle`   | Triangle    |
| `define-cross`      | Cross       |
| `define-arrow-open` | Open arrow  |

All arrow-type markers use `fill="context-stroke"` so they inherit the stroke color of the line they're attached to.

### Defining Markers

```lisp
(define-arrow my-arrow)
(define-arrow big-arrow :markerwidth 15 :markerheight 15 :scale 2)
(define-arrow small-arrow :scale 0.5)
(define-arrow wide-arrow :scale '(3 1))   ; x 3x, y unchanged
(define-arrow tall-arrow :scale '(1 3))   ; x unchanged, y 3x
```

### Using Markers

```lisp
;; Direct symbol reference (recommended)
(line (p 50 100) (p 150 100) :marker-start 'my-dot :marker-end 'my-arrow)

;; Using marker-url function
(line (p 50 150) (p 150 150) :marker-end (marker-url 'my-arrow))
```

### Marker Attributes

| Attribute       | Default                             |
| --------------- | ----------------------------------- |
| `:refx`         | 0 (arrow) / 5 (dot)                 |
| `:refy`         | 5                                   |
| `:markerwidth`  | 10                                  |
| `:markerheight` | 10                                  |
| `:orient`       | "auto"                              |
| `:scale`        | 1 (single value or pair `'(sx sy)`) |

### Custom Markers

```lisp
(define-marker my-marker
    "<circle cx=\"5\" cy=\"5\" r=\"5\" fill=\"context-stroke\" />"
  :refx 5 :refy 5 :markerwidth 10 :markerheight 10 :scale 1.5)
```

### Marker Functions

```lisp
(clear-all-markers)   ; Clear all defined markers
(marker-url 'name)    ; Generate url(#name) string
```

## 🔢 LaTeX Math Formula Rendering

```lisp
(latex position formula &rest attrs)
```

**Parameters:** `position` (complex), `formula` (LaTeX string), `:scale` (optional)

**Built-in packages:** `amsmath`, `amssymb`, `physics`

```lisp
(latex (p 160 40) "$E = mc^2$")

(latex (p 160 90) "$\\int_0^\\infty e^{-x^2} dx = \\frac{\\sqrt{\\pi}}{2}$" :scale 0.8)
```

### Setting LaTeX Packages

```lisp
(set-latex-packages "amsmath,amssymb" "physics" "tikz")
(get-latex-packages)
```

### Automatic Cleanup

LaTeX temporary files (`.tex`, `.dvi`, `.svg`, `.aux`, `.log`) are automatically cleaned up after each `latex` call via `unwind-protect`. No manual cleanup is needed.

## 🔧 Utility Functions

### Coordinates

```lisp
(p x y)              ; Create complex point
(x point)            ; Get X coordinate
(y point)            ; Get Y coordinate
```

### Unit Conversion

SVG 标准中 1in = 96px，以下函数将各种单位转换为像素值：

```lisp
(px x)               ; 像素，原样返回
(in x)               ; 英寸，1in = 96px
(cm x)               ; 厘米，1cm = 96/2.54 px
(mm x)               ; 毫米，1mm = 96/25.4 px
(pt x)               ; 磅，1pt = 96/72 px
(pc x)               ; 派卡，1pc = 16px
```

**示例：**

```lisp
(rect (p 10 10) (cm 2) (cm 1) :fill "red")     ; 2cm x 1cm 矩形
(circle (p 100 50) (mm 10) :fill "blue")        ; 半径 10mm 的圆
(ellipse (p 200 100) (in 1) (pt 36) :fill "green") ; 1in x 36pt 椭圆
```

### Transform Helpers

```lisp
(translate tx ty)             ; translate(tx,ty)
(rotate angle &optional cx cy) ; rotate string
(scale sx &optional sy)        ; scale string
(skew-x angle)                 ; skewX string
(skew-y angle)                 ; skewY string
(matrix a b c d e f)           ; matrix string
```

These are generated by the `def-transform` macro.

### Helper Elements

```lisp
(title "text")
(desc "description")
(script content)
(viewbox min-x min-y width height)
```

## 📝 Complete Example

```lisp
(ql:quickload :svg)
(in-package :svg)

(define-arrow my-arrow :scale 1.5)
(define-circle-dot my-dot)

(with-svg ("example.svg" 500 400)
  (title "My First SVG Drawing")
  (desc "A demonstration of the CL-SVG library")

  (setf (getf *default-attributes* :stroke-width) 2)

  (rect (p 0 0) 500 400 :fill "#f0f0f0" :stroke "none")

  (dolist (i '(0 72 144 216 288))
    (let ((angle (* i (/ pi 180)))
          (center (p 250 200)))
      (circle center 40 
              :fill (format nil "hsl(~a,70%,60%)" i)
              :rotate (list angle center))))

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
        :fill "#f1c40f" :stroke "#f39c12")

  (setf (getf *default-attributes* :stroke) "purple")
  (line (p 50 350) (p 200 350) :marker-start 'my-dot :marker-end 'my-arrow)

  (setf (getf *default-attributes* :stroke) "blue")
  (line (p 300 350) (p 450 350) :marker-end 'my-arrow)

  (latex (p 250 320) "$E = mc^2$" :scale 0.8)

  (text (p 250 380) "Star Shape + LaTeX + Markers"
        :font-size 14 :text-anchor "middle" :fill "#333333")

  (clear-default-attributes))
```

## 📁 Project Structure

```
svg/
├── svg.asd           # ASDF system definition (v0.3.0)
├── src/
│   ├── package.lisp  # Package definition and exports
│   ├── utils.lisp    # Utility functions and transform helpers
│   ├── core.lisp     # Core functionality (open/close/with-svg/frame)
│   ├── attributes.lisp # Global attributes system
│   ├── shapes.lisp   # Basic shape primitives
│   ├── text.lisp     # Text elements
│   ├── path.lisp     # Path commands (generated by def-path-cmd)
│   ├── latex.lisp    # LaTeX rendering with auto-cleanup
│   └── marker.lisp   # Marker system (built-in types)
└── test/
    ├── test-shapes.lisp
    ├── test-text.lisp
    ├── test-path.lisp
    ├── test-transforms.lisp
    ├── test-markers.lisp
    ├── test-marker-scale.lisp
    ├── test-global-attributes.lisp
    ├── test-latex.lisp
    ├── test-frame.lisp
    ├── test-units.lisp
    └── test-cartesian.lisp
```

## 🎓 Design Philosophy

1. **Simplicity** - Minimal boilerplate, intuitive API
2. **Consistency** - Unified complex number coordinates and attribute passing
3. **Flexibility** - Transforms, style inheritance, LaTeX, markers
4. **Composability** - Path commands freely combine
5. **Order Guarantee** - Predictable attribute output, transform always last
6. **Leverage Libraries** - Reuse alexandria, cl-ppcre, str, trivia instead of reimplementing
7. **Code Generation** - `def-path-cmd` and `def-transform` macros eliminate repetitive code

***

*This project was generated by* *[TRAE](https://www.trae.ai).*
