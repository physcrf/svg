(ql:quickload :svg :silent t)

(in-package #:svg)

(defun test-transforms ()
  (format t "~%=== Test Transforms ===~%")
  (with-svg ("test/test-transforms.svg" 400 200)
    (rect (p 0 0) 400 200 :fill "white")
    (rect (p 50 50) 40 30 :fill "purple" :rotate 15)
    (circle (p 150 65) 20 :fill "orange" :scale 1.5)
    (rect (p 220 50) 40 40 :fill "pink" :translate (p 20 10))
    (circle (p 300 65) 20 :fill "cyan" :rotate 30 :scale 0.8)
    (rect (p 50 120) 40 30 :fill "lightblue" :translate (p 100 50))
    (circle (p 200 135) 20 :fill "lightgreen" :rotate -20))
  (format t "Output: test/test-transforms.svg~%"))

(test-transforms)
