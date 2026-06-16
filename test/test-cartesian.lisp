(ql:quickload :svg :silent t)

(in-package :svg)

;; Comprehensive Cartesian coordinate system comparison
(with-svg ("test/test-cartesian.svg" 900 1020)
  (rect (p 0 0) 900 1020 :fill "#fafafa")
  (text (p 450 22) "Standard SVG vs Cartesian Frame — Coordinate System Comparison"
        :font-size 14 :text-anchor "middle" :font-weight "bold" :fill "#333")

  ;; ============================================================
  ;; Row 1: Basic point comparison
  ;; ============================================================
  (text (p 200 42) "Standard SVG (y increases down)"
        :font-size 11 :text-anchor "middle" :font-weight "bold" :fill "#444")
  (text (p 700 42) "Cartesian (y increases up)"
        :font-size 11 :text-anchor "middle" :font-weight "bold" :fill "#444")

  (frame (:x 50 :y 55 :width 300 :height 300 :viewbox (0 0 100 100))
    (rect (p 0 0) 100 100 :fill "#e3f2fd" :stroke "#1976d2" :stroke-width 1)
    ;; Grid
    (line (p 0 20) (p 100 20) :stroke "#bbdefb" :stroke-width 0.5)
    (line (p 0 40) (p 100 40) :stroke "#bbdefb" :stroke-width 0.5)
    (line (p 0 60) (p 100 60) :stroke "#bbdefb" :stroke-width 0.5)
    (line (p 0 80) (p 100 80) :stroke "#bbdefb" :stroke-width 0.5)
    (line (p 20 0) (p 20 100) :stroke "#bbdefb" :stroke-width 0.5)
    (line (p 40 0) (p 40 100) :stroke "#bbdefb" :stroke-width 0.5)
    (line (p 60 0) (p 60 100) :stroke "#bbdefb" :stroke-width 0.5)
    (line (p 80 0) (p 80 100) :stroke "#bbdefb" :stroke-width 0.5)
    ;; Axes
    (line (p 10 10) (p 90 10) :stroke "#1976d2" :stroke-width 1)
    (line (p 10 10) (p 10 90) :stroke "#1976d2" :stroke-width 1)
    ;; y arrow (points down)
    (line (p 80 15) (p 80 80) :stroke "#333" :stroke-width 1)
    (polygon (list (p 80 80) (p 77 70) (p 83 70)) :fill "#333")
    (text (p 84 55) "y" :font-size 9 :fill "#333")
    ;; Points
    (circle (p 25 25) 5 :fill "#e74c3c")
    (text (p 25 18) "(25,25)" :font-size 8 :text-anchor "middle" :fill "#e74c3c")
    (circle (p 70 25) 5 :fill "#e67e22")
    (text (p 70 18) "(70,25)" :font-size 8 :text-anchor "middle" :fill "#e67e22")
    (circle (p 25 70) 5 :fill "#27ae60")
    (text (p 25 82) "(25,70)" :font-size 8 :text-anchor "middle" :fill "#27ae60")
    (circle (p 70 70) 5 :fill "#8e44ad")
    (text (p 70 82) "(70,70)" :font-size 8 :text-anchor "middle" :fill "#8e44ad"))

  (text (p 200 365) "y=0 at top, y=100 at bottom"
        :font-size 9 :text-anchor "middle" :fill "#666")

  (cartesian-frame (:x 550 :y 55 :width 300 :height 300 :viewbox (0 0 100 100))
    (rect (p 0 0) 100 100 :fill "#fff3e0" :stroke "#f57c00" :stroke-width 1)
    (line (p 0 20) (p 100 20) :stroke "#ffe0b2" :stroke-width 0.5)
    (line (p 0 40) (p 100 40) :stroke "#ffe0b2" :stroke-width 0.5)
    (line (p 0 60) (p 100 60) :stroke "#ffe0b2" :stroke-width 0.5)
    (line (p 0 80) (p 100 80) :stroke "#ffe0b2" :stroke-width 0.5)
    (line (p 20 0) (p 20 100) :stroke "#ffe0b2" :stroke-width 0.5)
    (line (p 40 0) (p 40 100) :stroke "#ffe0b2" :stroke-width 0.5)
    (line (p 60 0) (p 60 100) :stroke "#ffe0b2" :stroke-width 0.5)
    (line (p 80 0) (p 80 100) :stroke "#ffe0b2" :stroke-width 0.5)
    (line (p 10 10) (p 90 10) :stroke "#f57c00" :stroke-width 1)
    (line (p 10 10) (p 10 90) :stroke "#f57c00" :stroke-width 1)
    (line (p 80 15) (p 80 80) :stroke "#333" :stroke-width 1)
    (polygon (list (p 80 80) (p 77 70) (p 83 70)) :fill "#333")
    (text (p 84 55) "y" :font-size 9 :fill "#333")
    (circle (p 25 75) 5 :fill "#e74c3c")
    (text (p 25 68) "(25,75)" :font-size 8 :text-anchor "middle" :fill "#e74c3c")
    (circle (p 70 75) 5 :fill "#e67e22")
    (text (p 70 68) "(70,75)" :font-size 8 :text-anchor "middle" :fill "#e67e22")
    (circle (p 25 30) 5 :fill "#27ae60")
    (text (p 25 42) "(25,30)" :font-size 8 :text-anchor "middle" :fill "#27ae60")
    (circle (p 70 30) 5 :fill "#8e44ad")
    (text (p 70 42) "(70,30)" :font-size 8 :text-anchor "middle" :fill "#8e44ad"))

  (text (p 700 365) "y=0 at bottom, y=100 at top"
        :font-size 9 :text-anchor "middle" :fill "#666")

  ;; ============================================================
  ;; Row 2: Line slopes
  ;; ============================================================
  (text (p 200 390) "Standard SVG — y=x, y=40, x=60"
        :font-size 11 :text-anchor "middle" :font-weight "bold" :fill "#444")
  (text (p 700 390) "Cartesian — y=x, y=40, x=60"
        :font-size 11 :text-anchor "middle" :font-weight "bold" :fill "#444")

  (frame (:x 50 :y 405 :width 300 :height 300 :viewbox (0 0 100 100))
    (rect (p 0 0) 100 100 :fill "#fbe9e7" :stroke "#d84315" :stroke-width 1)
    (line (p 0 20) (p 100 20) :stroke "#ffccbc" :stroke-width 0.5)
    (line (p 0 40) (p 100 40) :stroke "#ffccbc" :stroke-width 0.5)
    (line (p 0 60) (p 100 60) :stroke "#ffccbc" :stroke-width 0.5)
    (line (p 0 80) (p 100 80) :stroke "#ffccbc" :stroke-width 0.5)
    (line (p 20 0) (p 20 100) :stroke "#ffccbc" :stroke-width 0.5)
    (line (p 40 0) (p 40 100) :stroke "#ffccbc" :stroke-width 0.5)
    (line (p 60 0) (p 60 100) :stroke "#ffccbc" :stroke-width 0.5)
    (line (p 80 0) (p 80 100) :stroke "#ffccbc" :stroke-width 0.5)
    ;; y=x slopes down (in SVG)
    (line (p 0 0) (p 90 90) :stroke "#d84315" :stroke-width 2.5)
    ;; y=40 (from top)
    (line (p 0 40) (p 90 40) :stroke "#1565c0" :stroke-width 2)
    ;; x=60
    (line (p 60 0) (p 60 90) :stroke "#2e7d32" :stroke-width 2)
    (text (p 5 7) "y=x" :font-size 8 :fill "#d84315" :font-weight "bold")
    (text (p 5 38) "y=40" :font-size 8 :fill "#1565c0" :font-weight "bold")
    (text (p 61 7) "x=60" :font-size 8 :fill "#2e7d32" :font-weight "bold"))

  (text (p 200 715) "y=x slopes downward; y=40 near top; x=60 vertical"
        :font-size 8 :text-anchor "middle" :fill "#666")

  (cartesian-frame (:x 550 :y 405 :width 300 :height 300 :viewbox (0 0 100 100))
    (rect (p 0 0) 100 100 :fill "#fbe9e7" :stroke "#d84315" :stroke-width 1)
    (line (p 0 20) (p 100 20) :stroke "#ffccbc" :stroke-width 0.5)
    (line (p 0 40) (p 100 40) :stroke "#ffccbc" :stroke-width 0.5)
    (line (p 0 60) (p 100 60) :stroke "#ffccbc" :stroke-width 0.5)
    (line (p 0 80) (p 100 80) :stroke "#ffccbc" :stroke-width 0.5)
    (line (p 20 0) (p 20 100) :stroke "#ffccbc" :stroke-width 0.5)
    (line (p 40 0) (p 40 100) :stroke "#ffccbc" :stroke-width 0.5)
    (line (p 60 0) (p 60 100) :stroke "#ffccbc" :stroke-width 0.5)
    (line (p 80 0) (p 80 100) :stroke "#ffccbc" :stroke-width 0.5)
    ;; y=x slopes up (in Cartesian)
    (line (p 0 0) (p 90 90) :stroke "#d84315" :stroke-width 2.5)
    ;; y=40 (from bottom)
    (line (p 0 40) (p 90 40) :stroke "#1565c0" :stroke-width 2)
    ;; x=60
    (line (p 60 0) (p 60 90) :stroke "#2e7d32" :stroke-width 2)
    (text (p 5 7) "y=x" :font-size 8 :fill "#d84315" :font-weight "bold")
    (text (p 5 38) "y=40" :font-size 8 :fill "#1565c0" :font-weight "bold")
    (text (p 61 7) "x=60" :font-size 8 :fill "#2e7d32" :font-weight "bold"))

  (text (p 700 715) "y=x slopes upward; y=40 near bottom; x=60 vertical"
        :font-size 8 :text-anchor "middle" :fill "#666")

  ;; ============================================================
  ;; Row 3: Extra Cartesian demos (3 panels)
  ;; ============================================================
  (text (p 450 740) "More Cartesian demos (y always increases up)"
        :font-size 11 :text-anchor "middle" :font-weight "bold" :fill "#444")

  ;; --- Panel 1: House ---
  (cartesian-frame (:x 50 :y 755 :width 210 :height 210 :viewbox "0 0 100 100")
    (rect (p 0 0) 100 100 :fill "#f3e5f5" :stroke "#7b1fa2" :stroke-width 1)
    (line (p 0 25) (p 100 25) :stroke "#ce93d8" :stroke-width 0.5)
    (line (p 0 50) (p 100 50) :stroke "#ce93d8" :stroke-width 0.5)
    (line (p 0 75) (p 100 75) :stroke "#ce93d8" :stroke-width 0.5)
    (line (p 25 0) (p 25 100) :stroke "#ce93d8" :stroke-width 0.5)
    (line (p 50 0) (p 50 100) :stroke "#ce93d8" :stroke-width 0.5)
    (line (p 75 0) (p 75 100) :stroke "#ce93d8" :stroke-width 0.5)
    (polygon (list (p 20 40) (p 50 70) (p 80 40)) :fill "#9b59b6" :stroke "#8e44ad" :stroke-width 1)
    (rect (p 30 40) 40 50 :fill "#e8daef" :stroke "#8e44ad" :stroke-width 1)
    (rect (p 45 60) 10 30 :fill "#8e44ad")
    (rect (p 33 48) 8 8 :fill "#f5b041")
    (line (p 5 10) (p 95 10) :stroke "#27ae60" :stroke-width 2)
    (text (p 50 5) "ground (y=0)" :font-size 7 :text-anchor "middle" :fill "#27ae60"))

  (text (p 155 975) "House: y=ground, shapes sit on it"
        :font-size 8 :text-anchor "middle" :fill "#7b1fa2")

  ;; --- Panel 2: Function plot ---
  (cartesian-frame (:x 345 :y 755 :width 210 :height 210 :viewbox "0 0 100 100")
    (rect (p 0 0) 100 100 :fill "#e0f2f1" :stroke "#00695c" :stroke-width 1)
    (line (p 0 20) (p 100 20) :stroke "#b2dfdb" :stroke-width 0.5)
    (line (p 0 40) (p 100 40) :stroke "#b2dfdb" :stroke-width 0.5)
    (line (p 0 60) (p 100 60) :stroke "#b2dfdb" :stroke-width 0.5)
    (line (p 0 80) (p 100 80) :stroke "#b2dfdb" :stroke-width 0.5)
    (line (p 20 0) (p 20 100) :stroke "#b2dfdb" :stroke-width 0.5)
    (line (p 40 0) (p 40 100) :stroke "#b2dfdb" :stroke-width 0.5)
    (line (p 60 0) (p 60 100) :stroke "#b2dfdb" :stroke-width 0.5)
    (line (p 80 0) (p 80 100) :stroke "#b2dfdb" :stroke-width 0.5)
    ;; Origin at center (50,50)
    (line (p 5 50) (p 95 50) :stroke "#00695c" :stroke-width 1.5)
    (line (p 50 5) (p 50 95) :stroke "#00695c" :stroke-width 1.5)
    (text (p 95 52) "x" :font-size 8 :fill "#00695c" :font-weight "bold")
    (text (p 48 98) "y" :font-size 8 :fill "#00695c" :font-weight "bold")
    ;; y = x^2 (parabola)
    (circle (p 10 1)  3 :fill "#d32f2f")
    (circle (p 20 4)  3 :fill "#d32f2f")
    (circle (p 30 9)  3 :fill "#d32f2f")
    (circle (p 40 16) 3 :fill "#d32f2f")
    (circle (p 50 25) 3 :fill "#d32f2f")
    (circle (p 60 36) 3 :fill "#d32f2f")
    (circle (p 70 49) 3 :fill "#d32f2f")
    (circle (p 80 64) 3 :fill "#d32f2f")
    (circle (p 90 81) 3 :fill "#d32f2f")
    (path ((moveto (p 10 1))
           (lineto (p 20 4))
           (lineto (p 30 9))
           (lineto (p 40 16))
           (lineto (p 50 25))
           (lineto (p 60 36))
           (lineto (p 70 49))
           (lineto (p 80 64))
           (lineto (p 90 81)))
          :stroke "#d32f2f" :stroke-width 1.5 :fill "none")
    (text (p 10 98) "y=x/100" :font-size 7 :fill "#d32f2f"))

  (text (p 450 975) "Function: y = x^2 (parabola, origin at center)"
        :font-size 8 :text-anchor "middle" :fill "#00695c")

  ;; --- Panel 3: Concentric circles ---
  (cartesian-frame (:x 640 :y 755 :width 210 :height 210 :viewbox "0 0 100 100")
    (rect (p 0 0) 100 100 :fill "#fffde7" :stroke "#f9a825" :stroke-width 1)
    (line (p 0 20) (p 100 20) :stroke "#fff9c4" :stroke-width 0.5)
    (line (p 0 40) (p 100 40) :stroke "#fff9c4" :stroke-width 0.5)
    (line (p 0 60) (p 100 60) :stroke "#fff9c4" :stroke-width 0.5)
    (line (p 0 80) (p 100 80) :stroke "#fff9c4" :stroke-width 0.5)
    (line (p 20 0) (p 20 100) :stroke "#fff9c4" :stroke-width 0.5)
    (line (p 40 0) (p 40 100) :stroke "#fff9c4" :stroke-width 0.5)
    (line (p 60 0) (p 60 100) :stroke "#fff9c4" :stroke-width 0.5)
    (line (p 80 0) (p 80 100) :stroke "#fff9c4" :stroke-width 0.5)
    ;; Concentric circles centered at (50,50)
    (circle (p 50 50) 40 :fill "none" :stroke "#f9a825" :stroke-width 1.5)
    (circle (p 50 50) 28 :fill "none" :stroke "#f57f17" :stroke-width 1.5)
    (circle (p 50 50) 16 :fill "none" :stroke "#fbc02d" :stroke-width 1.5)
    (circle (p 50 50) 6 :fill "#fbc02d" :stroke "#f9a825" :stroke-width 1)
    ;; Axes through center
    (line (p 5 50) (p 95 50) :stroke "#f9a825" :stroke-width 0.5 :stroke-dasharray "3,2")
    (line (p 50 5) (p 50 95) :stroke "#f9a825" :stroke-width 0.5 :stroke-dasharray "3,2")
    (text (p 50 5) "center (50,50)" :font-size 7 :text-anchor "middle" :fill "#f57f17"))

  (text (p 745 975) "Circles: center at (50,50), y up"
        :font-size 8 :text-anchor "middle" :fill "#f9a825"))

(format t "Generated test/test-cartesian.svg~%")
