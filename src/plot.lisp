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
        (progn
          (assert (= (length spec) 3) (spec)
                  "Tics spec list must have exactly 3 elements (start interval end), got ~a" spec)
          spec)
        (list range-min spec range-max))))

(defmacro plot-frame ((&key x y width height xmin xmax ymin ymax
                            xtics ytics (xmtics 0) (ymtics 0) tic-length
                            prebody)
                      &body body)
  "Create a data-plotting frame (nested SVG) with Cartesian coordinates
and gnuplot-style tics inside the frame box.

:x, :y, :width, :height — frame position and pixel dimensions.
:xmin, :xmax, :ymin, :ymax — data coordinate range.
:xtics, :ytics — tic spec: a number (interval) or a list (start interval end).
:xmtics, :ymtics — number of minor tics between major tics (default 0).
:tic-length — major tic length in pixels (default: min(width,height)/40, auto-scaled).
:prebody — drawing forms emitted BEFORE the frame border and tics (e.g. an
opaque background band that must not cover the border/tics).

Inside the body, use (dp x y) to convert data coordinates to pixel coordinates.
Visual sizes (circle radius, stroke-width etc.) are in pixel units."
  (alexandria:with-gensyms (sx sy vb stream xspec yspec tl)
    `(let* ((,tl (or ,tic-length (max 3 (round (/ (min ,width ,height) 40)))))
            (,sx (if (= ,xmax ,xmin) 1 (/ ,width (- ,xmax ,xmin))))
            (,sy (if (= ,ymax ,ymin) 1 (/ ,height (- ,ymax ,ymin))))
            (,vb (viewbox 0 0 ,width ,height))
            (,stream (current-stream))
            (,xspec (parse-tics-spec ,xtics ,xmin ,xmax))
            (,yspec (parse-tics-spec ,ytics ,ymin ,ymax)))
       (assert (and (> ,width 0) (> ,height 0)) ()
               "Plot frame width and height must be positive, got ~a x ~a" ,width ,height)
       (labels ((dp (dx dy)
                  (complex (* (- dx ,xmin) ,sx)
                           (* (- ,ymax dy) ,sy)))
                ;; Vertical tic at data x=XI, drawn on the bottom and top edges.
                ;; EXTENT is the inward tic length, already in data-y units.
                (draw-x-tic (xi extent)
                  ;; clip to the data range: a spec end (e.g. 1.6) may lie
                  ;; beyond xmax — gnuplot drops such tics rather than
                  ;; drawing them outside the frame box.
                  (when (and (>= xi ,xmin) (<= xi ,xmax))
                    (line (dp xi ,ymin) (dp xi (+ ,ymin extent))
                          :stroke "black" :stroke-width 1)
                    (line (dp xi ,ymax) (dp xi (- ,ymax extent))
                          :stroke "black" :stroke-width 1)))
                ;; Horizontal tic at data y=YI, drawn on the left and right edges.
                ;; EXTENT is the inward tic length, already in data-x units.
                (draw-y-tic (yi extent)
                  (when (and (>= yi ,ymin) (<= yi ,ymax))
                    (line (dp ,xmin yi) (dp (+ ,xmin extent) yi)
                          :stroke "black" :stroke-width 1)
                    (line (dp ,xmax yi) (dp (- ,xmax extent) yi)
                          :stroke "black" :stroke-width 1)))
                ;; Shared tic loop for both axes. SPEC is (start interval end);
                ;; a major tic is drawn every INTERVAL, with MTICKS minor tics in
                ;; between. DRAW is called as (DRAW POS EXTENT) for each tic.
                (emit-tics (spec mticks major-extent minor-extent draw)
                  (destructuring-bind (start interval end) spec
                    ;; A non-positive interval (e.g. :xtics 0) would keep the tic
                    ;; positions from ever advancing and hang the loop — skip tics.
                    (when (plusp interval)
                      ;; Integer counter + multiplication avoids the floating-point
                      ;; accumulation that `loop ... by` suffers from; the small
                      ;; epsilon on the bound ensures the final tic (e.g. 0.1)
                      ;; is not lost to rounding.
                      (loop for i from 0
                            for pos = (+ start (* i interval))
                            while (<= pos (+ end 1e-6))
                            do (funcall draw pos major-extent))
                      ;; Minor tics are half as long, skipping every spot a major
                      ;; tic already occupies. Since step = interval/(1+mticks), a
                      ;; major tic lands exactly every (1+mticks) steps — track the
                      ;; step index with an integer counter to avoid fragile
                      ;; floating-point `mod` comparisons.
                      (when (> mticks 0)
                        (let ((step (/ interval (1+ mticks))))
                          (loop for i from 1
                                for pos = (+ start (* i step))
                                while (<= pos (+ end 1e-6))
                                unless (zerop (mod i (1+ mticks)))
                                do (funcall draw pos minor-extent))))))))
         ;; nested SVG with pixel-coordinate viewBox; overflow=visible so that
         ;; labels drawn outside the frame box (axis labels, tick numbers,
         ;; legends placed by root-canvas coordinates) are not clipped.
         (format ,stream "  <svg ")
         (write-attributes ,stream (list :x ,x :y ,y :width ,width :height ,height :viewbox ,vb
                                         :overflow "visible"))
         (format ,stream ">~%")
         ;; user background forms (drawn before border/tics so they stay
         ;; underneath)
         ,@prebody
         ;; frame border
         (rect (dp ,xmin ,ymax) ,width ,height
               :fill "none" :stroke "black" :stroke-width 1)
         ;; x-axis tics on the bottom and top edges.
         ;; ,tl is a pixel length; the y-scale converts it to data-y units.
         (when ,xspec
           (let ((y-scale (/ (- ,ymax ,ymin) ,height)))
             (emit-tics ,xspec ,xmtics
                        (abs (* ,tl y-scale))
                        (abs (* (/ ,tl 2) y-scale))
                        #'draw-x-tic)))
         ;; y-axis tics on the left and right edges, mirroring the x-axis logic.
         (when ,yspec
           (let ((x-scale (/ (- ,xmax ,xmin) ,width)))
             (emit-tics ,yspec ,ymtics
                        (abs (* ,tl x-scale))
                        (abs (* (/ ,tl 2) x-scale))
                        #'draw-y-tic)))
         ;; user data plotting forms
         ,@body
         (format ,stream "  </svg>~%")))))
