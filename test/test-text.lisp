(ql:quickload :svg :silent t)

(in-package #:svg)

(defun test-text ()
  (format t "~%=== Test Text ===~%")
  (with-svg ("test/test-text.svg" 400 150)
    (rect (p 0 0) 400 150 :fill "white")
    (text (p 50 30) "Hello SVG!" :font-size 24 :fill "black")
    (text (p 50 60) "中文测试" :font-size 18 :fill "darkblue")
    (text (p 50 90) "Bold Text" :font-size 16 :font-weight "bold" :fill "red")
    (text (p 50 120) "Italic Text" :font-size 14 :font-style "italic" :fill "purple"))
  (format t "Output: test/test-text.svg~%"))

(test-text)
