(ql:quickload :svg :silent t)

(in-package #:svg)

(defun test-text ()
  (format t "~%=== Test Text ===~%")
  (with-svg ("test/test-text.svg" 400 150)
    (text (complex 50 30) "Hello SVG!" :font-size 24 :fill "black")
    (text (complex 50 60) "中文测试" :font-size 18 :fill "darkblue")
    (text (complex 50 90) "Bold Text" :font-size 16 :font-weight "bold" :fill "red")
    (text (complex 50 120) "Italic Text" :font-size 14 :font-style "italic" :fill "purple"))
  (format t "Output: test/test-text.svg~%"))

(test-text)
