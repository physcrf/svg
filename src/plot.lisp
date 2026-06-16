(in-package #:svg)

;;; Data plotting frame with gnuplot-style tics inside the frame box.

(defun parse-tics-spec (spec range-min range-max)
  "Parse a tics spec into (start interval end).
SPEC can be:
  - a number: used as interval, range-min to range-max
  - a list (start interval end): gnuplot format
  - NIL: returns NIL"
  (when spec
    (if (listp spec)
        spec
        (list range-min spec range-max))))

(defmacro plot-frame ((&key x y width height xmin xmax ymin ymax
                            xtics ytics (xmtics 0) (ymtics 0) (tic-length 5))
                      &body body)
  "Create a data-plotting frame (nested SVG) with Cartesian coordinates
and gnuplot-style tics inside the frame box.

:x, :y, :width, :height — frame position and pixel dimensions.
:xmin, :xmax, :ymin, :ymax — data coordinate range.
:xtics, :ytics — tic spec: a number (interval) or a list (start interval end).
:xmtics, :ymtics — number of minor tics between major tics (default 0).
:tic-length — major tic length in pixels (default 5).

Inside the body, use (dp x y) to convert data coordinates to pixel coordinates.
Visual sizes (circle radius, stroke-width etc.) are in pixel units."
  (let ((sx (gensym "SX"))
        (sy (gensym "SY"))
        (vb (gensym "VB"))
        (stream (gensym "STREAM"))
        (xspec (gensym "XSPEC"))
        (yspec (gensym "YSPEC")))
    `(let* ((,sx (/ ,width (- ,xmax ,xmin)))
            (,sy (/ ,height (- ,ymax ,ymin)))
            (,vb (viewbox 0 0 ,width ,height))
            (,stream (current-stream))
            (,xspec (parse-tics-spec ,xtics ,xmin ,xmax))
            (,yspec (parse-tics-spec ,ytics ,ymin ,ymax)))
       (flet ((dp (dx dy)
                (complex (* (- dx ,xmin) ,sx)
                         (* (- ,ymax dy) ,sy))))
         ;; nested SVG with pixel-coordinate viewBox
         (format ,stream "  <svg ")
         (write-attributes ,stream (list :x ,x :y ,y :width ,width :height ,height :viewbox ,vb))
         (format ,stream ">~%")
         ;; frame border
         (rect (dp ,xmin ,ymax) ,width ,height
               :fill "none" :stroke "black" :stroke-width 1)
         ;; xtics — bottom edge (upward) and top edge (downward)
         (when ,xspec
           (destructuring-bind (xstart xint xend) ,xspec
             (let ((dx (* ,tic-length (/ (- ,ymax ,ymin) ,height))))
               (loop for xi from (+ xstart xint) to xend by xint
                     do (line (dp xi ,ymin) (dp xi (+ ,ymin dx))
                              :stroke "black" :stroke-width 1)
                        (line (dp xi ,ymax) (dp xi (- ,ymax dx))
                              :stroke "black" :stroke-width 1))
               ;; xmtics — minor tics
               (when (> ,xmtics 0)
                 (let ((mdx (* (/ ,tic-length 2) (/ (- ,ymax ,ymin) ,height)))
                       (step (/ xint (1+ ,xmtics))))
                   (loop for xi from (+ xstart step) below xend by step
                         unless (zerop (mod (- xi xstart) xint))
                         do (line (dp xi ,ymin) (dp xi (+ ,ymin mdx))
                                  :stroke "black" :stroke-width 1)
                            (line (dp xi ,ymax) (dp xi (- ,ymax mdx))
                                  :stroke "black" :stroke-width 1)))))))
         ;; ytics — left edge (rightward) and right edge (leftward)
         (when ,yspec
           (destructuring-bind (ystart yint yend) ,yspec
             (let ((dx (* ,tic-length (/ (- ,xmax ,xmin) ,width))))
               (loop for yi from (+ ystart yint) to yend by yint
                     do (line (dp ,xmin yi) (dp (+ ,xmin dx) yi)
                              :stroke "black" :stroke-width 1)
                        (line (dp ,xmax yi) (dp (- ,xmax dx) yi)
                              :stroke "black" :stroke-width 1))
               ;; ymtics — minor tics
               (when (> ,ymtics 0)
                 (let ((mdx (* (/ ,tic-length 2) (/ (- ,xmax ,xmin) ,width)))
                       (step (/ yint (1+ ,ymtics))))
                   (loop for yi from (+ ystart step) below yend by step
                         unless (zerop (mod (- yi ystart) yint))
                         do (line (dp ,xmin yi) (dp (+ ,xmin mdx) yi)
                                  :stroke "black" :stroke-width 1)
                            (line (dp ,xmax yi) (dp (- ,xmax mdx) yi)
                                  :stroke "black" :stroke-width 1)))))))
         ;; user data plotting forms
         ,@body
         (format ,stream "  </svg>~%")))))