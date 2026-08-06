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
  "Merge local attributes with *default-attributes*, local keys take precedence.
   Both LOCAL-ATTRS and *DEFAULT-ATTRIBUTES* are deduplicated so that no key
   appears more than once in the result (with-attributes can otherwise create
   duplicate keys in *DEFAULT-ATTRIBUTES* by prepending new bindings)."
  (if *default-attributes*
      (let ((local-keys (serapeum:plist-keys local-attrs))
            (seen nil))
        (append local-attrs
                (loop for (key value) on *default-attributes* by #'cddr
                      when (and (not (member key local-keys))
                                (not (member key seen)))
                      do (push key seen)
                      and append (list key value))))
      local-attrs))

(defmacro with-attributes (attrs &body body)
  "Execute BODY with additional default attributes prepended to the current defaults."
  (let ((resolved-attrs (if (and (consp attrs) (keywordp (first attrs)))
                            `(list ,@attrs)
                            attrs)))
    `(let ((*default-attributes* (append ,resolved-attrs *default-attributes*)))
       ,@body)))
