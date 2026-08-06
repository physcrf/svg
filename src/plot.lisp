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
                            xtics ytics (xmtics 0) (ymtics 0) tic-length)
                      &body body)
  "Create a data-plotting frame (nested SVG) with Cartesian coordinates
and gnuplot-style tics inside the frame box.

:x, :y, :width, :height — frame position and pixel dimensions.
:xmin, :xmax, :ymin, :ymax — data coordinate range.
:xtics, :ytics — tic spec: a number (interval) or a list (start interval end).
:xmtics, :ymtics — number of minor tics between major tics (default 0).
:tic-length — major tic length in pixels (default: min(width,height)/40, auto-scaled).

Inside the body, use (dp x y) to convert data coordinates to pixel coordinates.
Visual sizes (circle radius, stroke-width etc.) are in pixel units."
  (alexandria:with-gensyms (sx sy vb stream xspec yspec tl)
    `(let* ((,tl (or ,tic-length (max 3 (round (/ (min ,width ,height) 40)))))
            (,sx (/ ,width (- ,xmax ,xmin)))
            (,sy (/ ,height (- ,ymax ,ymin)))
            (,vb (viewbox 0 0 ,width ,height))
            (,stream (current-stream))
            (,xspec (parse-tics-spec ,xtics ,xmin ,xmax))
            (,yspec (parse-tics-spec ,ytics ,ymin ,ymax)))
       (labels ((dp (dx dy)
                  (complex (* (- dx ,xmin) ,sx)
                           (* (- ,ymax dy) ,sy)))
                ;; Vertical tic at data x=XI, drawn on the bottom and top edges.
                ;; EXTENT is the inward tic length, already in data-y units.
                (draw-x-tic (xi extent)
                  (line (dp xi ,ymin) (dp xi (+ ,ymin extent))
                        :stroke "black" :stroke-width 1)
                  (line (dp xi ,ymax) (dp xi (- ,ymax extent))
                        :stroke "black" :stroke-width 1))
                ;; Horizontal tic at data y=YI, drawn on the left and right edges.
                ;; EXTENT is the inward tic length, already in data-x units.
                (draw-y-tic (yi extent)
                  (line (dp ,xmin yi) (dp (+ ,xmin extent) yi)
                        :stroke "black" :stroke-width 1)
                  (line (dp ,xmax yi) (dp (- ,xmax extent) yi)
                        :stroke "black" :stroke-width 1)))
         ;; nested SVG with pixel-coordinate viewBox
         (format ,stream "  <svg ")
         (write-attributes ,stream (list :x ,x :y ,y :width ,width :height ,height :viewbox ,vb))
         (format ,stream ">~%")
         ;; frame border
         (rect (dp ,xmin ,ymax) ,width ,height
               :fill "none" :stroke "black" :stroke-width 1)
         ;; x-axis tics on the bottom and top edges.
         ;; ,tl is a pixel length; the y-scale converts it to data-y units.
         (when ,xspec
           (destructuring-bind (xstart xint xend) ,xspec
             (let ((major-extent (* ,tl (/ (- ,ymax ,ymin) ,height))))
               ;; Integer counter + multiplication avoids the floating-point
               ;; accumulation that `loop ... by` suffers from; the small
               ;; epsilon on the bound ensures the final tic (e.g. xint=0.1)
               ;; is not lost to rounding.
               (loop for i from 0
                     for xi = (+ xstart (* i xint))
                     while (<= xi (+ xend 1e-6))
                     do (draw-x-tic xi major-extent))
               ;; minor tics: half as long, skipping every spot a major tic already
               ;; occupies. Since step = xint/(1+xmtics), a major tic lands exactly
               ;; every (1+xmtics) steps — track the step index with an integer
               ;; counter to avoid fragile floating-point `mod` comparisons.
               (when (> ,xmtics 0)
                 (let ((minor-extent (* (/ ,tl 2) (/ (- ,ymax ,ymin) ,height)))
                       (step (/ xint (1+ ,xmtics))))
                   (loop for i from 1
                         for xi = (+ xstart (* i step))
                         while (<= xi (+ xend 1e-6))
                         unless (zerop (mod i (1+ ,xmtics)))
                         do (draw-x-tic xi minor-extent)))))))
         ;; y-axis tics on the left and right edges, mirroring the x-axis logic.
         (when ,yspec
           (destructuring-bind (ystart yint yend) ,yspec
             (let ((major-extent (* ,tl (/ (- ,xmax ,xmin) ,width))))
               (loop for i from 0
                     for yi = (+ ystart (* i yint))
                     while (<= yi (+ yend 1e-6))
                     do (draw-y-tic yi major-extent))
               (when (> ,ymtics 0)
                 (let ((minor-extent (* (/ ,tl 2) (/ (- ,xmax ,xmin) ,width)))
                       (step (/ yint (1+ ,ymtics))))
                   (loop for i from 1
                         for yi = (+ ystart (* i step))
                         while (<= yi (+ yend 1e-6))
                         unless (zerop (mod i (1+ ,ymtics)))
                         do (draw-y-tic yi minor-extent)))))))
         ;; user data plotting forms
         ,@body
         (format ,stream "  </svg>~%")))))