# SVG — A Common Lisp SVG Generation Library

A Common Lisp library for generating SVG (Scalable Vector Graphics) files, with LaTeX math rendering and a custom marker system.

## ✨ Features

- **Complex-number coordinates** — represent 2D points as complex numbers; clean and intuitive.
- **Global stream mode** — no need to thread an SVG object through every call.
- **`with-svg` macro** — automatic file open/close and `<defs>` emission.
- **Nested SVG frames** — sub-viewports with independent coordinate systems.
- **Cartesian frame** — a dedicated macro for y-up (mathematical) coordinates.
- **Direct transform attributes** — `:translate`, `:rotate`, `:scale`, etc. as plain keywords.
- **Path macro syntax** — compose paths from intuitive command forms.
- **Global attributes system** — shared defaults with dynamic, scoped overrides.
- **Marker system** — built-in marker types with per-reference scaling.
- **LaTeX rendering** — compile LaTeX to SVG via `dvisvgm` and embed it inline.
- **Pattern matching** — elegant dispatch via the `trivia` library.
- **Built on** `alexandria`, `cl-ppcre`, `str`, `trivia`, `serapeum`.

## 📦 Installation

### Dependencies

- `alexandria` — general utilities
- `cl-ppcre` — regular expressions
- `str` — string processing
- `trivia` — pattern matching
- `serapeum` — utilities

### Steps

Place the library in Quicklisp's `local-projects` directory, then load it:

```bash
cd ~/.quicklisp/local-projects
# place the svg/ folder here
```

```lisp
(ql:quickload :svg)
```

### LaTeX prerequisites (optional)

LaTeX rendering requires a TeX distribution and `dvisvgm`:

```bash
sudo apt install texlive dvisvgm
```

## 🚀 Quick Start

### Using `with-svg` (recommended)

```lisp
(in-package :svg)

(with-svg ("output.svg" 400 300)
  (rect (p 10 10) 100 60 :fill "#3498db")
  (circle (p 200 100) 30 :fill "#e74c3c")
  (text (p 150 200) "Hello SVG!" :font-size 24 :fill "black"))
```

> **Error safety:** `with-svg` emits the `<defs>` block and closing `</svg>` tag
> even when the body signals an error, leaving a well-formed (partial) file on
> disk that can be inspected for debugging, and the marker registry is reset so
> it never leaks into the next document.

### Using `open-svg` / `close-svg` (manual control)

```lisp
(in-package :svg)

(open-svg "output.svg" 400 300)

(rect (p 10 10) 100 60 :fill "#3498db")
(circle (p 200 100) 30 :fill "#e74c3c")
(text (p 150 200) "Hello SVG!" :font-size 24 :fill "black")

(close-svg)
```

`open-svg` / `close-svg` are useful when you need fine-grained control over the SVG lifecycle — for example, when generating content across several functions or in a REPL-driven workflow.

## 📍 Coordinates

Points are represented as complex numbers: the real part is X, the imaginary part is Y.

```lisp
(p x y)           ; create a point, e.g. (p 10 20)
(x point)         ; get the X coordinate (realpart)
(y point)         ; get the Y coordinate (imagpart)

(let ((center (p 150 100)))
  (circle center 50))   ; circle of radius 50 at (150, 100)
```

## 📐 Shape Elements

All shape functions accept `&rest` keyword attributes, which are rendered directly as SVG attributes.

### rect

```lisp
(rect position width height &key rx ry &rest attrs &allow-other-keys)
```

- `position` — top-left corner (complex)
- `width`, `height` — dimensions
- `:rx`, `:ry` — corner radii (optional)

```lisp
(rect (p 10 10) 100 60 :fill "#3498db")
(rect (p 20 20) 80 80 :rx 10 :ry 10 :fill "#e74c3c")
```

### circle

```lisp
(circle center radius &key &rest attrs &allow-other-keys)
```

```lisp
(circle (p 100 100) 50 :fill "#e74c3c" :stroke "#2c3e50" :stroke-width 2)
```

### ellipse

```lisp
(ellipse center rx ry &key &rest attrs &allow-other-keys)
```

```lisp
(ellipse (p 150 100) 80 40 :fill "#2ecc71")
```

### line

```lisp
(line start end &key &rest attrs &allow-other-keys)
```

