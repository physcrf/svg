(ql:quickload :svg :silent t)

(in-package #:svg)

(defun test-markers ()
  (format t "~%=== Test Markers ===~%")
  (clear-all-markers)
  (define-arrow arrow1)
  (define-circle-dot dot1)
  (define-square-dot square1)
  (define-diamond diamond1)
  (define-triangle triangle1)
  (define-cross cross1)
  (define-arrow-open arrow-open1)
  (define-arrow-filled arrow-filled1)
  
  (with-svg ("test/test-markers.svg" 600 200)
    (line (p 30 30) (p 80 30) :stroke "black" :stroke-width 2 
          :marker-end 'arrow1)
    (line (p 30 50) (p 80 50) :stroke "black" :stroke-width 2 
          :marker-end 'dot1)
    (line (p 30 70) (p 80 70) :stroke "black" :stroke-width 2 
          :marker-end 'square1)
    (line (p 30 90) (p 80 90) :stroke "black" :stroke-width 2 
          :marker-end 'diamond1)
    (line (p 30 110) (p 80 110) :stroke "black" :stroke-width 2 
          :marker-end 'triangle1)
    (line (p 30 130) (p 80 130) :stroke "black" :stroke-width 2 
          :marker-end 'cross1)
    (line (p 30 150) (p 80 150) :stroke "black" :stroke-width 2 
          :marker-end 'arrow-open1)
    (line (p 30 170) (p 80 170) :stroke "black" :stroke-width 2 
          :marker-end 'arrow-filled1)
    
    (text (p 90 35) "arrow" :font-size 12)
    (text (p 90 55) "circle-dot" :font-size 12)
    (text (p 90 75) "square-dot" :font-size 12)
    (text (p 90 95) "diamond" :font-size 12)
    (text (p 90 115) "triangle" :font-size 12)
    (text (p 90 135) "cross" :font-size 12)
    (text (p 90 155) "arrow-open" :font-size 12)
    (text (p 90 175) "arrow-filled" :font-size 12))
  (format t "Output: test/test-markers.svg~%"))

(test-markers)
