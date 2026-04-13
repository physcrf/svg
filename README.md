# CL-SVG - A Common Lisp SVG Generation Library

An AI-generated Common Lisp library for generating SVG (Scalable Vector Graphics) files with LaTeX math formula rendering and custom marker system.

## ✨ Features

- **Complex Number Coordinates** - Use complex numbers to represent 2D coordinate points, clean and intuitive
- **Global SVG Stream Mode** - No need to explicitly pass SVG objects
- **with-svg Macro** - Automatic file opening and closing management
- **Direct Transform Attributes** - Use `:translate`, `:rotate`, `:scale` keywords directly
- **Path Macro Syntax** - Intuitive path command composition
- **Global Attributes System** - Support global default attributes with dynamic modification
- **Marker System** - Built-in marker types with scaling and customization
- **LaTeX Formula Rendering** - Convert LaTeX to SVG via dvisvgm
- **Pattern Matching** - Elegant pattern matching using trivia library

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

### Using with-svg Macro (Recommended)

```lisp
(in-package :svg)

(with-svg ("output.svg" 400 300)
  (rect (p 10 10) 100 60 :fill "#3498db")
  (circle (p 200 100) 30 :fill "#e74c3c")
  (text (p 150 200) "Hello SVG!" :font-size 24 :fill "black"))
```

### Using open-svg/close-svg

```lisp
(in-package :svg)

(open-svg "output.svg" 400 300)
(rect (p 10 10) 100 60 :fill "#3498db")
(circle (p 200 100) 30 :fill "#e74c3c")
(close-svg)
```

### Complex Number Coordinate System

```lisp
;; Create points
(p x y)           ; Create complex point (e.g., (p 10 20))
(x point)         ; Get X coordinate (real part)
(y point)         ; Get Y coordinate (imaginary part)

;; Example
(let ((center (p 150 100)))
  (circle center 50))  ; Draw circle with radius 50 at (150, 100)
```

## 📐 Shape Elements

### Basic Shapes

All shape functions support `&key &rest &allow-other-keys`, accepting SVG attributes.

#### rect - Rectangle

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
(rect (p 10 10) 100 60 :fill "#3498db")              ; Normal rectangle
(rect (p 20 20) 80 80 :rx 10 :ry 10 :fill "#e74c3c") ; Rounded rectangle
```

#### circle - Circle

```lisp
(circle center radius &key &rest attrs &allow-other-keys)
```

**Example:**
```lisp
(circle (p 100 100) 50 :fill "#e74c3c" :stroke "#2c3e50" :stroke-width 2)
```

#### ellipse - Ellipse

```lisp
(ellipse center rx ry &key &rest attrs &allow-other-keys)
```

**Example:**
```lisp
(ellipse (p 150 100) 80 40 :fill "#2ecc71")
```

#### line - Line

```lisp
(line start end &key &rest attrs &allow-other-keys)
```

**Example:**
```lisp
(line (p 0 0) (p 100 100) :stroke "#2c3e50" :stroke-width 2)
```

#### polyline - Polyline

```lisp
(polyline points-list &key &rest attrs &allow-other-keys)
```

**Example:**
```lisp
(polyline (list (p 10 10) (p 50 30) (p 90 10))
          :stroke "#3498db" :fill "none")
```

#### polygon - Polygon

```lisp
(polygon points-list &key &rest attrs &allow-other-keys)
```

**Example:**
```lisp
(polygon (list (p 50 10) (p 90 90) (p 10 90))
         :fill "#f39c12")
```

### Text Elements

#### text - Text

```lisp
(text position content &rest attrs &key &allow-other-keys)
```

**Examples:**
```lisp
(text (p 100 200) "Hello, World!"
      :font-size 24 :font-family "Arial" :fill "#2c3e50")

(text (p 100 250) "中文测试"
      :font-size 18 :fill "darkblue")

(text (p 100 300) "Bold Text"
      :font-size 16 :font-weight "bold" :fill "red")
