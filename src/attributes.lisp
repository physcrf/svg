(in-package #:svg)

(defvar *default-attributes* nil
  "Global default attributes (a property list) inherited by every element.")

(defun set-default-attributes (&rest attrs)
  "Replace *default-attributes* with ATTRS (a property list)."
  (setf *default-attributes* attrs))

(defun clear-default-attributes ()
  "Clear all global default attributes."
  (setf *default-attributes* nil))

(defun dedupe-plist (plist)
  "Return PLIST with later duplicate keys removed (the first occurrence wins).
   Only keys are compared: values are never inspected, so a value that happens
   to be equal to some other key (e.g. the plist (:a :b :b :c)) cannot cause a
   key to be wrongly dropped."
  (let (seen result)
    (loop for (key value) on plist by #'cddr
          unless (member key seen)
            do (push key seen)
               (push key result)
               (push value result)
          finally (return (nreverse result)))))

(defun merge-attributes (local-attrs)
  "Merge local attributes with *default-attributes*, local keys take precedence.
   LOCAL-ATTRS is placed first so DEDUPE-PLIST (which keeps the first
   occurrence of each key) both resolves conflicts in favor of the locals and
   removes duplicate keys from either source (with-attributes can create
   duplicate keys in *DEFAULT-ATTRIBUTES* by prepending new bindings, and a
   caller can pass the same key twice)."
  (dedupe-plist (append local-attrs *default-attributes*)))

(defmacro with-attributes (attrs &body body)
  "Execute BODY with additional default attributes prepended to the current defaults."
  (let ((resolved-attrs (if (and (consp attrs) (keywordp (first attrs)))
                            `(list ,@attrs)
                            attrs)))
    `(let ((*default-attributes* (append ,resolved-attrs *default-attributes*)))
       ,@body)))
