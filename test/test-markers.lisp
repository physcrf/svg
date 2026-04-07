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
    (line (complex 30 30) (complex 80 30) :stroke "black" :stroke-width 2 
          :marker-end (marker-url 'arrow1))
    (line (complex 30 50) (complex 80 50) :stroke "black" :stroke-width 2 
          :marker-end (marker-url 'dot1))
    (line (complex 30 70) (complex 80 70) :stroke "black" :stroke-width 2 
          :marker-end (marker-url 'square1))
    (line (complex 30 90) (complex 80 90) :stroke "black" :stroke-width 2 
          :marker-end (marker-url 'diamond1))
    (line (complex 30 110) (complex 80 110) :stroke "black" :stroke-width 2 
          :marker-end (marker-url 'triangle1))
    (line (complex 30 130) (complex 80 130) :stroke "black" :stroke-width 2 
          :marker-end (marker-url 'cross1))
    (line (complex 30 150) (complex 80 150) :stroke "black" :stroke-width 2 
          :marker-end (marker-url 'arrow-open1))
    (line (complex 30 170) (complex 80 170) :stroke "black" :stroke-width 2 
          :marker-end (marker-url 'arrow-filled1))
    
    (text (complex 90 35) "arrow" :font-size 12)
    (text (complex 90 55) "circle-dot" :font-size 12)
    (text (complex 90 75) "square-dot" :font-size 12)
    (text (complex 90 95) "diamond" :font-size 12)
    (text (complex 90 115) "triangle" :font-size 12)
    (text (complex 90 135) "cross" :font-size 12)
    (text (complex 90 155) "arrow-open" :font-size 12)
    (text (complex 90 175) "arrow-filled" :font-size 12))
  (format t "Output: test/test-markers.svg~%"))

(test-markers)