```

#### tspan - Text Span

```lisp
(tspan content &rest attrs &key &allow-other-keys)
```

**Special Keyword Arguments:**
- `:position` - Position (complex number)
- `:dx`, `:dy` - Relative offset
- `:rotate` - Rotation angle

**Example:**
```lisp
(text (p 100 250) nil :font-size 16)
(tspan "Bold text" :font-weight "bold" :fill "#e74c3c")
(tspan " normal text" :font-weight "normal")
```

## 🎨 Path Commands

Use the `path` macro to create complex paths:

```lisp
(path (commands...) &rest attrs &key &allow-other-keys)
```

### Absolute Path Commands

| Command | Parameters | Description |
|---------|------------|-------------|
| `moveto` | `(point)` | Move to point |
| `lineto` | `(point)` | Draw line to point |
| `hlineto` | `(x)` | Horizontal line to x |
| `vlineto` | `(y)` | Vertical line to y |
| `curveto` | `(p1 p2 p3)` | Cubic Bezier curve |
| `smooth-curveto` | `(p2 p3)` | Smooth cubic Bezier |
| `quadto` | `(p1 p2)` | Quadratic Bezier curve |
| `smooth-quadto` | `(point)` | Smooth quadratic Bezier |
| `arc` | `(radii point &key ...)` | Arc |
| `closepath` | None | Close path |

### Relative Path Commands (with * suffix)

| Command | Parameters | Description |
|---------|------------|-------------|
| `moveto*` | `(dpoint)` | Relative move |
| `lineto*` | `(dpoint)` | Relative line |
| `hlineto*` | `(dx)` | Relative horizontal line |
| `vlineto*` | `(dy)` | Relative vertical line |
| `curveto*` | `(dp1 dp2 dp3)` | Relative cubic Bezier |
| `smooth-curveto*` | `(dp2 dp3)` | Relative smooth cubic Bezier |
| `quadto*` | `(dp1 dp2)` | Relative quadratic Bezier |
| `smooth-quadto*` | `(dpoint)` | Relative smooth quadratic Bezier |
| `arc*` | `(radii dpoint &key ...)` | Relative arc |

### Usage Examples

```lisp
;; Triangle
(path ((moveto (p 150 160))
       (lineto (p 190 220))
       (lineto (p 110 220))
       (closepath))
      :fill "#9b59b6"
      :opacity 0.7)

;; Bezier curve heart shape
(path ((moveto (p 320 180))
       (curveto (p 350 160) (p 370 190) (p 340 210))
       (curveto (p 310 230) (p 270 200) (p 270 170))
       (curveto (p 270 140) (p 310 110) (p 340 130))
       (curveto (p 370 150) (p 350 180) (p 320 180))
       (closepath))
      :fill "#e74c3c"
      :stroke "#c0392b")

;; Quadratic Bezier + Arc
(path ((moveto (p 50 100))
       (quadto (p 100 50) (p 150 100))
       (arc (p 25 25) (p 125 75) :large-arc-flag 1 :sweep-flag 1)
       (closepath))
      :fill "#1abc9c"
      :stroke "#16a085")
```

## 🔄 Transform Attributes

All shape functions support transform attributes, which are automatically merged into SVG's `transform` attribute:

### Available Transform Keywords

| Keyword | Parameter Type | Example | Generated SVG |
|---------|---------------|---------|---------------|
| `:translate` | Complex number | `:translate (p 10 20)` | `translate(10,20)` |
| `:rotate` | Number or list | `:rotate 45` | `rotate(45)` |
| | | `:rotate (list 45 (p cx cy))` | `rotate(45 cx,cy)` |
| `:scale` | Number or list | `:scale 2` | `scale(2)` |
| | | `:scale (list 2 3)` | `scale(2,3)` |
| `:skew-x` | Number | `:skew-x 15` | `skewX(15)` |
| `:skew-y` | Number | `:skew-y 15` | `skewY(15)` |
| `:matrix` | List | `:matrix (list a b c d e f)` | `matrix(a b c d e f)` |

### Usage Examples

```lisp
;; Single transform
(circle (p 100 100) 50 :fill "#e74c3c" :translate (p 20 30))

;; Combined transforms (applied in order)
(rect (p 50 50) 100 80 :fill "#3498db"
      :translate (p 10 10)
      :rotate 45
      :scale (list 1.5 1.5))

;; Rotation with center point
(ellipse (p 200 150) 60 40 :fill "#2ecc71"
         :rotate (list 30 (p 200 150)))
```

## 🎯 Global Attributes System

### Setting Global Attributes with setf

```lisp
;; Set global attributes
(setf (getf *default-attributes* :stroke) "red")
(setf (getf *default-attributes* :stroke-width) 3)

