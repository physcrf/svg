(defpackage #:svg
  (:use #:cl)
  (:export
   *svg*
   *default-attributes*
   open-svg close-svg with-svg with-attributes
   set-default-attributes clear-default-attributes
   p x y
   rect circle ellipse line polyline polygon path
   text frame cartesian-frame plot-frame
   moveto lineto hlineto vlineto curveto smooth-curveto quadto smooth-quadto arc closepath
   moveto* lineto* hlineto* vlineto* curveto* smooth-curveto* quadto* smooth-quadto* arc*
   translate rotate scale skew-x skew-y matrix
   title desc script viewbox
   px in cm mm pt pc
   latex
   *latex-packages*
   set-latex-packages get-latex-packages
   define-marker
   define-arrow define-circle-dot define-square-dot define-diamond
   define-triangle define-cross define-arrow-open
   marker-url clear-all-markers))

(in-package #:svg)

(defun p (x y)
  "Create a 2D point as a complex number."
  (complex x y))

(defun x (point)
  "Get the X coordinate (real part) of a point."
  (realpart point))

(defun y (point)
  "Get the Y coordinate (imaginary part) of a point."
  (imagpart point))
