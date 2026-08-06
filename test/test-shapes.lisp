(ql:quickload :svg :silent t)

(in-package #:svg)

(defun test-shapes ()
  (format t "~%=== Test Shapes ===~%")
  (with-svg ("test/test-shapes.svg" 500 300)
    (rect (p 0 0) 500 300 :fill "white")
    (circle (p 50 50) 20 :fill "red" :stroke "black")
    (rect (p 100 30) 60 40 :fill "blue" :rx 5 :ry 5)
    (ellipse (p 250 50) 40 25 :fill "green")
    (line (p 320 30) (p 380 70) :stroke "purple" :stroke-width 3)
    (polyline (list (p 50 120) (p 100 100) (p 150 130) (p 200 110)) 
              :stroke "orange" :fill "none" :stroke-width 2)
    (polygon (list (p 280 100) (p 330 80) (p 380 100) (p 350 150) (p 310 150))
             :fill "cyan" :stroke "black"))
  (format t "Output: test/test-shapes.svg~%"))

(test-shapes)
