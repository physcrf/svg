(ql:quickload :svg :silent t)

(in-package #:svg)

(defun test-units ()
  (format t "~%=== Test Unit Conversion ===~%")
  
  ;; Test basic conversions
  (format t "px(100) = ~a (expected: 100)~%" (px 100))
  (format t "in(1) = ~a (expected: 96)~%" (in 1))
  (format t "cm(2.54) = ~a (expected: 96)~%" (cm 2.54))
  (format t "mm(25.4) = ~a (expected: 96)~%" (mm 25.4))
  (format t "pt(72) = ~a (expected: 96)~%" (pt 72))
  (format t "pc(6) = ~a (expected: 96)~%" (pc 6))
  
  ;; Test with SVG
  (with-svg ("test/test-units.svg" 400 300)
    (rect (p 0 0) 400 300 :fill "white")
    ;; Draw rectangles using different units
    (rect (p 10 10) (cm 2) (cm 1) :fill "red")
    (rect (p 10 40) (in 1) (mm 5) :fill "blue")
    (rect (p 10 70) (pt 72) (pc 1) :fill "green")
    
    ;; Draw a circle with cm radius
    (circle (p 200 50) (cm 0.5) :fill "purple")
    
    (format t "Output: test/test-units.svg~%"))
  
  (format t "=== Test Completed ===~%"))

(test-units)
