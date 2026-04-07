(in-package #:svg)

(defvar *markers* nil)
(defvar *used-markers* nil)

(defstruct marker
  id
  content
  refx
  refy
  markerwidth
  markerheight
  viewbox
  orient
  scale)

(defun register-marker (m)
  (push m *markers*)
  m)

(defun find-marker (name)
  (find name *markers* :key #'marker-id :test #'equal))

(defun use-marker (name)
  (let ((m (find-marker name)))
    (when m
      (pushnew m *used-markers* :test #'eq))
    m))

(defmacro define-marker (id content &rest rest &key refx refy markerwidth markerheight viewbox orient scale &allow-other-keys)
  `(let ((m (make-marker :id ',id
                          :content ,content
                          :refx ,(or refx 5)
                          :refy ,(or refy 5)
                          :markerwidth ,(or markerwidth 10)
                          :markerheight ,(or markerheight 10)
                          :viewbox ,viewbox
                          :orient ,(or orient "auto")
                          :scale ,scale)))
     (register-marker m)
     m))

(defun %define-arrow (id content &key (refx 0) (refy 5) (markerwidth 10) (markerheight 10) viewbox (orient "auto") scale)
  (let ((m (make-marker :id id
                        :content content
                        :refx refx
                        :refy refy
                        :markerwidth markerwidth
                        :markerheight markerheight
                        :viewbox (or viewbox (format nil "0 0 ~a ~a" markerwidth markerheight))
                        :orient orient
                        :scale scale)))
    (register-marker m)
    m))

(defmacro define-arrow (id &rest rest &key refx refy markerwidth markerheight viewbox orient scale &allow-other-keys)
  (let ((w (or markerwidth 10))
        (h (or markerheight 10)))
    `(%define-arrow ',id
                    (format nil "<path d=\"M0,0 L0,~a L~a,~a z\" fill=\"context-stroke\" />"
                            ,h ,w (/ ,h 2))
                    :refx ,(or refx 0)
                    :refy ,(or refy `(/ ,h 2))
                    :markerwidth ,w
                    :markerheight ,h
                    :viewbox ,(or viewbox `(format nil "0 0 ~a ~a" ,w ,h))
                    :orient ,orient
                    :scale ,scale)))

(defmacro define-circle-dot (id &rest rest &key refx refy markerwidth markerheight viewbox orient scale &allow-other-keys)
  (let ((w (or markerwidth 10))
        (h (or markerheight 10)))
    `(%define-arrow ',id
                    (format nil "<circle cx=\"~a\" cy=\"~a\" r=\"~a\" fill=\"context-stroke\" />"
                            (/ ,w 2) (/ ,h 2) (/ (min ,w ,h) 2))
                    :refx ,(or refx `(/ ,w 2))
                    :refy ,(or refy `(/ ,h 2))
                    :markerwidth ,w
                    :markerheight ,h
                    :viewbox ,(or viewbox `(format nil "0 0 ~a ~a" ,w ,h))
                    :orient ,orient
                    :scale ,scale)))

(defmacro define-square-dot (id &rest rest &key refx refy markerwidth markerheight viewbox orient scale &allow-other-keys)
  (let ((w (or markerwidth 10))
        (h (or markerheight 10)))
    `(%define-arrow ',id
                    (format nil "<rect x=\"0\" y=\"0\" width=\"~a\" height=\"~a\" fill=\"context-stroke\" />"
                            ,w ,h)
                    :refx ,(or refx `(/ ,w 2))
                    :refy ,(or refy `(/ ,h 2))
                    :markerwidth ,w
                    :markerheight ,h
                    :viewbox ,(or viewbox `(format nil "0 0 ~a ~a" ,w ,h))
                    :orient ,orient
                    :scale ,scale)))

(defmacro define-diamond (id &rest rest &key refx refy markerwidth markerheight viewbox orient scale &allow-other-keys)
  (let ((w (or markerwidth 10))
        (h (or markerheight 10)))
    `(%define-arrow ',id
                    (format nil "<path d=\"M~a,0 L~a,~a L~a,~a L0,~a z\" fill=\"context-stroke\" />"
                            (/ ,w 2) ,w (/ ,h 2) (/ ,w 2) ,h (/ ,h 2))
                    :refx ,(or refx `(/ ,w 2))
                    :refy ,(or refy `(/ ,h 2))
                    :markerwidth ,w
                    :markerheight ,h
                    :viewbox ,(or viewbox `(format nil "0 0 ~a ~a" ,w ,h))
                    :orient ,orient
                    :scale ,scale)))

