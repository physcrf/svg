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

;;; Attribute serialization

(defun serialize-value (value)
  "Convert a Lisp value to its SVG attribute string representation."
  (trivia:match value
    ((type string) value)
    ((type number) (fmt value))
    ((type list) (format nil "~{~a~^ ~}" value))
    ((type symbol)
     (alexandria:if-let ((m (use-marker value)))
       (format nil "url(#~a)" (marker-id m))
       (str:downcase (string value))))
    (_ (format nil "~a" value))))

;;; Transform attribute processing

(defun transform-value (key value)
  "Convert a transform keyword + value into an SVG transform string, or NIL if not a transform."
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
  "Separate transform keywords from other attributes, combining transforms into one :transform entry."
  (let (transforms others)
    (loop for (key value) on attributes by #'cddr
          for tf = (transform-value key value)
          if tf
            do (push tf transforms)
          else
            do (push key others) (push value others))
    (if transforms
        (nconc (nreverse others) (list :transform (str:join " " (nreverse transforms))))
        (nreverse others))))

;;; Output primitives

(declaim (inline current-stream))
(defun current-stream ()
  (if *svg* (svg-stream *svg*) *standard-output*))

(defun attr-name (key)
  "Convert a keyword attribute name to its SVG string representation.
   Handles camelCase attributes like VIEWBOX -> viewBox."
  (let ((name (string-downcase (symbol-name key))))
    (if (string= name "viewbox") "viewBox" name)))

(defun write-attributes (stream attributes)
  (loop for (key value) on attributes by #'cddr
        do (format stream "~a=\"~a\" " (attr-name key) (serialize-value value))))

(defun write-element (name attributes &optional content)
  (let* ((stream (current-stream))
         (processed-attrs (process-transform-attributes (merge-attributes attributes))))
    (format stream "  <~a " name)
    (write-attributes stream processed-attrs)
    (if content
        (format stream ">~a</~a>~%" content name)
        (format stream "/>~%"))))

;;; Frame / sub-viewport

(defun cartesian-flip-transform (viewbox-value height-value)
  "Compute the Y-flip transform string for Cartesian coordinates.
   Returns NIL if no flipping is needed (no viewBox or height)."
  (let ((vh (trivia:match viewbox-value
              ((type string) (let ((parts (str:split " " viewbox-value)))
                               (when (>= (length parts) 4)
                                 (parse-integer (fourth parts) :junk-allowed t))))
              ((type list) (when (>= (length viewbox-value) 4)
                             (fourth viewbox-value)))
              (_ nil))))
    (alexandria:when-let ((h (or vh height-value)))
      (format nil "translate(0, ~a) scale(1, -1)" h))))

(defmacro frame (attributes &body body)
  "Create a nested <svg> element (sub-viewport).
   Attributes: :x, :y, :width, :height, :viewBox, :id, :class, etc."
  (let ((stream-var (gensym "stream")))
    `(let ((,stream-var (current-stream)))
       (format ,stream-var "  <svg ")
       (write-attributes ,stream-var (process-transform-attributes (merge-attributes (copy-list ',attributes))))
       (format ,stream-var ">~%")
       ,@body
       (format ,stream-var "  </svg>~%"))))

(defmacro cartesian-frame (attributes &body body)
  "Create a nested <svg> with Cartesian coordinates (Y-axis points up).
   Wraps content in <g transform=\"translate(0,h) scale(1,-1)\"> to flip Y."
  (let ((attrs-var (gensym "attrs"))
        (stream-var (gensym "stream"))
        (flip-var (gensym "flip")))
    `(let* ((,attrs-var (copy-list ',attributes))
            (,flip-var (cartesian-flip-transform (getf ,attrs-var :viewbox)
                                                  (getf ,attrs-var :height)))
            (,stream-var (current-stream)))
       (format ,stream-var "  <svg ")
       (write-attributes ,stream-var (process-transform-attributes (merge-attributes ,attrs-var)))
       (format ,stream-var ">~%")
       (when ,flip-var
         (format ,stream-var "    <g transform=\"~a\">~%" ,flip-var))
       ,@body
       (when ,flip-var
         (format ,stream-var "    </g>~%"))
       (format ,stream-var "  </svg>~%"))))
