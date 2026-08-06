(ql:quickload :svg :silent t)

(in-package #:svg)

(defun test-global-attributes ()
  (format t "~%=== Test Global Attributes ===~%")
  (clear-all-markers)
  (define-arrow test-arrow :scale 1.5)
  (define-circle-dot test-dot)
  
  (with-svg ("test/test-global-attributes.svg" 600 350)
    (rect (p 0 0) 600 350 :fill "white")
    (text (p 50 20) "Without global attributes:" :font-size 12 :fill "black")
    (line (p 50 40) (p 150 40) :stroke "black" :stroke-width 2 
          :marker-end 'test-arrow)
    
    (setf (getf *default-attributes* :stroke) "red")
    (setf (getf *default-attributes* :stroke-width) 3)
    (text (p 50 60) "Global stroke=red, stroke-width=3:" :font-size 12 :fill "black" :stroke "none")
    (line (p 50 80) (p 150 80) 
          :marker-end 'test-arrow)
    
    (clear-default-attributes)
    (setf (getf *default-attributes* :translate) (p 200 0))
    (text (p 50 100) "Global translate=(200,0):" :font-size 12 :fill "black")
    (line (p 50 120) (p 150 120) :stroke "blue" :stroke-width 2 
          :marker-end 'test-arrow)
    
    (setf (getf *default-attributes* :translate) (p 0 50))
    (text (p 50 140) "Global translate=(0,50), local translate=(50,0):" :font-size 12 :fill "black")
    (line (p 50 160) (p 150 160) :stroke "green" :stroke-width 2 
          :translate (p 50 0)
          :marker-end 'test-arrow)
    
    (clear-default-attributes)
    (setf (getf *default-attributes* :stroke) "purple")
    (setf (getf *default-attributes* :stroke-width) 3)
    (setf (getf *default-attributes* :translate) (p 0 100))
    (text (p 50 180) "Global stroke=purple, translate=(0,100):" :font-size 12 :fill "black" :stroke "none")
    (line (p 50 200) (p 150 200) 
          :marker-start 'test-dot
          :marker-end 'test-arrow)
    
    (clear-default-attributes)
    (setf (getf *default-attributes* :rotate) 15)
    (text (p 50 280) "Global rotate=15:" :font-size 12 :fill "black")
    (line (p 100 280) (p 200 280) :stroke "orange" :stroke-width 2 
          :marker-end 'test-arrow))
  
  (clear-default-attributes)
  (format t "Output: test/test-global-attributes.svg~%"))

(test-global-attributes)
