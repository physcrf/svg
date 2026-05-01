(in-package #:svg)

(defun remove-from-plist (plist &rest keys)
  (loop for (key value) on plist by #'cddr
        unless (member key keys)
        append (list key value)))

(defun fmt (value)
  (alexandria:if-let ((int (ignore-errors (coerce value 'integer))))
    (format nil "~d" int)
    (format nil "~,2f" value)))

(defun translate (tx ty)
  (format nil "translate(~a,~a)" (fmt tx) (fmt ty)))

(defun rotate (angle &optional cx cy)
  (if (and cx cy)
      (format nil "rotate(~a ~a,~a)" (fmt angle) (fmt cx) (fmt cy))
      (format nil "rotate(~a)" (fmt angle))))

(defun scale (sx &optional sy)
  (if sy
      (format nil "scale(~a,~a)" (fmt sx) (fmt sy))
      (format nil "scale(~a)" (fmt sx))))

(defun skew-x (angle)
  (format nil "skewX(~a)" (fmt angle)))

(defun skew-y (angle)
  (format nil "skewY(~a)" (fmt angle)))

(defun matrix (a b c d e f)
  (format nil "matrix(~a ~a ~a ~a ~a ~a)" a b c d e f))

(defun title (text-content)
  (write-element "title" nil text-content))

(defun desc (text-content)
  (write-element "desc" nil text-content))

(defun script (content &rest attrs)
  (apply #'write-element "script" (append attrs (list content))))

(defun viewbox (min-x min-y width height)
  (format nil "~a ~a ~a ~a" min-x min-y width height))
