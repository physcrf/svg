(in-package #:svg)

(defun text (position content &rest attrs &key &allow-other-keys)
  "Write a <text> element at POSITION with CONTENT and attributes."
  (check-type position number)
  (write-element "text"
                 (append (list 'x (x position) 'y (y position)) attrs)
                 content))
