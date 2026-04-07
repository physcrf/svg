(ql:quickload :svg :silent t)

(in-package #:svg)

(defun test-global-attributes ()
  (format t "~%=== Test Global Attributes ===~%")
  (clear-all-markers)
  (define-arrow test-arrow :scale 1.5)
  (define-circle-dot test-dot)
  
  (with-svg ("test/test-global-attributes.svg" 600 250)
    (text (complex 50 20) "Without global attributes:" :font-size 12 :fill "black")
    (line (complex 50 40) (complex 150 40) :stroke "black" :stroke-width 2 
          :marker-end (marker-url 'test-arrow))
    
    (setf (getf *default-attributes* :stroke) "red")
    (setf (getf *default-attributes* :stroke-width) 3)
    (text (complex 50 60) "Global stroke=red, stroke-width=3:" :font-size 12 :fill "black" :stroke "none")
    (line (complex 50 80) (complex 150 80) 
          :marker-end (marker-url 'test-arrow))
    
    (clear-default-attributes)
    (setf (getf *default-attributes* :translate) (complex 200 0))
    (text (complex 50 100) "Global translate=(200,0):" :font-size 12 :fill "black")
    (line (complex 50 120) (complex 150 120) :stroke "blue" :stroke-width 2 
          :marker-end (marker-url 'test-arrow))
    
    (setf (getf *default-attributes* :translate) (complex 0 50))
    (text (complex 50 140) "Global translate=(0,50), local translate=(50,0):" :font-size 12 :fill "black")
    (line (complex 50 160) (complex 150 160) :stroke "green" :stroke-width 2 
          :translate (complex 50 0)
          :marker-end (marker-url 'test-arrow))
    
    (clear-default-attributes)
    (setf (getf *default-attributes* :stroke) "purple")
    (setf (getf *default-attributes* :stroke-width) 3)
    (setf (getf *default-attributes* :translate) (complex 0 100))
    (text (complex 50 180) "Global stroke=purple, translate=(0,100):" :font-size 12 :fill "black" :stroke "none")
    (line (complex 50 200) (complex 150 200) 
          :marker-start (marker-url 'test-dot)
          :marker-end (marker-url 'test-arrow))
    
    (clear-default-attributes)
    (setf (getf *default-attributes* :rotate) 15)
    (text (complex 50 220) "Global rotate=15:" :font-size 12 :fill "black")
    (line (complex 50 240) (complex 150 240) :stroke "orange" :stroke-width 2 
          :marker-end (marker-url 'test-arrow)))
  
  (clear-default-attributes)
  (format t "Output: test/test-global-attributes.svg~%"))

(test-global-attributes)
