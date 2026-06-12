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

(defmacro def-simple-marker (name (content-fmt &rest fmt-args) &key (default-refx 5) (default-refy 5))
  `(defmacro ,name (id &rest rest &key refx refy markerwidth markerheight viewbox orient scale &allow-other-keys)
     (let ((w (or markerwidth 10)) (h (or markerheight 10)))
       `(define-marker ',id
                       ,(format nil ,content-fmt ,@fmt-args)
                       :refx ,(or refx ,default-refx) :refy ,(or refy ,default-refy)
                       :markerwidth ,w :markerheight ,h
                       :viewbox ,(or viewbox (format nil "0 0 ~a ~a" w h))
                       :orient ,(or orient "auto") :scale ,scale))))

(def-simple-marker define-arrow ("<path d=\"M0,0 L0,~a L~a,~a z\" fill=\"context-stroke\" />" h w (/ h 2))
  :default-refx 0 :default-refy (/ h 2))

(def-simple-marker define-circle-dot ("<circle cx=\"~a\" cy=\"~a\" r=\"~a\" fill=\"context-stroke\" />" (/ w 2) (/ h 2) (/ (min w h) 2))
  :default-refx (/ w 2) :default-refy (/ h 2))

(def-simple-marker define-square-dot ("<rect x=\"0\" y=\"0\" width=\"~a\" height=\"~a\" fill=\"context-stroke\" />" w h)
  :default-refx (/ w 2) :default-refy (/ h 2))

(def-simple-marker define-triangle ("<path d=\"M0,0 L0,~a L~a,~a z\" fill=\"context-stroke\" />" h w (/ h 2))
  :default-refx 0 :default-refy (/ h 2))

(defmacro define-diamond (id &rest rest &key refx refy markerwidth markerheight viewbox orient scale &allow-other-keys)
  (let ((w (or markerwidth 10)) (h (or markerheight 10)))
    `(define-marker ',id
                    ,(format nil "<path d=\"M~a,0 L~a,~a L~a,~a L0,~a z\" fill=\"context-stroke\" />"
                             (/ w 2) w (/ h 2) (/ w 2) h (/ h 2))
                    :refx ,(or refx (/ w 2)) :refy ,(or refy (/ h 2))
                    :markerwidth ,w :markerheight ,h
                    :viewbox ,(or viewbox (format nil "0 0 ~a ~a" w h))
                    :orient ,(or orient "auto") :scale ,scale)))

(defmacro define-cross (id &rest rest &key refx refy markerwidth markerheight viewbox orient stroke-width scale &allow-other-keys)
  (let ((w (or markerwidth 10)) (h (or markerheight 10)) (sw (or stroke-width 2)))
    `(define-marker ',id
                    ,(format nil "<path d=\"M~a,0 L~a,0 M~a,0 L~a,~a M~a,~a L~a,~a\" stroke=\"context-stroke\" stroke-width=\"~a\" fill=\"none\" />"
                             (- (/ w 2) sw) (+ (/ w 2) sw) (/ w 2) (/ w 2) h (- (/ w 2) sw) h (+ (/ w 2) sw) h sw)
                    :refx ,(or refx (/ w 2)) :refy ,(or refy (/ h 2))
                    :markerwidth ,w :markerheight ,h
                    :viewbox ,(or viewbox (format nil "0 0 ~a ~a" w h))
                    :orient ,(or orient "auto") :scale ,scale)))

(defmacro define-arrow-open (id &rest rest &key refx refy markerwidth markerheight viewbox orient stroke-width scale &allow-other-keys)
  (let ((w (or markerwidth 10)) (h (or markerheight 10)) (sw (or stroke-width 1.5)))
    `(define-marker ',id
                    ,(format nil "<path d=\"M0,0 L0,~a L~a,~a z\" fill=\"white\" stroke=\"context-stroke\" stroke-width=\"~a\" />" h w (/ h 2) sw)
                    :refx ,(or refx 0) :refy ,(or refy (/ h 2))
                    :markerwidth ,w :markerheight ,h
                    :viewbox ,(or viewbox (format nil "0 0 ~a ~a" w h))
                    :orient ,(or orient "auto") :scale ,scale)))

(defun resolve-scale (scale-val)
  (trivia:match scale-val
    ((list sx sy) (list sx sy))
    ((list sx) (list sx sx))
    ((type number) (list scale-val scale-val))
    (_ (list 1 1))))

(defun emit-marker-defs ()
  (let ((stream (current-stream)))
    (when *used-markers*
      (format stream "  <defs>~%")
      (dolist (m (reverse *used-markers*))
        (let* ((sv (resolve-scale (marker-scale m)))
               (sx (first sv)) (sy (second sv))
               (bw (or (marker-markerwidth m) 10)) (bh (or (marker-markerheight m) 10))
               (sw (* bw sx)) (sh (* bh sy))
               (brx (or (marker-refx m) 5)) (bry (or (marker-refy m) 5))
               (srx (* brx sx)) (sry (* bry sy)))
          (format stream "    <marker id=\"~a\" refX=\"~a\" refY=\"~a\" markerWidth=\"~a\" markerHeight=\"~a\" viewBox=\"0 0 ~a ~a\" orient=\"~a\" markerUnits=\"userSpaceOnUse\">~%"
                  (marker-id m) (fmt srx) (fmt sry) (fmt sw) (fmt sh) (fmt sw) (fmt sh) (or (marker-orient m) "auto"))
          (format stream "      ~a~%" (if (and (= sx 1) (= sy 1))
                                          (marker-content m)
                                          (format nil "<g transform=\"scale(~a,~a)\">~a</g>" sx sy (marker-content m))))
          (format stream "    </marker>~%")))
      (format stream "  </defs>~%"))))

(defun marker-url (name)
  (alexandria:if-let ((m (use-marker name)))
    (format nil "url(#~a)" (marker-id m))
    (string-downcase (string name))))

(defun reset-markers ()
  (setf *used-markers* nil))

(defun clear-all-markers ()
  (setf *markers* nil)
  (reset-markers))
