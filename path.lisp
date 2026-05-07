(in-package #:svg)

(defmacro def-path-cmd (abs-name abs-letter abs-params rel-params format-string &rest format-args)
  (let ((abs-fn (intern (string-upcase abs-name) (find-package :svg)))
        (rel-fn (intern (format nil "~a*" (string-upcase abs-name)) (find-package :svg)))
        (rel-letter (char-downcase abs-letter)))
    `(progn
       (defun ,abs-fn ,abs-params
         (format nil ,(format nil "~a ~a" abs-letter format-string) ,@format-args))
       (defun ,rel-fn ,rel-params
         (format nil ,(format nil "~a ~a" rel-letter format-string) ,@format-args)))))

(def-path-cmd "moveto" #\M (point) (dpoint) "~a,~a" (fmt (x point)) (fmt (y point)))
(def-path-cmd "lineto" #\L (point) (dpoint) "~a,~a" (fmt (x point)) (fmt (y point)))
(def-path-cmd "hlineto" #\H (x) (dx) "~a" (fmt x))
(def-path-cmd "vlineto" #\V (y) (dy) "~a" (fmt y))
(def-path-cmd "curveto" #\C (p1 p2 p3) (dp1 dp2 dp3) "~a,~a ~a,~a ~a,~a"
              (fmt (x p1)) (fmt (y p1)) (fmt (x p2)) (fmt (y p2)) (fmt (x p3)) (fmt (y p3)))
(def-path-cmd "smooth-curveto" #\S (p2 p3) (dp2 dp3) "~a,~a ~a,~a"
              (fmt (x p2)) (fmt (y p2)) (fmt (x p3)) (fmt (y p3)))
(def-path-cmd "quadto" #\Q (p1 p2) (dp1 dp2) "~a,~a ~a,~a"
              (fmt (x p1)) (fmt (y p1)) (fmt (x p2)) (fmt (y p2)))
(def-path-cmd "smooth-quadto" #\T (point) (dpoint) "~a,~a" (fmt (x point)) (fmt (y point)))

(defun arc (radii point &key (x-axis-rotation 0) (large-arc-flag 0) (sweep-flag 1))
  (format nil "A ~a ~a ~a ~a ~a ~a,~a"
          (fmt (x radii)) (fmt (y radii))
          (fmt x-axis-rotation) large-arc-flag sweep-flag
          (fmt (x point)) (fmt (y point))))

(defun arc* (radii dpoint &key (x-axis-rotation 0) (large-arc-flag 0) (sweep-flag 1))
  (format nil "a ~a ~a ~a ~a ~a ~a,~a"
          (fmt (x radii)) (fmt (y radii))
          (fmt x-axis-rotation) large-arc-flag sweep-flag
          (fmt (x dpoint)) (fmt (y dpoint))))

(defun closepath () "Z")

(defmacro path (commands &rest attrs &key &allow-other-keys)
  `(write-element "path"
                  (append (list 'd (format nil "~{~a ~}" (list ,@commands)))
                          ',attrs)))
