(in-package #:svg)

(defun text (position content &rest attrs &key &allow-other-keys)
  (write-element "text"
                (append (list 'x (x position) 'y (y position)) attrs)
                content))
