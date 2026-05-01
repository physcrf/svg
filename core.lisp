(in-package #:svg)

(defvar *svg* nil)

(defstruct svg
  (stream nil :type (or null stream))
  (filename nil :type (or null string))
  (width 325 :type number)
  (height 201 :type number))

(defun svg-xml-header ()
  "<?xml version=\"1.0\" encoding=\"UTF-8\"?>")

(defun svg-opening-tag (svg)
  (format nil "<svg xmlns=\"http://www.w3.org/2000/svg\" xmlns:xlink=\"http://www.w3.org/1999/xlink\" width=\"~a\" height=\"~a\">"
          (svg-width svg)
          (svg-height svg)))

(defun write-svg-header (stream svg)
  (format stream "~a~%~a~%" (svg-xml-header) (svg-opening-tag svg)))

(defun create-svg (&key width height stream filename)
  (make-svg :stream (or stream *standard-output*)
            :filename filename
            :width (or width 325)
            :height (or height 201)))

(defun open-svg (filename &optional (width 325) (height 201))
  (let ((stream (open filename :direction :output :if-exists :supersede)))
    (reset-markers)
    (let ((svg (create-svg :stream stream :filename filename :width width :height height)))
      (write-svg-header stream svg)
      (setf *svg* svg)
      svg)))

(defmacro with-svg ((filename &optional (width 325) (height 201)) &body body)
  `(with-open-file (stream ,filename :direction :output :if-exists :supersede)
     (let* ((svg (create-svg :stream stream :filename ,filename :width ,width :height ,height))
            (*svg* svg))
       (reset-markers)
       (write-svg-header stream svg)
       ,@body
       (emit-marker-defs)
       (format stream "</svg>~%")
       svg)))

(defun close-svg (&optional svg)
  (let ((target-svg (or svg *svg*)))
    (when (and target-svg (svg-stream target-svg))
      (emit-marker-defs)
      (format (svg-stream target-svg) "</svg>~%")
      (close (svg-stream target-svg))
      (when (eq target-svg *svg*)
        (setf *svg* nil)))
    target-svg))

(defun serialize-value (value)
  (trivia:match value
    ((type string) value)
    ((type number) (fmt value))
    ((type symbol) (alexandria:if-let ((marker (find-marker value)))
                     (progn (use-marker value)
                            (format nil "url(#~a)" (marker-id marker)))
                     (string-downcase (string value))))
    (_ (format nil "~a" value))))

(defun serialize-attributes (attributes)
  (format nil "~{~a=\"~a\" ~}"
          (loop for (key value) on attributes by #'cddr
                collect (string-downcase (format nil "~a" key))
                collect (serialize-value value))))

(defun process-transform-attributes (attributes)
  (let ((transforms nil)
        (other-attributes nil))
    (loop for (key value) on attributes by #'cddr
          do (trivia:match key
               (:translate (push (translate (realpart value) (imagpart value)) transforms))
               (:rotate (trivia:match value
                          ((list angle center) (push (rotate angle (realpart center) (imagpart center)) transforms))
                          (_ (push (rotate value) transforms))))
               (:scale (trivia:match value
                         ((list sx sy) (push (scale sx sy) transforms))
                         (_ (push (scale value) transforms))))
               (:skew-x (push (skew-x value) transforms))
               (:skew-y (push (skew-y value) transforms))
               (:matrix (push (apply #'matrix value) transforms))
               (_ (push key other-attributes) (push value other-attributes))))
          finally (if transforms
                      (append (nreverse other-attributes)
                              (list :transform (format nil "~{~a ~}" (reverse transforms))))
                      (nreverse other-attributes))))

(defun write-element (name attributes &optional content)
  (let* ((stream (if *svg* (svg-stream *svg*) *standard-output*))
         (processed-attrs (process-transform-attributes (merge-attributes attributes)))
         (attrs-str (serialize-attributes processed-attrs)))
    (if content
        (format stream "  <~a ~a>~a</~a>~%" name attrs-str content name)
        (format stream "  <~a ~a/>~%" name attrs-str))))
