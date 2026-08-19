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

(defun %finish-svg (svg)
  "Emit the <defs> block and closing </svg> tag for SVG, and close its stream
   if SVG owns it. The stream slot is cleared afterwards so a second call is
   a no-op; safe to call on NIL."
  (when (and svg (svg-stream svg))
    (let ((stream (svg-stream svg)))
      (setf (svg-stream svg) nil)
      (emit-marker-defs stream)
      (format stream "</svg>~%")
      (when (svg-own-stream-p svg)
        (close stream)))))

(defmacro with-svg ((filename &optional (width 325) (height 201)) &body body)
  "Write an SVG document to FILENAME, evaluating BODY with the SVG bound.
   The stream is managed manually (not via WITH-OPEN-FILE) and the <defs> block
   and closing tag are always emitted through UNWIND-PROTECT: even if BODY
   signals an error, the file is left on disk as well-formed (partial) XML that
   can be inspected, and the marker registry does not leak into the next
   document. On SBCL, WITH-OPEN-FILE would instead delete the file entirely."
  ;; Bind *SVG* first so the (setf *svg* ...) inside OPEN-SVG updates the
  ;; dynamic binding rather than leaking into the global value on exit.
  `(let* ((*svg* nil)
         (svg (open-svg ,filename ,width ,height)))
     (unwind-protect
          (progn ,@body)
       (%finish-svg svg)
       (setf *svg* nil))
     svg))

(defun close-svg (&optional svg)
  "Finish and close an SVG document (default: the current *SVG*)."
  (let ((target-svg (or svg *svg*)))
    (%finish-svg target-svg)
    (when (eq target-svg *svg*)
      (setf *svg* nil))
    target-svg))

;;; Attribute serialization

(defparameter *plain-attribute-values*
  '("none" "inherit" "hidden" "visible" "collapse" "auto" "normal" "bold"
    "italic" "start" "middle" "end" "butt" "round" "square" "miter" "bevel"
    "nonzero" "evenodd" "default")
  "Symbol names that are plain SVG/CSS keyword values and must never be
   interpreted as marker references by SERIALIZE-VALUE.")

(defun plain-attribute-symbol-p (sym)
  "Whether SYM names a plain SVG/CSS keyword value (e.g. NONE, INHERIT).
   Case-insensitive so both `none' and :none work."
  (member (symbol-name sym) *plain-attribute-values* :test #'string-equal))

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
     ;; SVG/CSS keyword values are written as-is; everything else is treated
     ;; as a marker reference (MARKER-URL handles both registered and
     ;; forward-referenced markers, normalizing keywords and case).
     (if (plain-attribute-symbol-p value)
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
      (:translate (trivia:match value
                    ((list tx ty) (translate tx ty))
                    ((type number) (translate (realpart value) (imagpart value)))
                    (_ (error "Invalid :translate value: ~a (expected a point or (tx ty))" value))))
      (:rotate (trivia:match value
                 ((list angle center) (rotate angle (realpart center) (imagpart center)))
                 ((type number) (rotate value))
                 (_ (error "Invalid :rotate value: ~a (expected a number or (angle point))" value))))
      (:scale (trivia:match value
                ((list sx sy) (scale sx sy))
                ((list sx) (scale sx))
                ((type number) (scale value))
                (_ (error "Invalid :scale value: ~a (expected a number or (sx [sy]))" value))))
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

(defun emit-open-tag (stream name attributes)
  "Write an opening tag `  <NAME' with ATTRIBUTES, after merging with the
   global defaults and folding transform keywords. The caller writes the
   closing '>' (or '/>') and any content, so the tag can be re-used by
   WRITE-ELEMENT, FRAME, and the raw writers. No stray space is emitted when
   there are no attributes."
  (let ((processed (process-transform-attributes (merge-attributes attributes))))
    (format stream "  <~a" name)
    (when processed
      (format stream " ")
      (write-attributes stream processed))))

(defun write-element (name attributes &optional content)
  "Write an SVG element. String CONTENT is XML-escaped for safety;
   use WRITE-RAW-ELEMENT for content that is pre-rendered markup or script
   that must not be escaped (see latex.lisp)."
  (let ((stream (current-stream)))
    (emit-open-tag stream name attributes)
    (if (null content)
        (format stream "/>~%")
        (format stream ">~a</~a>~%" (xml-escape content) name))))

(defun write-raw-element (name attributes content)
  "Write an SVG element whose CONTENT is written verbatim (no XML escaping):
   pre-rendered SVG markup, JavaScript in <script>, CDATA, etc."
  (let ((stream (current-stream)))
    (emit-open-tag stream name attributes)
    (format stream ">~a</~a>~%" content name)))

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

(defun %expand-frame (attributes body flip-p)
  "Shared expansion for FRAME and CARTESIAN-FRAME: open a nested <svg> element,
   optionally wrap BODY in a Cartesian Y-flip group, then close the element."
  (alexandria:with-gensyms (stream attrs flip)
    `(let* ((,attrs ,(expand-frame-attrs attributes))
            (,stream (current-stream))
            ,@(when flip-p
                `((,flip (cartesian-flip-transform (getf ,attrs :viewbox)
                                                   (getf ,attrs :height))))))
       (emit-open-tag ,stream "svg" ,attrs)
       (format ,stream ">~%")
       ,@(when flip-p
           `((when ,flip
               (format ,stream "    <g transform=\"~a\">~%" ,flip))))
       ,@body
       ,@(when flip-p
           `((when ,flip
               (format ,stream "    </g>~%"))))
       (format ,stream "  </svg>~%"))))

(defmacro frame (attributes &body body)
  "Create a nested <svg> element (sub-viewport).
   Attributes: :x, :y, :width, :height, :viewBox, :id, :class, etc.
   Attribute values are evaluated; the viewBox shorthand (0 0 100 100) is kept literal."
  (%expand-frame attributes body nil))

(defmacro cartesian-frame (attributes &body body)
  "Create a nested <svg> with Cartesian coordinates (Y-axis points up).
   Wraps content in <g transform=\"translate(0,h) scale(1,-1)\"> to flip Y."
  (%expand-frame attributes body t))
