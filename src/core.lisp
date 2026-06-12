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
    ((type list) (format nil "~{~a~^ ~}" value))
    ((type symbol) (alexandria:if-let ((m (use-marker value)))
                     (format nil "url(#~a)" (marker-id m))
                     (string-downcase (string value))))
    (_ (format nil "~a" value))))

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
        (nconc (nreverse others) (list :transform (format nil "~{~a ~}" (nreverse transforms))))
        (nreverse others))))

(declaim (inline current-stream))
(defun current-stream ()
  (if *svg* (svg-stream *svg*) *standard-output*))

(defun write-attributes (stream attributes)
  (loop for (key value) on attributes by #'cddr
        do (format stream "~(~a~)=\"~a\" " key (serialize-value value))))

(defun write-element (name attributes &optional content)
  (let* ((stream (current-stream))
         (processed-attrs (process-transform-attributes (merge-attributes attributes))))
    (format stream "  <~a " name)
    (write-attributes stream processed-attrs)
    (if content
        (format stream ">~a</~a>~%" content name)
        (format stream "/>~%"))))

(defmacro frame (attributes &body body)
  "Create a nested <svg> element (sub-viewport) to contain multiple SVG elements.
   Attributes can include :x, :y, :width, :height, :viewBox, :id, :class, etc.
   Body can contain multiple SVG element calls.
   
   Example:
   (frame (:x 10 :y 20 :width 100 :height 100 :viewbox \"0 0 50 50\")
     (rect (p 0 0) 50 50 :fill \"red\")
     (circle (p 25 25) 10 :fill \"blue\"))"
  (let ((stream-var (gensym "stream")))
    `(let ((,stream-var (current-stream)))
       (format ,stream-var "  <svg ")
       (write-attributes ,stream-var (process-transform-attributes (merge-attributes (copy-list ',attributes))))
       (format ,stream-var ">~%")
       ,@body
       (format ,stream-var "  </svg>~%"))))

(defmacro cartesian-frame (attributes &body body)
  "Create a nested <svg> element with Cartesian coordinates (Y-axis points up).
   Accepts same attributes as frame: :x, :y, :width, :height, :viewBox, etc.
   The viewBox or :height attribute determines the coordinate system height.
   
   Works by wrapping content in <g transform=\"translate(0, h) scale(1, -1)\">:
   - y=0 → bottom of viewport
   - y=height → top of viewport
   
   If both viewBox and height are omitted, content is not flipped.
   
   Example:
   (cartesian-frame (:x 50 :y 50 :width 200 :height 200 :viewbox \"0 0 100 100\")
     (circle (p 50 50) 30 :fill \"red\")
     (line (p 0 0) (p 100 100) :stroke \"gray\"))"
  (let ((attrs-var (gensym "attrs"))
        (stream-var (gensym "stream"))
        (viewbox-var (gensym "viewbox"))
        (height-var (gensym "height"))
        (flip-var (gensym "flip")))
    `(let* ((,attrs-var (copy-list ',attributes))
            (,viewbox-var (getf ,attrs-var :viewbox))
            (,height-var (getf ,attrs-var :height))
            (,flip-var (if ,viewbox-var
                          (let* ((parts (str:split " " (if (stringp ,viewbox-var)
                                                           ,viewbox-var
                                                           (format nil "~{~a~^ ~}" ,viewbox-var))))
                                 (vh (parse-integer (fourth parts))))
                            (format nil "translate(0, ~a) scale(1, -1)" vh))
                          (when ,height-var
                            (format nil "translate(0, ~a) scale(1, -1)" ,height-var))))
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
