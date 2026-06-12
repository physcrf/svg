(in-package #:svg)

(defun fmt (value)
  (if (integerp value)
      (format nil "~d" value)
      (format nil "~,2f" value)))

(defmacro def-transform (name format-string args)
  `(defun ,name ,args
     (format nil ,format-string ,@(loop for s in args collect `(fmt ,s)))))

(def-transform translate "translate(~a,~a)" (tx ty))
(def-transform skew-x "skewX(~a)" (angle))
(def-transform skew-y "skewY(~a)" (angle))

(defun rotate (angle &optional cx cy)
  (if (and cx cy)
      (format nil "rotate(~a ~a,~a)" (fmt angle) (fmt cx) (fmt cy))
      (format nil "rotate(~a)" (fmt angle))))

(defun scale (sx &optional sy)
  (if sy
      (format nil "scale(~a,~a)" (fmt sx) (fmt sy))
      (format nil "scale(~a)" (fmt sx))))

(defun matrix (a b c d e f)
  (format nil "matrix(~a ~a ~a ~a ~a ~a)" (fmt a) (fmt b) (fmt c) (fmt d) (fmt e) (fmt f)))

(defun title (text-content)
  (write-element "title" nil text-content))

(defun desc (text-content)
  (write-element "desc" nil text-content))

(defun script (content &rest attrs)
  (apply #'write-element "script" (append attrs (list content))))

(defun viewbox (min-x min-y width height)
  (format nil "~a ~a ~a ~a" min-x min-y width height))

;; Unit conversion functions (convert to pixels, SVG default unit)
;; SVG standard: 1in = 96px
(defconstant +cm-to-px+ (/ 96 2.54))
(defconstant +mm-to-px+ (/ 96 25.4))
(defconstant +pt-to-px+ (/ 96 72))

(defun px (x) x)
(defun in (x) (* x 96))
(defun cm (x) (* x +cm-to-px+))
(defun mm (x) (* x +mm-to-px+))
(defun pt (x) (* x +pt-to-px+))
(defun pc (x) (* x 16))