```lisp
(line (p 0 0) (p 100 100) :stroke "#2c3e50" :stroke-width 2)
```

### polyline / polygon

```lisp
(polyline points &key &rest attrs &allow-other-keys)
(polygon  points &key &rest attrs &allow-other-keys)
```

```lisp
(polyline (list (p 10 10) (p 50 30) (p 90 10)) :stroke "#3498db" :fill "none")
(polygon  (list (p 50 10) (p 90 90) (p 10 90)) :fill "#f39c12")
```

### text

```lisp
(text position content &rest attrs &key &allow-other-keys)
```

```lisp
(text (p 100 200) "Hello, World!" :font-size 24 :font-family "Arial")
(text (p 100 250) "中文测试" :font-size 18 :fill "darkblue")
(text (p 100 300) "Bold Text" :font-size 16 :font-weight "bold" :fill "red")
```

## 🖼️ Frames & Coordinate Systems

### frame — sub-viewport

Create a nested `<svg>` element with its own coordinate system.

```lisp
(frame attributes &body body)
```

Common attributes: `:x`, `:y`, `:width`, `:height`, `:viewBox`, `:id`, `:class`.

```lisp
;; A sub-viewport with its own coordinate system
(frame (:x 50 :y 50 :width 150 :height 150 :viewbox "0 0 100 100")
  (rect (p 0 0) 100 100 :fill "#e3f2fd")
  (circle (p 50 50) 30 :fill "#ff5722")
  (text (p 50 80) "Frame 1" :font-size 12 :text-anchor "middle"))

;; Frames can be nested
(frame (:x 50 :y 220 :width 300 :height 60 :viewbox "0 0 300 60")
  (rect (p 0 0) 300 60 :fill "#f3e5f5")
  (frame (:x 10 :y 10 :width 80 :height 40 :viewbox "0 0 40 20")
    (rect (p 0 0) 40 20 :fill "#e1bee7")
    (text (p 20 14) "Nested" :font-size 8 :text-anchor "middle"))
  (text (p 150 35) "Outer frame" :font-size 12 :text-anchor "middle"))
```

### cartesian-frame — y-up coordinates

Create a nested `<svg>` with Cartesian coordinates (Y points up). The macro wraps the body in `<g transform="translate(0,h) scale(1,-1)">` to flip the Y axis.

```lisp
(cartesian-frame attributes &body body)
```

`:viewBox` accepts either a string (`"0 0 100 100"`) or a list (`(0 0 100 100)`).

```lisp
;; With viewBox — origin at the bottom-left
(cartesian-frame (:x 50 :y 50 :width 200 :height 200 :viewbox (0 0 100 100))
  (rect (p 0 0) 100 100 :fill "#fff3e0")
  (circle (p 50 50) 30 :fill "#ff5722")
  (text (p 50 95) "y=0 at bottom" :font-size 10 :text-anchor "middle"))

;; Without viewBox — pixel coordinates with y-up
(cartesian-frame (:x 50 :y 300 :width 200 :height 100)
  (rect (p 0 0) 200 100 :fill "#fce4ec")
  (circle (p 100 50) 20 :fill "#c2185b"))
```

> **Note:** Because the Y axis is flipped, text rendered inside a `cartesian-frame` appears upside down. Place labels outside the frame, or use them sparingly.

### plot-frame — data plotting

Create a data-plotting frame with automatic data→pixel coordinate conversion and gnuplot-style inward tics.

```lisp
(plot-frame (&key x y width height xmin xmax ymin ymax
                  xtics ytics (xmtics 0) (ymtics 0) tic-length)
  &body body)
```

**Parameters:**

- `:x`, `:y` — position in the parent viewport (pixels)
- `:width`, `:height` — size of the plotting area (pixels)
- `:xmin`, `:xmax`, `:ymin`, `:ymax` — data coordinate range
- `:xtics`, `:ytics` — major tic spec: a number (interval) or a list `(start interval end)`
- `:xmtics`, `:ymtics` — number of minor tics between majors (default `0`)
- `:tic-length` — major tic length in pixels (default `max(3, round(min(width, height) / 40))`)

Inside the body, use `(dp x y)` to convert data coordinates to pixel coordinates. Visual sizes (circle radii, stroke widths, etc.) remain in pixel units.

