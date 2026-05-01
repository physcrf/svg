(in-package #:svg)

(defun points-to-string (points)
  (format nil "~{~a,~a ~}"
          (alexandria:mappend (lambda (p) (list (x p) (y p))) points)))

(defun circle (center r &rest rest &key &allow-other-keys)
  (write-element "circle"
                 (append (list 'cx (x center) 'cy (y center) 'r r) rest)))

(defun rect (position width height &rest rest &key rx ry &allow-other-keys)
  (write-element "rect"
                 (append (list 'x (x position) 'y (y position) 'width width 'height height)
                         (when rx (list 'rx rx))
                         (when ry (list 'ry ry))
                         (remove-from-plist rest :rx :ry))))

(defun ellipse (center rx ry &rest rest &key &allow-other-keys)
  (write-element "ellipse"
                 (append (list 'cx (x center) 'cy (y center) 'rx rx 'ry ry) rest)))

(defun line (start end &rest rest &key &allow-other-keys)
  (write-element "line"
                 (append (list 'x1 (x start) 'y1 (y start) 'x2 (x end) 'y2 (y end)) rest)))

(defun polyline (points &rest rest &key &allow-other-keys)
  (write-element "polyline"
                 (append (list 'points (points-to-string points)) rest)))

(defun polygon (points &rest rest &key &allow-other-keys)
  (write-element "polygon"
                 (append (list 'points (points-to-string points)) rest)))