;; All subsequent shapes inherit these attributes
(line (p 50 100) (p 150 100) 
      :marker-end 'my-arrow)  ; Automatically gets stroke="red" stroke-width="3"

;; Clear global attributes
(clear-default-attributes)
```

### Setting Global Transforms

```lisp
;; Global translate
(setf (getf *default-attributes* :translate) (complex 100 50))

;; Global rotate
(setf (getf *default-attributes* :rotate) 15)

;; Global scale
(setf (getf *default-attributes* :scale) 1.5)
```

### with-attributes Macro

Temporarily override or extend default attributes:

```lisp
(with-attributes (:fill "#e74c3c" :stroke "none")
  ;; Shapes in this block use :fill "#e74c3c" and :stroke "none"
  (rect (p 10 10) 100 100)
  (circle (p 200 200) 50))
```

### Attribute Priority

1. **Highest Priority** - Attributes passed to function call
2. **Medium Priority** - Attributes set by `with-attributes` macro
3. **Lowest Priority** - Global default attributes (`*default-attributes*`)

### Global Attributes and Markers

Global `stroke` attribute affects marker color because markers use `fill="context-stroke"`:

```lisp
(define-arrow my-arrow)
(setf (getf *default-attributes* :stroke) "purple")
(line (p 50 100) (p 150 100) :marker-end 'my-arrow)
;; Arrow becomes purple
```

## 🏷️ Marker System

### Built-in Marker Types

| Macro | Description |
|-------|-------------|
| `define-arrow` | Arrow |
| `define-circle-dot` | Circle dot |
| `define-square-dot` | Square dot |
| `define-diamond` | Diamond |
| `define-triangle` | Triangle |
| `define-cross` | Cross |
| `define-arrow-open` | Open arrow |
| `define-arrow-filled` | Filled arrow |

### Defining Markers

```lisp
;; Basic definition
(define-arrow my-arrow)

;; Definition with parameters
(define-arrow big-arrow :markerwidth 15 :markerheight 15 :scale 2)

;; Scaled markers
(define-arrow small-arrow :scale 0.5)
(define-arrow wide-arrow :scale '(3 1))   ; x scaled 3x, y unchanged
(define-arrow tall-arrow :scale '(1 3))   ; x unchanged, y scaled 3x
```

### Using Markers

```lisp
;; Use markers at line endpoints (direct symbol reference)
(line (p 50 100) (p 150 100) 
      :stroke "black" :stroke-width 2
      :marker-start 'my-dot
      :marker-end 'my-arrow)

;; Can also use marker-url function
(line (p 50 150) (p 150 150)
      :stroke "blue" :stroke-width 2
      :marker-end (marker-url 'my-arrow))
```

### Marker Attributes

| Attribute | Description | Default |
|-----------|-------------|---------|
| `:refx` | Reference point X | 0 (arrow) / 5 (dot) |
| `:refy` | Reference point Y | 5 |
| `:markerwidth` | Marker width | 10 |
| `:markerheight` | Marker height | 10 |
| `:viewbox` | View box | "0 0 width height" |
| `:orient` | Orientation | "auto" |
| `:scale` | Scale | 1 |

### scale Attribute

`scale` can accept:
- **Single value** - Same scale for x and y
- **Pair of values** - Separate x and y scales

```lisp
(define-arrow s1 :scale 0.5)      ; Uniform scale down
(define-arrow s2 :scale 2)        ; Uniform scale up
(define-arrow s3 :scale '(3 1))   ; Wide arrow
(define-arrow s4 :scale '(1 3))   ; Tall arrow
```

### Custom Markers

```lisp
(define-marker my-marker
    "<circle cx=\"5\" cy=\"5\" r=\"5\" fill=\"context-stroke\" />"
  :refx 5 :refy 5
  :markerwidth 10 :markerheight 10
  :scale 1.5)
```

### Marker Management Functions

```lisp
(clear-all-markers)   ; Clear all defined markers
(reset-markers)       ; Reset used markers list
(find-marker 'name)   ; Find marker
(use-marker 'name)    ; Use marker (add to used list)
(marker-url 'name)    ; Generate url(#name) string
```

## 🔢 LaTeX Math Formula Rendering

Render LaTeX math formulas to SVG elements via the `latex` function.

### latex Function

```lisp
(latex position formula &rest attrs)
```

**Parameters:**
- `position` - Formula position (complex number)
- `formula` - LaTeX string
- `:scale` - Scale factor (optional)

**Built-in packages:** `amsmath`, `amssymb`, `physics`

**Examples:**

```lisp
;; Simple formula
(latex (p 160 40) "$E = mc^2$")

;; Integral formula
(latex (p 160 90) "$\\int_0^\\infty e^{-x^2} dx = \\frac{\\sqrt{\\pi}}{2}$"
       :scale 0.8)

;; Maxwell equations
(latex (p 160 140) "$\\nabla \\times \\vec{E} = -\\frac{\\partial \\vec{B}}{\\partial t}$"
       :scale 0.7)
```

### Setting LaTeX Packages

```lisp
(set-latex-packages "amsmath,amssymb" "physics" "tikz")
(get-latex-packages)  ; Get current package list
```

### with-latex-env Macro

Automatically manage LaTeX temporary file lifecycle:

```lisp
(with-latex-env
  (with-svg ("output-with-math.svg" 400 300)
    (rect (p 0 0) 400 300 :fill "white")
    (latex (p 200 150) "$\\sum_{i=1}^{n} x_i^2$")))
;; Automatically cleans up all temporary files
```

### Cleanup Function

```lisp
(cleanup-all-latex)  ; Clean all LaTeX temporary directories and files
```

## 🔧 Utility Functions

### Coordinates and Formatting

```lisp
(p x y)              ; Create complex point
(x point)            ; Get X coordinate
(y point)            ; Get Y coordinate
(fmt number)         ; Format number (integers without decimals, floats with 2 decimals)
```

### Transform Helper Functions

```lisp
(translate tx ty)    ; Generate translate(tx,ty) string
(rotate angle &optional cx cy)  ; Generate rotate string
(scale sx &optional sy)         ; Generate scale string
(skew-x angle)      ; Generate skewX string
(skew-y angle)      ; Generate skewY string
(matrix a b c d e f) ; Generate matrix string
```

### Helper Elements

```lisp
(title "text")        ; Add <title> element
(desc "description")  ; Add <desc> element
(script content)      ; Add <script> element
(viewbox min-x min-y width height)  ; Generate viewBox string
```

## 📝 Complete Example

```lisp
(ql:quickload :svg)
(in-package :svg)

;; Define markers
(define-arrow my-arrow :scale 1.5)
(define-circle-dot my-dot)

;; Create SVG file
(with-svg ("example.svg" 500 400)
  
  ;; Add title and description
  (title "My First SVG Drawing")
  (desc "A demonstration of the CL-SVG library")
  
  ;; Set global attributes
  (setf (getf *default-attributes* :stroke-width) 2)
  
  ;; Draw background
  (rect (p 0 0) 500 400 :fill "#f0f0f0" :stroke "none")
  
  ;; Draw decorative circles (with transforms)
  (dolist (i '(0 72 144 216 288))
    (let ((angle (* i (/ pi 180)))
          (center (p 250 200)))
      (circle center 40 
              :fill (format nil "hsl(~a,70%,60%)" i)
              :rotate (list angle center))))
  
  ;; Draw star path
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
  
  ;; Draw lines with markers
  (setf (getf *default-attributes* :stroke) "purple")
  (line (p 50 350) (p 200 350) 
        :marker-start 'my-dot
        :marker-end 'my-arrow)
  
  (setf (getf *default-attributes* :stroke) "blue")
  (line (p 300 350) (p 450 350)
        :marker-end 'my-arrow)
  
  ;; Add LaTeX formula
  (latex (p 250 320) "$E = mc^2$" :scale 0.8)
  
  ;; Add text label
  (text (p 250 380) "Star Shape + LaTeX + Markers"
        :font-size 14 :text-anchor "middle" :fill "#333333")
  
  ;; Clear global attributes
  (clear-default-attributes))
```

## 📁 Project Structure

```
svg/
├── svg.asd          # ASDF system definition (v0.3.0)
├── package.lisp     # Package definition and exports
├── utils.lisp       # Utility functions
├── core.lisp        # Core functionality (open/close/with-svg/serialize)
├── attributes.lisp  # Attributes system
├── shapes.lisp      # Basic shapes
├── text.lisp        # Text elements
├── path.lisp        # Path commands
├── latex.lisp       # LaTeX rendering support
├── marker.lisp      # Marker system
└── test/            # Test files
    ├── test-shapes.lisp
    ├── test-text.lisp
    ├── test-path.lisp
    ├── test-transforms.lisp
    ├── test-markers.lisp
    ├── test-marker-scale.lisp
    └── test-global-attributes.lisp
```

## 🎓 Design Philosophy

1. **Simplicity** - Minimal boilerplate code, intuitive API
2. **Consistency** - All functions use unified complex number coordinate system and attribute passing
3. **Flexibility** - Support transforms, style inheritance, LaTeX, markers and other advanced features
4. **Composability** - Path macro allows free combination of various path commands
5. **Order Guarantee** - Predictable attribute output order, transform always last

---

*This project was generated by [TRAE](https://www.trae.ai) with [GLM-5](https://www.zhipuai.cn/)*
