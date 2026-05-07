(in-package #:svg)

(defvar *default-attributes* nil)

(defun set-default-attributes (&rest attrs)
  (setf *default-attributes* attrs))

(defun get-default-attributes ()
  *default-attributes*)

(defun clear-default-attributes ()
  (setf *default-attributes* nil))

(defun merge-attributes (local-attrs)
  (if *default-attributes*
      (let ((local-keys (loop for (key) on local-attrs by #'cddr collect key)))
        (append local-attrs
                (loop for (key value) on *default-attributes* by #'cddr
                      unless (member key local-keys)
                      append (list key value))))
      local-attrs))

(defmacro with-attributes (attrs &body body)
  `(let ((*default-attributes* (append ,attrs *default-attributes*)))
     ,@body))
