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
          (svg-width svg) (svg-height svg)))

(defun write-svg-header (stream svg)
  (format stream "~a~%~a~%" (svg-xml-header) (svg-opening-tag svg)))

(defun create-svg (&key width height stream filename)
  (make-svg :stream (or stream *standard-output*)
            :filename filename
            :width (or width 325)
            :height (or height 201)))

(defun open-svg (filename &optional (width 325) (height 201))
  (let* ((stream (open filename :direction :output :if-exists :supersede))
         (svg (create-svg :stream stream :filename filename :width width :height height)))
    (reset-markers)
    (write-svg-header stream svg)
    (setf *svg* svg)
    svg))

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
    ((type symbol) (alexandria:if-let ((m (use-marker value)))
                     (format nil "url(#~a)" (marker-id m))
                     (string-downcase (string value))))
    (_ (format nil "~a" value))))

(defun serialize-attributes (attributes)
  (format nil "~{~(~a~)=\"~a\" ~}"
          (loop for (key value) on attributes by #'cddr
                collect key
                collect (serialize-value value))))

(defun transform-value (key value)
  (trivia:match key
    (:translate (translate (realpart value) (imagpart value)))
    (:rotate (trivia:match value
               ((list angle center) (rotate angle (realpart center) (imagpart center)))
               (_ (rotate value))))
    (:scale (trivia:match value
              ((list sx sy) (scale sx sy))
              (_ (scale value))))
    (:skew-x (skew-x value))
    (:skew-y (skew-y value))
    (:matrix (apply #'matrix value))))

(defun process-transform-attributes (attributes)
  (let (transforms others)
    (loop for (key value) on attributes by #'cddr
          for tf = (transform-value key value)
          if tf
            do (push tf transforms)
          else
            do (push key others) (push value others))
    (if transforms
        (append (nreverse others) (list :transform (format nil "~{~a ~}" (nreverse transforms))))
        (nreverse others))))

(defun write-element (name attributes &optional content)
  (let* ((stream (if *svg* (svg-stream *svg*) *standard-output*))
         (processed-attrs (process-transform-attributes (merge-attributes attributes)))
         (attrs-str (serialize-attributes processed-attrs)))
    (if content
        (format stream "  <~a ~a>~a</~a>~%" name attrs-str content name)
        (format stream "  <~a ~a/>~%" name attrs-str))))
