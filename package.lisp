(defpackage #:svg
  (:use #:cl)
  (:export
   *svg*
   *default-attributes*
   open-svg close-svg with-svg with-attributes
   set-default-attributes clear-default-attributes
   p x y
   rect circle ellipse line polyline polygon path
   text tspan
   moveto lineto hlineto vlineto curveto smooth-curveto quadto smooth-quadto arc closepath
   moveto* lineto* hlineto* vlineto* curveto* smooth-curveto* quadto* smooth-quadto* arc*
   translate rotate scale skew-x skew-y matrix
   fmt title desc script viewbox
   latex
   *latex-packages*
   set-latex-packages get-latex-packages
   define-marker
   define-arrow define-circle-dot define-square-dot define-diamond
   define-triangle define-cross define-arrow-open
   marker-url clear-all-markers))

(in-package #:svg)

(setf (fdefinition 'p) #'complex)
(setf (fdefinition 'x) #'realpart)
(setf (fdefinition 'y) #'imagpart)
