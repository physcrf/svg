(in-package #:svg)

;;; Path command macros — each defines both absolute (uppercase) and relative (lowercase) variants.

(defmacro def-path-cmd (abs-name abs-letter abs-params rel-params format-string &rest format-args)
  "Define absolute and relative SVG path command functions.
   ABS-LETTER is the uppercase SVG command letter; the lowercase variant is automatic."
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

;;; Arc commands (separate because they have keyword parameters)

(defun %arc (letter radii point &key (x-axis-rotation 0) (large-arc-flag 0) (sweep-flag 1))
  "Internal: generate an arc path command with the given LETTER (A or a)."
  (format nil "~a ~a ~a ~a ~a ~a ~a,~a"
          letter (fmt (x radii)) (fmt (y radii))
          (fmt x-axis-rotation) large-arc-flag sweep-flag
          (fmt (x point)) (fmt (y point))))

(defun arc (radii point &key (x-axis-rotation 0) (large-arc-flag 0) (sweep-flag 1))
  "Absolute arc path command (A)."
  (%arc #\A radii point
        :x-axis-rotation x-axis-rotation
        :large-arc-flag large-arc-flag
        :sweep-flag sweep-flag))

(defun arc* (radii dpoint &key (x-axis-rotation 0) (large-arc-flag 0) (sweep-flag 1))
  "Relative arc path command (a)."
  (%arc #\a radii dpoint
        :x-axis-rotation x-axis-rotation
        :large-arc-flag large-arc-flag
        :sweep-flag sweep-flag))

(defun closepath ()
  "Emit the SVG closepath command (Z)."
  "Z")

(defmacro path (commands &rest attrs &key &allow-other-keys)
  "Create an SVG <path> element from a list of path command forms.
COMMANDS is a list of path-command forms (moveto, lineto, ...); ATTRS are
keyword attributes, evaluated like any other shape primitive's attributes."
  `(write-element "path"
                  (append (list 'd (str:join " " (list ,@commands)))
                          (list ,@attrs))))
