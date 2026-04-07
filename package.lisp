(defpackage #:svg
  (:use #:cl)
  (:export
   *svg*
   *default-attributes*
   open-svg close-svg with-svg with-attributes
   set-default-attributes
   get-default-attributes
   clear-default-attributes
   p x y
   rect circle ellipse line polyline polygon path
   text tspan
   moveto lineto hlineto vlineto curveto smooth-curveto quadto smooth-quadto arc closepath
   moveto* lineto* hlineto* vlineto* curveto* smooth-curveto* quadto* smooth-quadto* arc*
   path-data
   translate rotate scale skew-x skew-y matrix
   fmt title desc script viewbox
   latex
   *latex-packages*
   set-latex-packages get-latex-packages
   with-latex-env cleanup-all-latex
   define-marker
   define-arrow define-circle-dot define-square-dot define-diamond
   define-triangle define-cross define-arrow-open define-arrow-filled
   *markers* *used-markers*
   register-marker find-marker use-marker
   emit-marker-defs reset-markers clear-all-markers))

(in-package #:svg)

(setf (fdefinition 'p)  #'complex)
(setf (fdefinition 'x)  #'realpart)
(setf (fdefinition 'y)  #'imagpart)