```lisp
;; Sine wave
(with-svg ("sine.svg" 600 400)
  (plot-frame (:x 50 :y 50 :width 500 :height 300
                  :xmin 0 :xmax 10 :ymin -1.5 :ymax 1.5
                  :xtics 2 :ytics 0.5)
    (path ((moveto (dp 0 0))
           (lineto (dp 1 0.841))
           (lineto (dp 2 0.909))
           (lineto (dp 3 0.141))
           (lineto (dp 4 -0.757))
           (lineto (dp 5 -0.959))
           (lineto (dp 6 -0.279))
           (lineto (dp 7 0.657))
           (lineto (dp 8 0.989))
           (lineto (dp 9 0.412))
           (lineto (dp 10 -0.544)))
          :stroke "#d32f2f" :stroke-width 2 :fill "none")
    (circle (dp 1.57 1.0) 4 :fill "#d32f2f")
    (circle (dp 4.71 -1.0) 4 :fill "#d32f2f")
    (circle (dp 7.85 1.0) 4 :fill "#d32f2f")))

;; Minor tics and a custom tic spec
(with-svg ("plot-with-minor-tics.svg" 600 400)
  (plot-frame (:x 50 :y 50 :width 500 :height 300
                  :xmin 0 :xmax 100 :ymin 0 :ymax 100
                  :xtics '(0 20 100) :ytics 20
                  :xmtics 4 :ymtics 4)
    (line (dp 0 10) (dp 100 90) :stroke "#1976d2" :stroke-width 1.5 :stroke-dasharray "4,3")
    (circle (dp 10 20) 3 :fill "#e65100")
    (circle (dp 30 35) 3 :fill "#e65100")
    (circle (dp 50 48) 3 :fill "#e65100")
    (circle (dp 70 70) 3 :fill "#e65100")
    (circle (dp 90 80) 3 :fill "#e65100")))
```

## 🎨 Path Commands

Compose complex paths with the `path` macro:

```lisp
(path (commands...) &rest attrs &key &allow-other-keys)
```

### Absolute / relative commands

| Absolute         | Relative          | Parameters                                           | Description             |
| ---------------- | ----------------- | ---------------------------------------------------- | ----------------------- |
| `moveto`         | `moveto*`         | `(point)` / `(dpoint)`                               | Move to point           |
| `lineto`         | `lineto*`         | `(point)` / `(dpoint)`                               | Draw line to point      |
| `hlineto`        | `hlineto*`        | `(x)` / `(dx)`                                       | Horizontal line         |
| `vlineto`        | `vlineto*`        | `(y)` / `(dy)`                                       | Vertical line           |
| `curveto`        | `curveto*`        | `(p1 p2 p3)` / `(dp1 dp2 dp3)`                       | Cubic Bézier curve      |
| `smooth-curveto` | `smooth-curveto*` | `(p2 p3)` / `(dp2 dp3)`                              | Smooth cubic Bézier     |
| `quadto`         | `quadto*`         | `(p1 p2)` / `(dp1 dp2)`                              | Quadratic Bézier        |
| `smooth-quadto`  | `smooth-quadto*`  | `(point)` / `(dpoint)`                               | Smooth quadratic Bézier |
| `arc`            | `arc*`            | `(radii point &key ...)` / `(radii dpoint &key ...)` | Arc                     |
| `closepath`      | —                 | None                                                 | Close path              |

Each absolute/relative pair shares a single format string, generated by the `def-path-cmd` macro.

```lisp
;; Triangle
(path ((moveto (p 150 160))
       (lineto (p 190 220))
       (lineto (p 110 220))
       (closepath))
      :fill "#9b59b6" :opacity 0.7)

;; Bézier heart
(path ((moveto (p 320 180))
       (curveto (p 350 160) (p 370 190) (p 340 210))
       (curveto (p 310 230) (p 270 200) (p 270 170))
       (curveto (p 270 140) (p 310 110) (p 340 130))
       (curveto (p 370 150) (p 350 180) (p 320 180))
       (closepath))
      :fill "#e74c3c" :stroke "#c0392b")

;; Quadratic Bézier + arc
(path ((moveto (p 50 100))
       (quadto (p 100 50) (p 150 100))
       (arc (p 25 25) (p 125 75) :large-arc-flag 1 :sweep-flag 1)
       (closepath))
      :fill "#1abc9c" :stroke "#16a085")
```

