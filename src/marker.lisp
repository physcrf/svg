(in-package #:svg)

(defvar *markers* nil)
(defvar *used-markers* nil)

(defstruct marker id content refx refy markerwidth markerheight viewbox orient scale)

(defun register-marker (m)
  (push m *markers*)
  m)

(defun find-marker (name)
  (find name *markers* :key #'marker-id :test #'equal))

(defun use-marker (name)
  (alexandria:when-let ((m (find-marker name)))
    (pushnew m *used-markers* :test #'eq)
    m))

(defun define-marker (id content &key (refx 5) (refy 5) (markerwidth 10) (markerheight 10) viewbox (orient "auto") scale)
  (register-marker
   (make-marker :id id :content content
                :refx refx :refy refy
                :markerwidth markerwidth :markerheight markerheight
                :viewbox (or viewbox (format nil "0 0 ~a ~a" markerwidth markerheight))
                :orient orient :scale scale)))

;;; Marker definition macros
;;;
;;; `def-simple-marker` defines a macro (e.g. `define-arrow`) that, when invoked,
;;; expands into a `define-marker` form. The marker's SVG content is built from
;;; CONTENT-FMT at expansion time, with W and H (the marker's pixel width/height)
;;; and any EXTRA-KEYS available as variables among the format arguments.
;;;
;;; DEFAULT-REFX / DEFAULT-REFY are the reference-point fallbacks, expressed in
;;; terms of W/H so they track the marker size. EXTRA-KEYS is a list of
;;; (KEY DEFAULT) pairs for additional &key parameters beyond the standard ones.

(defmacro def-simple-marker (name (content-fmt &rest fmt-args) &key (default-refx 5) (default-refy 5) extra-keys)
  "Define a marker-defining macro NAME. The content is computed from CONTENT-FMT/FMT-ARGS.
   DEFAULT-REFX/DEFAULT-REFY provide the fallback ref values.
   EXTRA-KEYS is a list of (KEY DEFAULT-VALUE) for additional &key parameters."
  (let ((extra-key-names (mapcar #'first extra-keys))
        (extra-let-bindings (mapcar (lambda (spec)
                                      `(,(first spec) (or ,(first spec) ,(second spec))))
                                    extra-keys)))
    `(defmacro ,name (id &rest rest
                       &key refx refy markerwidth markerheight viewbox orient scale
                       ,@extra-key-names
                       &allow-other-keys)
       (let ((w (or markerwidth 10))
             (h (or markerheight 10))
             ,@extra-let-bindings)
         `(define-marker ',id
                          ,(format nil ,content-fmt ,@fmt-args)
                          :refx ,(or refx ,default-refx) :refy ,(or refy ,default-refy)
                          :markerwidth ,w :markerheight ,h
                          :viewbox ,(or viewbox (format nil "0 0 ~a ~a" w h))
                          :orient ,(or orient "auto") :scale ,scale)))))

;;; Built-in markers. Each draws a simple shape sized to the W x H marker box;
;;; `fill="context-stroke"` (or `stroke="context-stroke"`) makes the marker
;;; inherit the color of the line it is attached to.

;; Filled arrow: base on the left edge (x=0, full height), tip at (w, h/2).
(def-simple-marker define-arrow
  ("<path d=\"M0,0 L0,~a L~a,~a z\" fill=\"context-stroke\" />" h w (float (/ h 2)))
  :default-refx 0 :default-refy (float (/ h 2)))

;; Filled circle centered in the box, radius = half the shorter side.
(def-simple-marker define-circle-dot
  ("<circle cx=\"~a\" cy=\"~a\" r=\"~a\" fill=\"context-stroke\" />" (/ w 2) (/ h 2) (/ (min w h) 2))
  :default-refx (/ w 2) :default-refy (/ h 2))

;; Filled square filling the whole box.
(def-simple-marker define-square-dot
  ("<rect x=\"0\" y=\"0\" width=\"~a\" height=\"~a\" fill=\"context-stroke\" />" w h)
  :default-refx (/ w 2) :default-refy (/ h 2))

;; Filled triangle: base on the left edge, apex at (w, h/2).
(def-simple-marker define-triangle
  ("<path d=\"M0,0 L0,~a L~a,~a z\" fill=\"context-stroke\" />" h w (float (/ h 2)))
  :default-refx 0 :default-refy (float (/ h 2)))

;; Filled diamond: vertices at the midpoints of the four edges.
(def-simple-marker define-diamond
  ("<path d=\"M~a,0 L~a,~a L~a,~a L0,~a z\" fill=\"context-stroke\" />" (/ w 2) w (/ h 2) (/ w 2) h (/ h 2))
  :default-refx (/ w 2) :default-refy (/ h 2))

;; Cross (plus sign): two stroked segments crossing at the box center.
(def-simple-marker define-cross
  ("<path d=\"M~a,0 L~a,0 M~a,0 L~a,~a M~a,~a L~a,~a\" stroke=\"context-stroke\" stroke-width=\"~a\" fill=\"none\" />"
   (- (/ w 2) stroke-width) (+ (/ w 2) stroke-width) (/ w 2) (/ w 2) h
   (- (/ w 2) stroke-width) h (+ (/ w 2) stroke-width) h stroke-width)
  :default-refx (/ w 2) :default-refy (/ h 2)
  :extra-keys ((stroke-width 2)))

;; Open (hollow) arrow: white fill with a stroked outline.
(def-simple-marker define-arrow-open
  ("<path d=\"M0,0 L0,~a L~a,~a z\" fill=\"white\" stroke=\"context-stroke\" stroke-width=\"~a\" />"
   h w (float (/ h 2)) stroke-width)
  :default-refx 0 :default-refy (float (/ h 2))
  :extra-keys ((stroke-width 1.5)))

;;; Marker emission

(defun resolve-scale (scale-val)
  "Normalize a scale value to (SX SY). Accepts a number, (SX), or (SX SY)."
  (trivia:match scale-val
    ((list sx sy) (list sx sy))
    ((list sx) (list sx sx))
    ((type number) (list scale-val scale-val))
    (_ (list 1 1))))

(defun marker-scaled-content (m sx sy)
  "Return M's SVG content, wrapped in a scale transform unless (SX, SY) is (1, 1)."
  (let ((content (marker-content m)))
    (if (and (= sx 1) (= sy 1))
        content
        (format nil "<g transform=\"scale(~a,~a)\">~a</g>" sx sy content))))

(defun emit-marker (m stream)
  "Write a single <marker> definition for M to STREAM.

The marker's width, height, and reference point are scaled by (SX, SY) so a
single definition can back several scaled references. Size 10 and ref 5 are
the fallbacks used when the struct slots are unset."
  (destructuring-bind (sx sy) (resolve-scale (marker-scale m))
    (let* ((width          (or (marker-markerwidth m) 10))
           (height         (or (marker-markerheight m) 10))
           (ref-x          (or (marker-refx m) 5))
           (ref-y          (or (marker-refy m) 5))
           (scaled-width   (* width  sx))
           (scaled-height  (* height sy))
           (scaled-ref-x   (* ref-x  sx))
           (scaled-ref-y   (* ref-y  sy))
           (orient         (or (marker-orient m) "auto")))
      (format stream "    <marker id=\"~a\" refX=\"~a\" refY=\"~a\" markerWidth=\"~a\" markerHeight=\"~a\"~%"
              (marker-id m) (fmt scaled-ref-x) (fmt scaled-ref-y)
              (fmt scaled-width) (fmt scaled-height))
      (format stream "            viewBox=\"0 0 ~a ~a\" orient=\"~a\" markerUnits=\"userSpaceOnUse\">~%"
              (fmt scaled-width) (fmt scaled-height) orient)
      (format stream "      ~a~%" (marker-scaled-content m sx sy))
      (format stream "    </marker>~%"))))

(defun emit-marker-defs ()
  "Write the <defs> block containing every used marker to the current stream."
  (when *used-markers*
    (let ((stream (current-stream)))
      (format stream "  <defs>~%")
      (dolist (m (reverse *used-markers*))
        (emit-marker m stream))
      (format stream "  </defs>~%"))))

(defun marker-url (name)
  "Get the CSS url() reference for a marker, or downcase the symbol name."
  (alexandria:if-let ((m (use-marker name)))
    (format nil "url(#~a)" (marker-id m))
    (str:downcase (string name))))

(defun reset-markers ()
  (setf *used-markers* nil))

(defun clear-all-markers ()
  (setf *markers* nil)
  (reset-markers))
