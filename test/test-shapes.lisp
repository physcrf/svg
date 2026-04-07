(ql:quickload :svg :silent t)

(in-package #:svg)

(defun test-shapes ()
  (format t "~%=== Test Shapes ===~%")
  (with-svg ("test/test-shapes.svg" 500 300)
    (circle (complex 50 50) 20 :fill "red" :stroke "black")
    (rect (complex 100 30) 60 40 :fill "blue" :rx 5 :ry 5)
    (ellipse (complex 250 50) 40 25 :fill "green")
    (line (complex 320 30) (complex 380 70) :stroke "purple" :stroke-width 3)
    (polyline (list (complex 50 120) (complex 100 100) (complex 150 130) (complex 200 110)) 
              :stroke "orange" :fill "none" :stroke-width 2)
    (polygon (list (complex 280 100) (complex 330 80) (complex 380 100) (complex 350 150) (complex 310 150))
             :fill "cyan" :stroke "black"))
  (format t "Output: test/test-shapes.svg~%"))

(test-shapes)
