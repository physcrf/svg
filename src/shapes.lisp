(in-package #:svg)

;;; Shape primitives.
;;;
;;; Each shape takes its geometry as complex-number points (a single position
;;; or a list of points) plus &rest keyword attributes. The attributes are
;;; passed straight through to `write-element`, which merges them with the
;;; global defaults (see attributes.lisp) and serializes them to SVG.
;;; Transform keywords (`:translate`, `:rotate`, ...) are folded into a single
;;; trailing `transform` attribute.

(defun points-to-string (points)
  "Convert a list of points to an SVG points attribute string."
  (str:join " " (mapcar (lambda (p) (format nil "~a,~a" (fmt (x p)) (fmt (y p)))) points)))

(defun circle (center r &rest rest &key &allow-other-keys)
  (write-element "circle"
                 (append (list 'cx (x center) 'cy (y center) 'r r) rest)))

(defun rect (position width height &rest rest &key rx ry &allow-other-keys)
  (let ((clean-rest (alexandria:remove-from-plist rest :rx :ry)))
    (write-element "rect"
                   (append (list 'x (x position) 'y (y position) 'width width 'height height)
                           (when rx (list 'rx rx))
                           (when ry (list 'ry ry))
                           (when (and rx (not ry)) (list 'ry rx))
                           clean-rest))))

(defun ellipse (center rx ry &rest rest &key &allow-other-keys)
  (write-element "ellipse"
                 (append (list 'cx (x center) 'cy (y center) 'rx rx 'ry ry) rest)))

(defun line (start end &rest rest &key &allow-other-keys)
  (write-element "line"
                 (append (list 'x1 (x start) 'y1 (y start) 'x2 (x end) 'y2 (y end)) rest)))

(defun polyline (points &rest rest &key &allow-other-keys)
  (check-type points list)
  (write-element "polyline" (append (list 'points (points-to-string points)) rest)))

(defun polygon (points &rest rest &key &allow-other-keys)
  (check-type points list)
  (write-element "polygon" (append (list 'points (points-to-string points)) rest)))

(defun text (position content &rest attrs &key &allow-other-keys)
  "Write a <text> element at POSITION with CONTENT and attributes."
  (check-type position number)
  (write-element "text"
                 (append (list 'x (x position) 'y (y position)) attrs)
                 content))
