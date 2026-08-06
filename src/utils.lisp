(in-package #:svg)

(defun p (x y)
  "Create a 2D point as a complex number."
  (complex x y))

(defun x (point)
  "Get the X coordinate (real part) of a point."
  (realpart point))

(defun y (point)
  "Get the Y coordinate (imaginary part) of a point."
  (imagpart point))

(defun fmt (value)
  "Format a number for SVG output: integers as-is, floats to 2 decimal places.
   For extreme values where fixed-point loses precision, scientific notation is used.
   Values up to 0.005 would round to \"0.00\" (or \"-0.00\") and silently lose
   precision, so they fall back to scientific notation too."
  (cond ((integerp value) (format nil "~d" value))
        ((complexp value) (format nil "~a,~a" (fmt (realpart value)) (fmt (imagpart value))))
        ((floatp value)
         (let ((absval (abs value)))
           (if (or (and (not (zerop absval)) (<= absval 0.005))
                   (> absval 1000000))
               (format nil "~,6e" value)
               (format nil "~,2f" value))))
        (t (format nil "~,2f" value))))

(defun xml-escape (string)
  "Escape XML special characters in STRING for safe insertion as element content."
  (if (stringp string)
      (with-output-to-string (out)
        (loop for char across string
              do (case char
                   (#\< (write-string "&lt;" out))
                   (#\> (write-string "&gt;" out))
                   (#\& (write-string "&amp;" out))
                   (#\" (write-string "&quot;" out))
                   (#\' (write-string "&apos;" out))
                   (otherwise (write-char char out)))))
      string))

;;; Transform functions

(defmacro def-transform (name format-string args)
  "Define a simple SVG transform function that formats its arguments."
  `(defun ,name ,args
     (format nil ,format-string ,@(mapcar (lambda (s) `(fmt ,s)) args))))

(def-transform translate "translate(~a,~a)" (tx ty))
(def-transform skew-x "skewX(~a)" (angle))
(def-transform skew-y "skewY(~a)" (angle))

(defun rotate (angle &optional cx cy)
  "SVG rotate transform. With CX/CY, rotates around (CX, CY)."
  (cond ((and cx cy)
         (format nil "rotate(~a ~a,~a)" (fmt angle) (fmt cx) (fmt cy)))
        (cx (error "rotate: CX given without CY — pass both or neither"))
        (t (format nil "rotate(~a)" (fmt angle)))))

(defun scale (sx &optional sy)
  "SVG scale transform. With SY, scales X and Y independently."
  (if sy
      (format nil "scale(~a,~a)" (fmt sx) (fmt sy))
      (format nil "scale(~a)" (fmt sx))))

(defun matrix (a b c d e f)
  "SVG matrix transform."
  (format nil "matrix(~a ~a ~a ~a ~a ~a)" (fmt a) (fmt b) (fmt c) (fmt d) (fmt e) (fmt f)))

;;; SVG metadata elements

(defun title (text-content)
  "Write a <title> element (accessible document title)."
  (write-element "title" nil text-content))

(defun desc (text-content)
  "Write a <desc> element (accessible description)."
  (write-element "desc" nil text-content))

(defun script (content &rest attrs)
  "Write a <script> element with CONTENT and optional attributes.
   CONTENT is written verbatim (no XML escaping) so JavaScript is not mangled."
  (write-raw-element "script" attrs content))

(defun viewbox (min-x min-y width height)
  "Construct a viewBox attribute value."
  (format nil "~a ~a ~a ~a" (fmt min-x) (fmt min-y) (fmt width) (fmt height)))

;;; Unit conversion (convert to pixels, SVG standard: 1in = 96px)

(defmacro def-unit (name factor &optional docstring)
  "Define a unit conversion function: NAME(x) = x * FACTOR."
  `(defun ,name (x) ,@(when docstring (list docstring)) (* x ,factor)))

(def-unit px 1 "Identity: pixels are already pixels.")
(def-unit in 96 "Inches to pixels (1in = 96px).")
(def-unit cm #.(/ 96 2.54) "Centimeters to pixels.")
(def-unit mm #.(/ 96 25.4) "Millimeters to pixels.")
(def-unit pt #.(/ 96 72) "Points to pixels (1pt = 1/72in).")
(def-unit pc 16 "Picas to pixels (1pc = 12pt).")
