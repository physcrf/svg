(ql:quickload :svg :silent t)

(in-package :svg)

;; Test data-plotting frame with gnuplot-style tics inside the frame box.
(with-svg ("test/test-plot.svg" 800 700)
  (rect (p 0 0) 800 700 :fill "white")
  (text (p 400 22) "plot-frame — gnuplot-style tics inside frame"
        :font-size 16 :text-anchor "middle" :font-weight "bold" :fill "#333")

  ;; ============================================================
  ;; Example 1: Simple sine wave with minor tics
  ;; ============================================================
  (plot-frame (:x 50 :y 50 :width 340 :height 300
               :xmin 0 :xmax 10 :ymin -1.5 :ymax 1.5
               :xtics 2 :ytics 0.5 :xmtics 4 :ymtics 4)
    ;; sine curve
    (path ((moveto (dp 0 0))
           (lineto (dp 0.5 0.479))
           (lineto (dp 1.0 0.841))
           (lineto (dp 1.5 0.997))
           (lineto (dp 2.0 0.909))
           (lineto (dp 2.5 0.598))
           (lineto (dp 3.0 0.141))
           (lineto (dp 3.5 -0.351))
           (lineto (dp 4.0 -0.757))
           (lineto (dp 4.5 -0.977))
           (lineto (dp 5.0 -0.959))
           (lineto (dp 5.5 -0.706))
           (lineto (dp 6.0 -0.279))
           (lineto (dp 6.5 0.215))
           (lineto (dp 7.0 0.657))
           (lineto (dp 7.5 0.938))
           (lineto (dp 8.0 0.989))
           (lineto (dp 8.5 0.798))
           (lineto (dp 9.0 0.412))
           (lineto (dp 9.5 -0.075))
           (lineto (dp 10.0 -0.544)))
          :stroke "#d32f2f" :stroke-width 2 :fill "none")
    ;; data points
    (circle (dp 1.57 1.0) 4 :fill "#d32f2f")
    (circle (dp 4.71 -1.0) 4 :fill "#d32f2f")
    (circle (dp 7.85 1.0) 4 :fill "#d32f2f"))

  (text (p 220 365) "y = sin(x)" :font-size 12 :text-anchor "middle" :fill "#d32f2f")

  ;; ============================================================
  ;; Example 2: Linear data with scatter points
  ;; ============================================================
  (plot-frame (:x 420 :y 50 :width 340 :height 300
               :xmin 0 :xmax 100 :ymin 0 :ymax 100
               :xtics 20 :ytics 20)
    ;; y = 0.8x + 10 reference line
    (line (dp 0 10) (dp 100 90) :stroke "#1976d2" :stroke-width 1.5 :stroke-dasharray "4,3")
    ;; scatter points
    (circle (dp 10 20) 3 :fill "#e65100")
    (circle (dp 20 22) 3 :fill "#e65100")
    (circle (dp 30 35) 3 :fill "#e65100")
    (circle (dp 40 45) 3 :fill "#e65100")
    (circle (dp 50 48) 3 :fill "#e65100")
    (circle (dp 60 55) 3 :fill "#e65100")
    (circle (dp 70 70) 3 :fill "#e65100")
    (circle (dp 80 72) 3 :fill "#e65100")
    (circle (dp 90 80) 3 :fill "#e65100"))

  (text (p 590 365) "y = 0.8x + 10" :font-size 12 :text-anchor "middle" :fill "#1976d2")

  ;; ============================================================
  ;; Example 3: Large-range data with fine tics
  ;; ============================================================
  (plot-frame (:x 50 :y 400 :width 340 :height 250
               :xmin -5 :xmax 5 :ymin 0 :ymax 25
               :xtics 1 :ytics 5)
    ;; y = x^2 parabola
    (path ((moveto (dp -5 25))
           (lineto (dp -4.5 20.25))
           (lineto (dp -4 16))
           (lineto (dp -3.5 12.25))
           (lineto (dp -3 9))
           (lineto (dp -2.5 6.25))
           (lineto (dp -2 4))
           (lineto (dp -1.5 2.25))
           (lineto (dp -1 1))
           (lineto (dp -0.5 0.25))
           (lineto (dp 0 0))
           (lineto (dp 0.5 0.25))
           (lineto (dp 1 1))
           (lineto (dp 1.5 2.25))
           (lineto (dp 2 4))
           (lineto (dp 2.5 6.25))
           (lineto (dp 3 9))
           (lineto (dp 3.5 12.25))
           (lineto (dp 4 16))
           (lineto (dp 4.5 20.25))
           (lineto (dp 5 25)))
          :stroke "#2e7d32" :stroke-width 2 :fill "none"))

  (text (p 220 665) "y = x^2" :font-size 12 :text-anchor "middle" :fill "#2e7d32")

  ;; ============================================================
  ;; Example 4: Fine tics
  ;; ============================================================
  (plot-frame (:x 420 :y 400 :width 340 :height 250
               :xmin 0 :xmax 6.28 :ymin -1 :ymax 1
               :xtics 1.57 :ytics 0.5)
    ;; cosine curve
    (path ((moveto (dp 0 1.0))
           (lineto (dp 0.5 0.877))
           (lineto (dp 1.0 0.540))
           (lineto (dp 1.5 0.071))
           (lineto (dp 2.0 -0.416))
           (lineto (dp 2.5 -0.801))
           (lineto (dp 3.0 -0.990))
           (lineto (dp 3.5 -0.937))
           (lineto (dp 4.0 -0.654))
           (lineto (dp 4.5 -0.211))
           (lineto (dp 5.0 0.284))
           (lineto (dp 5.5 0.709))
           (lineto (dp 6.0 0.960))
           (lineto (dp 6.28 1.0)))
          :stroke "#6a1b9a" :stroke-width 2 :fill "none"))

  (text (p 590 665) "y = cos(x) (no border)" :font-size 12 :text-anchor "middle" :fill "#6a1b9a"))

(format t "Generated test/test-plot.svg~%")