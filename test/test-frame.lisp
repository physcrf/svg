(ql:quickload :svg :silent t)

(in-package :svg)

;; Test nested SVG frames (sub-viewport)
(with-svg ("test/test-frame.svg" 400 300)
  ;; Background
  (rect (p 0 0) 400 300 :fill "white")

  ;; Main frame with its own coordinate system
  (frame (:x 50 :y 50 :width 150 :height 150 :viewbox "0 0 100 100")
    ;; In this frame, coordinates go from 0-100
    (rect (p 0 0) 100 100 :fill "#e3f2fd" :stroke "#1976d2" :stroke-width 2)
    (circle (p 50 50) 30 :fill "#ff5722")
    (text (p 50 80) "Frame 1" :font-size 12 :text-anchor "middle"))

  ;; Another frame with different viewBox
  (frame (:x 250 :y 50 :width 100 :height 100 :viewbox "0 0 50 50")
    ;; In this frame, coordinates go from 0-50
    (rect (p 0 0) 50 50 :fill "#fff3e0" :stroke "#f57c00" :stroke-width 2)
    (polygon (list (p 25 5) (p 45 45) (p 5 45)) :fill "#4caf50")
    (text (p 25 35) "F2" :font-size 10 :text-anchor "middle"))

  ;; Nested frames
  (frame (:x 50 :y 220 :width 300 :height 60 :viewbox "0 0 300 60")
    (rect (p 0 0) 300 60 :fill "#f3e5f5" :stroke "#7b1fa2" :stroke-width 2)

    ;; Nested sub-frame
    (frame (:x 10 :y 10 :width 80 :height 40 :viewbox "0 0 40 20")
      (rect (p 0 0) 40 20 :fill "#e1bee7")
      (text (p 20 14) "Nested" :font-size 8 :text-anchor "middle"))

    (text (p 150 35) "Outer frame with nested frame" :font-size 12 :text-anchor "middle"))

  ;; Title
  (text (p 200 20) "SVG Frame Test" :font-size 18 :text-anchor "middle" :font-weight "bold"))

(format t "Generated test/test-frame.svg~%")
