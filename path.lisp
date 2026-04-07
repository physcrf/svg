(in-package #:svg)

(defun moveto (point)
  (format nil "M ~a,~a" (fmt (x point)) (fmt (y point))))

(defun lineto (point)
  (format nil "L ~a,~a" (fmt (x point)) (fmt (y point))))

(defun hlineto (x)
  (format nil "H ~a" (fmt x)))

(defun vlineto (y)
  (format nil "V ~a" (fmt y)))

(defun curveto (p1 p2 p3)
  (format nil "C ~a,~a ~a,~a ~a,~a"
          (fmt (x p1)) (fmt (y p1))
          (fmt (x p2)) (fmt (y p2))
          (fmt (x p3)) (fmt (y p3))))

(defun smooth-curveto (p2 p3)
  (format nil "S ~a,~a ~a,~a"
          (fmt (x p2)) (fmt (y p2))
          (fmt (x p3)) (fmt (y p3))))

(defun quadto (p1 p2)
  (format nil "Q ~a,~a ~a,~a"
          (fmt (x p1)) (fmt (y p1))
          (fmt (x p2)) (fmt (y p2))))

(defun smooth-quadto (point)
  (format nil "T ~a,~a" (fmt (x point)) (fmt (y point))))

(defun arc (radii point &key (x-axis-rotation 0) (large-arc-flag 0) (sweep-flag 1))
  (format nil "A ~a ~a ~a ~a ~a ~a,~a"
          (fmt (x radii)) (fmt (y radii))
          (fmt x-axis-rotation) large-arc-flag sweep-flag
          (fmt (x point)) (fmt (y point))))

(defun closepath ()
  "Z")

(defun moveto* (dpoint)
  (format nil "m ~a,~a" (fmt (x dpoint)) (fmt (y dpoint))))

(defun lineto* (dpoint)
  (format nil "l ~a,~a" (fmt (x dpoint)) (fmt (y dpoint))))

(defun hlineto* (dx)
  (format nil "h ~a" (fmt dx)))

(defun vlineto* (dy)
  (format nil "v ~a" (fmt dy)))

(defun curveto* (dp1 dp2 dp3)
  (format nil "c ~a,~a ~a,~a ~a,~a"
          (fmt (x dp1)) (fmt (y dp1))
          (fmt (x dp2)) (fmt (y dp2))
          (fmt (x dp3)) (fmt (y dp3))))

(defun smooth-curveto* (dp2 dp3)
  (format nil "s ~a,~a ~a,~a"
          (fmt (x dp2)) (fmt (y dp2))
          (fmt (x dp3)) (fmt (y dp3))))

(defun quadto* (dp1 dp2)
  (format nil "q ~a,~a ~a,~a"
          (fmt (x dp1)) (fmt (y dp1))
          (fmt (x dp2)) (fmt (y dp2))))

(defun smooth-quadto* (dpoint)
  (format nil "t ~a,~a" (fmt (x dpoint)) (fmt (y dpoint))))

(defun arc* (radii dpoint &key (x-axis-rotation 0) (large-arc-flag 0) (sweep-flag 1))
  (format nil "a ~a ~a ~a ~a ~a ~a,~a"
          (fmt (x radii)) (fmt (y radii))
          (fmt x-axis-rotation) large-arc-flag sweep-flag
          (fmt (x dpoint)) (fmt (y dpoint))))

(defmacro path (commands &rest attrs &key &allow-other-keys)
  `(write-element "path"
                  (append (list 'd (format nil "~{~a ~}" (list ,@commands)))
                          ',attrs)))
