;;;; scaled.lisp — scaled fixed-point arithmetic
;;;;
;;;; 1pt = 65536 sp (scaled points), matching Knuth's TeX.
;;;; All box geometry and font metrics are expressed in sp as fixnums.
;;;; This module provides the scaled-* API declared in package.lisp.

(in-package :svg-tex)

(defconstant +scaled-one+ 65536)            ; 1pt in sp
(defconstant +scaled-point+ 65536)          ; alias
(defconstant +scaled-bp+ 65781)             ; 1 big-point (72bp = 1in) in sp
(defconstant +scaled-zero+ 0)

(defparameter *scaled-base* 65536)          ; sp per pt
(defparameter *scaled-base-f* 65536.0d0)   ; as double for float conversions

(deftype scaled () 'fixnum)                ; 64-bit sbcl fixnum holds ±2^62 sp

(declaim (inline scaledp scaled+ scaled- scaled-abs
                 scaled-= scaled-< scaled-> scaled-<= scaled->=
                 scaled-min scaled-max scaled-half
                 scaled-from-sp scaled-to-sp scaled-from-fix scaled-wrap))

(defun scaledp (x) (integerp x))

(defun scaled+ (a b) (the fixnum (+ (the fixnum a) (the fixnum b))))
(defun scaled- (a b) (the fixnum (- (the fixnum a) (the fixnum b))))
(defun scaled-abs (a) (the fixnum (abs (the fixnum a))))

(defun scaled* (a b)
  "Fixed-point multiply: result in sp. (a * b) / +scaled-one+."
  (the fixnum (truncate (/ (* (the fixnum a) (the fixnum b)) +scaled-one+))))

(defun scaled/ (a b)
  "Fixed-point divide: result in sp. (a * +scaled-one+) / b."
  (the fixnum (truncate (/ (* (the fixnum a) +scaled-one+) (the fixnum b)))))

(defun scaled-= (a b) (= (the fixnum a) (the fixnum b)))
(defun scaled-< (a b) (< (the fixnum a) (the fixnum b)))
(defun scaled-> (a b) (> (the fixnum a) (the fixnum b)))
(defun scaled-<= (a b) (<= (the fixnum a) (the fixnum b)))
(defun scaled->= (a b) (>= (the fixnum a) (the fixnum b)))
(defun scaled-min (a b) (the fixnum (min (the fixnum a) (the fixnum b))))
(defun scaled-max (a b) (the fixnum (max (the fixnum a) (the fixnum b))))
(defun scaled-half (a) (the fixnum (ash (the fixnum a) -1)))

(defun scaled-from-pt (pt)
  "Convert points (integer or ratio) to sp."
  (the fixnum (truncate (* pt +scaled-one+))))

(defun scaled-to-pt (s)
  "Convert sp to points (double-float)."
  (/ (the fixnum s) *scaled-base-f*))

(defun scaled-from-bp (bp)
  "Convert big-points to sp. 1bp = 65781 sp."
  (the fixnum (truncate (* bp +scaled-bp+))))

(defun scaled-to-bp (s)
  "Convert sp to big-points (double-float)."
  (/ (the fixnum s) (coerce +scaled-bp+ 'double-float)))

(defun scaled-from-sp (sp) (the fixnum sp))
(defun scaled-to-sp (s) (the fixnum s))
(defun scaled-from-fix (n) (the fixnum n))
(defun scaled-wrap (n) (the fixnum n))