## 🔄 Transform Attributes

All shape functions accept transform keywords, which are merged into a single SVG `transform` attribute (always emitted last).

| Keyword      | Parameter      | Example                       | Generated             |
| ------------ | -------------- | ----------------------------- | --------------------- |
| `:translate` | Complex number | `:translate (p 10 20)`        | `translate(10,20)`    |
| `:rotate`    | Number or list | `:rotate 45`                  | `rotate(45)`          |
|              |                | `:rotate (list 45 (p cx cy))` | `rotate(45 cx,cy)`    |
| `:scale`     | Number or list | `:scale 2`                    | `scale(2)`            |
|              |                | `:scale (list 2 3)`           | `scale(2,3)`          |
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

Default attributes are held in `*default-attributes*` and inherited by every subsequent element. They can be set globally or scoped with `with-attributes`.

```lisp
;; Set global defaults field by field
(setf (getf *default-attributes* :stroke) "red")
(setf (getf *default-attributes* :stroke-width) 3)

;; All subsequent shapes inherit them
(line (p 50 100) (p 150 100) :marker-end 'my-arrow)

(clear-default-attributes)                       ; clear defaults
(set-default-attributes :stroke "red" :stroke-width 3)  ; or set them all at once
```

### with-attributes

```lisp
(with-attributes (:fill "#e74c3c" :stroke "none")
  (rect (p 10 10) 100 100)
  (circle (p 200 200) 50))
```

### Attribute priority

1. **Highest** — attributes passed to the function call
2. **Medium** — the enclosing `with-attributes` block
3. **Lowest** — global `*default-attributes*`

A global `stroke` also drives marker color (via `fill="context-stroke"`):

```lisp
(define-arrow my-arrow)
(setf (getf *default-attributes* :stroke) "purple")
(line (p 50 100) (p 150 100) :marker-end 'my-arrow)
```

## 🏷️ Marker System

### Built-in marker types

| Macro               | Description      |
| ------------------- | ---------------- |
| `define-arrow`      | Filled arrow     |
| `define-circle-dot` | Filled circle    |
| `define-square-dot` | Filled square    |
| `define-diamond`    | Filled diamond   |
| `define-triangle`   | Filled triangle  |
| `define-cross`      | Cross (plus)     |
| `define-arrow-open` | Open (hollow) arrow |

All arrow/dot markers use `fill="context-stroke"` (or `stroke="context-stroke"`), so they inherit the color of the line they are attached to.

### Defining markers

```lisp
(define-arrow my-arrow)
(define-arrow big-arrow :markerwidth 15 :markerheight 15 :scale 2)
(define-arrow small-arrow :scale 0.5)
(define-arrow wide-arrow :scale '(3 1))    ; x scaled 3×, y unchanged
(define-arrow tall-arrow :scale '(1 3))    ; x unchanged, y scaled 3×
```

### Using markers

```lisp
;; Direct symbol reference (recommended)
(line (p 50 100) (p 150 100) :marker-start 'my-dot :marker-end 'my-arrow)

;; Keyword references also work (matched case-insensitively)
(line (p 50 200) (p 150 200) :marker-end :my-arrow)

;; Explicit url() string
(line (p 50 150) (p 150 150) :marker-end (marker-url 'my-arrow))
```

### Marker attributes

| Attribute       | Default                                              |
| --------------- | ---------------------------------------------------- |
| `:refx`         | shape-dependent (`0` for arrows, `w/2` for dots)     |
| `:refy`         | shape-dependent (e.g. `h/2`)                          |
| `:markerwidth`  | 10                                                   |
| `:markerheight` | 10                                                   |
| `:orient`       | `"auto"`                                             |
| `:scale`        | 1 (a number, or a pair `'(sx sy)`)                   |

### Custom markers

```lisp
(define-marker my-marker
    "<circle cx=\"5\" cy=\"5\" r=\"5\" fill=\"context-stroke\" />"
  :refx 5 :refy 5 :markerwidth 10 :markerheight 10 :scale 1.5)
```

### Marker functions

```lisp
(clear-all-markers)      ; clear all defined markers
(marker-url 'name)       ; generate the url(#name) reference string
```

