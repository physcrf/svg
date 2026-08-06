(ql:quickload :svg :silent t)

(in-package #:svg)

(defun test-marker-scale ()
  (format t "~%=== Test Marker Scale ===~%")
  (clear-all-markers)
  (define-arrow s1 :scale 0.5)
  (define-arrow s2 :scale 1)
  (define-arrow s3 :scale 2)
  (define-arrow s4 :scale '(3 1))
  (define-arrow s5 :scale '(1 3))
  
  (with-svg ("test/test-marker-scale.svg" 600 150)
    (rect (p 0 0) 600 150 :fill "white")
    (line (p 30 30) (p 100 30) :stroke "black" :stroke-width 2 
          :marker-end 's1)
    (line (p 30 55) (p 100 55) :stroke "black" :stroke-width 2 
          :marker-end 's2)
    (line (p 30 80) (p 100 80) :stroke "black" :stroke-width 2 
          :marker-end 's3)
    (line (p 30 105) (p 100 105) :stroke "black" :stroke-width 2 
          :marker-end 's4)
    (line (p 30 130) (p 100 130) :stroke "black" :stroke-width 2 
          :marker-end 's5)
    
    (text (p 110 35) "scale=0.5" :font-size 12)
    (text (p 110 60) "scale=1" :font-size 12)
    (text (p 110 85) "scale=2" :font-size 12)
    (text (p 110 110) "scale=(3,1)" :font-size 12)
    (text (p 110 135) "scale=(1,3)" :font-size 12))
  (format t "Output: test/test-marker-scale.svg~%"))

(test-marker-scale)
