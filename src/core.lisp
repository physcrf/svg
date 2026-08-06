(in-package #:svg)

(defvar *svg* nil)

(defstruct svg
  (stream nil :type (or null stream))
  (filename nil :type (or null string pathname))
  (width 325 :type number)
  (height 201 :type number)
  (own-stream-p nil :type boolean))

(defun svg-xml-header ()
  "<?xml version=\"1.0\" encoding=\"UTF-8\"?>")

(defun svg-opening-tag (svg)
  (format nil "<svg xmlns=\"http://www.w3.org/2000/svg\" xmlns:xlink=\"http://www.w3.org/1999/xlink\" width=\"~a\" height=\"~a\">"
          (svg-width svg) (svg-height svg)))

(defun write-svg-header (stream svg)
  (format stream "~a~%~a~%" (svg-xml-header) (svg-opening-tag svg)))

(defun begin-svg (stream svg)
  "Initialize STREAM for a fresh SVG document: reset the marker registry and
   write the XML header. Returns SVG."
  (reset-markers)
  (write-svg-header stream svg)
  svg)

(defun create-svg (&key width height stream filename)
  (make-svg :stream (or stream *standard-output*)
            :filename filename
            :width (or width 325)
            :height (or height 201)))

(defun open-svg (filename &optional (width 325) (height 201))
  (let* ((stream (open filename :direction :output :if-exists :supersede))
         (svg (create-svg :stream stream :filename filename :width width :height height)))
    (setf (svg-own-stream-p svg) t)
    (begin-svg stream svg)
    (setf *svg* svg)
    svg))

(defmacro with-svg ((filename &optional (width 325) (height 201)) &body body)
  `(with-open-file (stream ,filename :direction :output :if-exists :supersede)
     (let* ((svg (create-svg :stream stream :filename ,filename :width ,width :height ,height))
            (*svg* svg))
       (begin-svg stream svg)
       ,@body
       (emit-marker-defs)
       (format stream "</svg>~%")
       svg)))

(defun close-svg (&optional svg)
  (let ((target-svg (or svg *svg*)))
    (when (and target-svg (svg-stream target-svg))
      (emit-marker-defs)
      (format (svg-stream target-svg) "</svg>~%")
      (when (svg-own-stream-p target-svg)
        (close (svg-stream target-svg)))
      (when (eq target-svg *svg*)
        (setf *svg* nil)))
    target-svg))

;;; Attribute serialization

(defun serialize-value (value)
  "Convert a Lisp value to its SVG attribute string representation."
  (trivia:match value
    ((type string) (xml-escape value))
    ((type number) (fmt value))
    ((list 'quote sym) (serialize-value sym))
    ((type list) (str:join " "
                           (mapcar (lambda (v) (if (numberp v) (fmt v) v))
                                   value)))
    ((type symbol)
     ;; SVG keyword symbols are used unquoted in practice (e.g. :fill none);
     ;; everything else is treated as a marker reference.
     (if (member value '(none inherit))
         (string-downcase (symbol-name value))
         (marker-url value)))
    ((type null) "")
    (_ (format nil "~a" value))))

;;; Transform attribute processing

(defun transform-key-p (key)
  "Whether KEY is a transform keyword handled by TRANSFORM-VALUE."
  (member key '(:translate :rotate :scale :skew-x :skew-y :matrix)))

(defun transform-value (key value)
  "Convert a transform keyword + value into an SVG transform string.
   Returns NIL if KEY is not a transform, or if VALUE is NIL (the caller then
   drops the attribute pair entirely)."
  (when value
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
      (:matrix (apply #'matrix value))
      (_ nil))))

(defun process-transform-attributes (attributes)
  "Separate transform keywords from other attributes, combining transforms into one :transform entry.
   A user-supplied :transform string is treated as another transform fragment and
   folded into the same combined attribute, so passing both :transform and keyword
   transforms (e.g. :translate) produces a single transform attribute rather than
   two duplicate ones. Transform keywords with NIL values are ignored."
  (let (transforms others)
    (loop for (key value) on attributes by #'cddr
          if (eq key :transform)
            do (when value (push value transforms))
          else
            do (let ((tf (transform-value key value)))
                 (cond (tf (push tf transforms))
                       ((transform-key-p key) nil) ; NIL-valued transform: drop
                       (t (push key others) (push value others)))))
    (if transforms
        (nconc (nreverse others) (list :transform (str:join " " (nreverse transforms))))
        (nreverse others))))

;;; Output primitives

(declaim (inline current-stream))
(defun current-stream ()
  (if *svg* (svg-stream *svg*) *standard-output*))

(defparameter *camel-case-map*
  '(("viewbox" . "viewBox")
    ("preserveaspectratio" . "preserveAspectRatio")
    ("attributename" . "attributeName")
    ("gradientunits" . "gradientUnits")
    ("gradienttransform" . "gradientTransform")
    ("patternunits" . "patternUnits")
    ("patterncontentunits" . "patternContentUnits")
    ("markerunits" . "markerUnits")
    ("markerwidth" . "markerWidth")
    ("markerheight" . "markerHeight")
    ("refx" . "refX")
    ("refy" . "refY")
    ("markerstart" . "marker-start")
    ("markerend" . "marker-end")
    ("markermid" . "marker-mid")
    ("transformorigin" . "transform-origin")
    ("floodcolor" . "flood-color")
    ("floodopacity" . "flood-opacity")
    ("lightingcolor" . "lighting-color")
    ("paintorder" . "paint-order")
    ("baselineshift" . "baseline-shift")
    ("letterspacing" . "letter-spacing")
    ("wordspacing" . "word-spacing")
    ("textlength" . "textLength")
    ("lengthadjust" . "lengthAdjust")
    ("startoffset" . "startOffset")
    ("colorrendering" . "color-rendering")
    ("shaperendering" . "shape-rendering")
    ("textrendering" . "text-rendering")
    ("mixblendmode" . "mix-blend-mode")
    ("strokewidth" . "stroke-width")
    ("strokedasharray" . "stroke-dasharray")
    ("strokedashoffset" . "stroke-dashoffset")
    ("strokelinecap" . "stroke-linecap")
    ("strokelinejoin" . "stroke-linejoin")
    ("strokemiterlimit" . "stroke-miterlimit")
    ("fontsize" . "font-size")
    ("fontfamily" . "font-family")
    ("fontweight" . "font-weight")
    ("fontstyle" . "font-style")
    ("textanchor" . "text-anchor")
    ("textdecoration" . "text-decoration")
    ("dominantbaseline" . "dominant-baseline")
    ("clippath" . "clip-path")
    ("cliprule" . "clip-rule")
    ("fillrule" . "fill-rule")
    ("fillopacity" . "fill-opacity")
    ("strokeopacity" . "stroke-opacity")
    ("stopcolor" . "stop-color")
    ("stopopacity" . "stop-opacity")
    ("xmllang" . "xml:lang")
    ("xmlspace" . "xml:space"))
  "Alist mapping lowercased attribute names to their canonical SVG spelling
   (camelCase or hyphenated), consulted by ATTR-NAME.")

(defun attr-name (key)
  "Convert a keyword attribute name to its SVG string representation.
   Handles camelCase attributes like VIEWBOX -> viewBox."
  (let ((name (string-downcase (symbol-name key))))
    (or (cdr (assoc name *camel-case-map* :test #'string=)) name)))

(defun write-attributes (stream attributes)
  (loop for (key value) on attributes by #'cddr
        do (format stream "~a=\"~a\" " (attr-name key) (serialize-value value))))

(defun write-element (name attributes &optional content)
  "Write an SVG element. String CONTENT is XML-escaped for safety;
   `latex` writes its <g> directly (see latex.lisp) because its content
   is pre-rendered SVG markup that must not be escaped."
  (let* ((stream (current-stream))
         (processed-attrs (process-transform-attributes (merge-attributes attributes))))
    (format stream "  <~a " name)
    (write-attributes stream processed-attrs)
    (if (null content)
        (format stream "/>~%")
        (format stream ">~a</~a>~%" (xml-escape content) name))))

;;; Frame / sub-viewport

(defun parse-svg-number (string)
  "Parse a number from STRING, returning NIL if STRING is not a clean number."
  (let ((*read-eval* nil))
    (handler-case
        (let ((val (read-from-string (str:trim string))))
          (when (numberp val) val))
      (error () nil))))

(defun cartesian-flip-transform (viewbox-value height-value)
  "Compute the Y-flip transform string for Cartesian coordinates.
   Returns NIL if no flipping is needed (no viewBox or height)."
  (let ((vh (trivia:match viewbox-value
              ((type string) (let ((parts (str:split " " viewbox-value)))
                               (when (>= (length parts) 4)
                                 (parse-svg-number (fourth parts)))))
              ((type list) (when (>= (length viewbox-value) 4)
                             (let ((v (fourth viewbox-value)))
                               (when (numberp v) v))))
              (_ nil))))
    (alexandria:when-let ((h (or vh height-value)))
      (format nil "translate(0, ~a) scale(1, -1)" h))))

(defun evaluate-attr-form-p (form)
  "Whether an attribute value FORM in the FRAME/CARTESIAN-FRAME macros should be
   evaluated at runtime. Bare lists whose head is not a symbol (e.g. the viewBox
   shorthand (0 0 100 100)) cannot be function calls and are treated as literal
   data; everything that could be a call is evaluated."
  (and (consp form) (symbolp (first form))))

(defun expand-frame-attrs (attributes)
  "Generate a form that builds the attribute plist for FRAME/CARTESIAN-FRAME.
   Literal values (numbers, strings, symbols, and bare lists such as (0 0 100 100))
   are quoted; call forms (e.g. (viewbox 0 0 100 100) or (* 2 100)) are evaluated."
  `(list ,@(loop for (k v) on attributes by #'cddr
                 if (evaluate-attr-form-p v)
                   append (list `',k v)
                 else
                   append (list `',k `',v))))

(defmacro frame (attributes &body body)
  "Create a nested <svg> element (sub-viewport).
   Attributes: :x, :y, :width, :height, :viewBox, :id, :class, etc.
   Attribute values are evaluated; the viewBox shorthand (0 0 100 100) is kept literal."
  (let ((stream-var (gensym "stream"))
        (attrs-var (gensym "attrs")))
    `(let* ((,attrs-var ,(expand-frame-attrs attributes))
            (,stream-var (current-stream)))
       (format ,stream-var "  <svg ")
       (write-attributes ,stream-var (process-transform-attributes (merge-attributes ,attrs-var)))
       (format ,stream-var ">~%")
       ,@body
       (format ,stream-var "  </svg>~%"))))

(defmacro cartesian-frame (attributes &body body)
  "Create a nested <svg> with Cartesian coordinates (Y-axis points up).
   Wraps content in <g transform=\"translate(0,h) scale(1,-1)\"> to flip Y."
  (let ((attrs-var (gensym "attrs"))
        (stream-var (gensym "stream"))
        (flip-var (gensym "flip")))
    `(let* ((,attrs-var ,(expand-frame-attrs attributes))
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