## 🔢 LaTeX Math Rendering

```lisp
(latex position formula &rest attrs)
```

- `position` — placement (complex)
- `formula` — a LaTeX string
- `:scale` — optional scaling factor

The default packages are `amsmath`, `amssymb`, and `physics`.

```lisp
(latex (p 160 40) "$E = mc^2$")

(latex (p 160 90) "$\\int_0^\\infty e^{-x^2} dx = \\frac{\\sqrt{\\pi}}{2}$" :scale 0.8)
```

### Setting LaTeX packages

```lisp
(set-latex-packages "amsmath,amssymb" "physics" "tikz")
(get-latex-packages)
```

### Automatic cleanup

Each `latex` call writes a `.tex` file, compiles it to `.dvi`, converts it to `.svg`, embeds the inner content, and then removes every temporary file (`.tex`, `.dvi`, `.svg`, `.aux`, `.log`) via `unwind-protect`. No manual cleanup is needed.

## 🔧 Utility Functions

### Coordinates

```lisp
(p x y)       ; create a complex point
(x point)     ; get the X coordinate
(y point)     ; get the Y coordinate
```

### Unit conversion

Per the SVG standard, `1in = 96px`. The following functions convert each unit to pixels:

```lisp
(px x)   ; pixels        — returned as-is
(in x)   ; inches        (1in = 96px)
(cm x)   ; centimeters   (1cm = 96/2.54 px)
(mm x)   ; millimeters   (1mm = 96/25.4 px)
(pt x)   ; points        (1pt = 96/72 px)
(pc x)   ; picas         (1pc = 16px)
```

```lisp
(rect (p 10 10) (cm 2) (cm 1) :fill "red")           ; 2cm × 1cm rectangle
(circle (p 100 50) (mm 10) :fill "blue")             ; radius 10mm
(ellipse (p 200 100) (in 1) (pt 36) :fill "green")   ; 1in × 36pt
```

### Transform helpers

```lisp
(translate tx ty)              ; "translate(tx,ty)"
(rotate angle &optional cx cy) ; "rotate(angle)" or "rotate(angle cx,cy)"
(scale sx &optional sy)        ; "scale(sx)" or "scale(sx,sy)"
(skew-x angle)                 ; "skewX(angle)"
(skew-y angle)                 ; "skewY(angle)"
(matrix a b c d e f)           ; "matrix(a b c d e f)"
```

`translate`, `skew-x`, and `skew-y` are generated by the `def-transform` macro.

### Helper elements

```lisp
(title "text")
(desc "description")
(script content)                    ; content is written verbatim (no XML escaping)
(viewbox min-x min-y width height)   ; build a viewBox attribute value
```

`script` writes its content verbatim without XML escaping, so JavaScript such as
`if (a < b && c > d) { ... }` can be embedded directly.

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
├── svg.asd              # ASDF system definition (v0.3.0)
├── src/
│   ├── package.lisp     # package definition and exports
│   ├── utils.lisp       # utilities (points, fmt), transform and unit helpers
│   ├── attributes.lisp  # global attributes system
│   ├── marker.lisp      # marker system (built-in types)
│   ├── core.lisp        # core: open/close/with-svg, frame, attribute serialization
│   ├── shapes.lisp      # shape primitives and text
│   ├── path.lisp        # path commands (generated by def-path-cmd)
│   ├── latex.lisp       # LaTeX rendering with auto-cleanup
│   └── plot.lisp        # data plotting frame
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
    ├── test-cartesian.lisp
    └── test-plot.lisp
```

## 🎓 Design Philosophy

1. **Simplicity** — minimal boilerplate, intuitive API.
2. **Consistency** — unified complex-number coordinates and attribute passing.
3. **Flexibility** — transforms, style inheritance, LaTeX, markers.
4. **Composability** — path commands combine freely.
5. **Order guarantee** — predictable attribute output; `transform` is always last.
6. **Leverage libraries** — reuse `alexandria`, `cl-ppcre`, `str`, `trivia`, `serapeum` instead of reimplementing.
7. **Code generation** — `def-path-cmd` and `def-transform` macros eliminate repetitive code.

---

*This project was generated by [TRAE](https://www.trae.ai).*