(defmacro define-triangle (id &rest rest &key refx refy markerwidth markerheight viewbox orient scale &allow-other-keys)
  (let ((w (or markerwidth 10))
        (h (or markerheight 10)))
    `(%define-arrow ',id
                    (format nil "<path d=\"M0,0 L0,~a L~a,~a z\" fill=\"context-stroke\" />"
                            ,h ,w (/ ,h 2))
                    :refx ,(or refx 0)
                    :refy ,(or refy `(/ ,h 2))
                    :markerwidth ,w
                    :markerheight ,h
                    :viewbox ,(or viewbox `(format nil "0 0 ~a ~a" ,w ,h))
                    :orient ,orient
                    :scale ,scale)))

(defmacro define-cross (id &rest rest &key refx refy markerwidth markerheight viewbox orient stroke-width scale &allow-other-keys)
  (let ((w (or markerwidth 10))
        (h (or markerheight 10))
        (sw (or stroke-width 2)))
    `(%define-arrow ',id
                    (format nil "<path d=\"M~a,0 L~a,0 M~a,0 L~a,~a M~a,~a L~a,~a\" stroke=\"context-stroke\" stroke-width=\"~a\" fill=\"none\" />"
                            (- (/ ,w 2) ,sw) (+ (/ ,w 2) ,sw)
                            (/ ,w 2) (/ ,w 2) ,h
                            (- (/ ,w 2) ,sw) ,h (+ (/ ,w 2) ,sw) ,h
                            ,sw)
                    :refx ,(or refx `(/ ,w 2))
                    :refy ,(or refy `(/ ,h 2))
                    :markerwidth ,w
                    :markerheight ,h
                    :viewbox ,(or viewbox `(format nil "0 0 ~a ~a" ,w ,h))
                    :orient ,orient
                    :scale ,scale)))

(defmacro define-arrow-open (id &rest rest &key refx refy markerwidth markerheight viewbox orient stroke-width scale &allow-other-keys)
  (let ((w (or markerwidth 10))
        (h (or markerheight 10))
        (sw (or stroke-width 1.5)))
    `(%define-arrow ',id
                    (format nil "<path d=\"M0,0 L0,~a L~a,~a z\" fill=\"white\" stroke=\"context-stroke\" stroke-width=\"~a\" />"
                            ,h ,w (/ ,h 2) ,sw)
                    :refx ,(or refx 0)
                    :refy ,(or refy `(/ ,h 2))
                    :markerwidth ,w
                    :markerheight ,h
                    :viewbox ,(or viewbox `(format nil "0 0 ~a ~a" ,w ,h))
                    :orient ,orient
                    :scale ,scale)))

(defmacro define-arrow-filled (id &rest rest &key refx refy markerwidth markerheight viewbox orient scale &allow-other-keys)
  (let ((w (or markerwidth 10))
        (h (or markerheight 10)))
    `(%define-arrow ',id
                    (format nil "<path d=\"M0,0 L0,~a L~a,~a z\" fill=\"context-stroke\" />"
                            ,h ,w (/ ,h 2))
                    :refx ,(or refx 0)
                    :refy ,(or refy `(/ ,h 2))
                    :markerwidth ,w
                    :markerheight ,h
                    :viewbox ,(or viewbox `(format nil "0 0 ~a ~a" ,w ,h))
                    :orient ,orient
                    :scale ,scale)))

(defun emit-marker-defs ()
  (let ((stream (if *svg* (svg-stream *svg*) *standard-output*)))
    (when *used-markers*
      (format stream "  <defs>~%")
      (dolist (m (reverse *used-markers*))
        (let* ((scale-val (marker-scale m))
               (scale-x (trivia:match scale-val
                          ((list sx _) (or sx 1))
                          ((list sx) (or sx 1))
                          ((type number) (or scale-val 1))
                          (_ 1)))
               (scale-y (trivia:match scale-val
                          ((list _ sy) (or sy scale-x))
                          ((list sx) (or sx 1))
                          ((type number) (or scale-val 1))
                          (_ 1)))
               (base-width (or (marker-markerwidth m) 10))
               (base-height (or (marker-markerheight m) 10))
               (scaled-width (* base-width scale-x))
               (scaled-height (* base-height scale-y))
               (base-refx (or (marker-refx m) 5))
               (base-refy (or (marker-refy m) 5))
               (scaled-refx (* base-refx scale-x))
               (scaled-refy (* base-refy scale-y))
               (scaled-viewbox (format nil "0 0 ~a ~a" scaled-width scaled-height))
               (scaled-content (if (and (= scale-x 1) (= scale-y 1))
                                   (marker-content m)
                                   (format nil "<g transform=\"scale(~a,~a)\">~a</g>" 
                                           scale-x scale-y (marker-content m)))))
          (format stream "    <marker id=\"~a\" refX=\"~a\" refY=\"~a\" markerWidth=\"~a\" markerHeight=\"~a\" viewBox=\"~a\" orient=\"~a\" markerUnits=\"userSpaceOnUse\">~%" 
                  (marker-id m)
                  scaled-refx
                  scaled-refy
                  scaled-width
                  scaled-height
                  scaled-viewbox
                  (or (marker-orient m) "auto"))
          (format stream "      ~a~%" scaled-content)
          (format stream "    </marker>~%")))
      (format stream "  </defs>~%"))))

(defun reset-markers ()
  (setf *used-markers* nil))

(defun marker-url (name)
  (let ((m (use-marker name)))
    (if m
        (format nil "url(#~a)" (marker-id m))
        (string-downcase (string name)))))

(defun clear-all-markers ()
  (setf *markers* nil)
  (reset-markers))
