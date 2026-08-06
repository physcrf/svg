(in-package #:svg)

(defvar *default-attributes* nil
  "Global default attributes (a property list) inherited by every element.")

(defun set-default-attributes (&rest attrs)
  "Replace *default-attributes* with ATTRS (a property list)."
  (setf *default-attributes* attrs))

(defun get-default-attributes ()
  "Return the current global default attributes."
  *default-attributes*)

(defun clear-default-attributes ()
  "Clear all global default attributes."
  (setf *default-attributes* nil))

(defun merge-attributes (local-attrs)
  "Merge local attributes with *default-attributes*, local keys take precedence."
  (if *default-attributes*
      (let ((local-keys (serapeum:plist-keys local-attrs)))
        (append local-attrs
                (loop for (key value) on *default-attributes* by #'cddr
                      unless (member key local-keys)
                      append (list key value))))
      local-attrs))

(defmacro with-attributes (attrs &body body)
  "Execute BODY with additional default attributes prepended to the current defaults."
  (let ((resolved-attrs (if (and (consp attrs) (keywordp (first attrs)))
                            `(list ,@attrs)
                            attrs)))
    `(let ((*default-attributes* (append ,resolved-attrs *default-attributes*)))
       ,@body)))
