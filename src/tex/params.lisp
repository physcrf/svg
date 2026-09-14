;;;; params.lisp — named math font parameter keys
;;;;
;;;; Replaces the positional 24-element param array (where slot 8 was
;;;; ambiguous between num1 and default-rule-thickness). Each parameter
;;;; is a distinct keyword key, eliminating the slot collision at the root.

(in-package :svg-tex)

(defparameter *font-param-count* 23)
(defparameter *math-family-count* 4)               ; cmr/cmmi/cmsy/cmex

(defconstant +param-num1+ :num1)
(defconstant +param-num2+ :num2)
(defconstant +param-num3+ :num3)
(defconstant +param-denom1+ :denom1)
(defconstant +param-denom2+ :denom2)
(defconstant +param-sup1+ :sup1)
(defconstant +param-sup2+ :sup2)
(defconstant +param-sup3+ :sup3)
(defconstant +param-sub1+ :sub1)
(defconstant +param-sub2+ :sub2)
(defconstant +param-sup-drop+ :sup-drop)
(defconstant +param-sub-drop+ :sub-drop)
(defconstant +param-delim1+ :delim1)
(defconstant +param-delim2+ :delim2)
(defconstant +param-axis-height+ :axis-height)
(defconstant +param-default-rule-thickness+ :default-rule-thickness)
(defconstant +param-big-op-spacing1+ :big-op-spacing1)
(defconstant +param-big-op-spacing2+ :big-op-spacing2)
(defconstant +param-big-op-spacing3+ :big-op-spacing3)
(defconstant +param-big-op-spacing4+ :big-op-spacing4)
(defconstant +param-big-op-spacing5+ :big-op-spacing5)
(defconstant +param-x-height+ :x-height)
(defconstant +param-quad+ :quad)

;;; \scriptspace（tex.web L5314）：sub/sup 盒宽的额外空隙，plain TeX 默认 0.5pt。
(defconstant +script-space+ 32768)

;;; \nulldelimiterspace（tex.web L13930）：null 定界符盒的宽度，plain TeX 1.2pt。
(defconstant +null-delimiter-space+ 78643)

;;; plain TeX 的 \delimiterfactor（901）与 \delimitershortfall（5pt），
;;; 用于 \left...\right 的目标高度公式（tex.web make_left_right L15025–15027）。
(defconstant +delimiter-factor+ 901)
(defconstant +delimiter-shortfall+ 327680)

(defun tex-half (x)
  "tex.web half（L2168–2171）：奇数 → (x+1)/2（向 +∞ 取整），偶数 → x/2。
  Pascal div 截断向零，配合 (+ x 1) 恰为向 +∞ 取整（half(-5)=-2）。"
  (if (oddp x) (ash (1+ x) -1) (ash x -1)))
