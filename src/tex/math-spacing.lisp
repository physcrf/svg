;;;; math-spacing.lisp — TeX 的 8×8 原子间间距表（tex.web L15064）
;;;;
;;;; tex.web 把间距表存成 64 字符的串
;;;;   "0234000122*4000133**3**344*0400400*000000234000111*1111112341011"
;;;; （L15073–15089 的解释）：
;;;;   0 = 无间距
;;;;   1 = 条件 thin   —— 仅当 cur_style < script_style（display/text 系）才插
;;;;   2 = thin        —— 无条件
;;;;   3 = 条件 medium —— 仅非 script 风格
;;;;   4 = 条件 thick  —— 仅非 script 风格
;;;;   * = 不可能组合（bin→ord 转换保证其不可达，tex.web 视为 confusion）
;;;; 行 = 左原子类，列 = 右原子类；类序 ord op bin rel open close punct inner
;;;; （= noad 类型值 ord_noad..inner_noad 的顺序，tex.web L13446–13453）。
;;;;
;;;; plain TeX 的 muskip 默认值：thinmuskip = 3mu，
;;;; medmuskip = 4mu plus 2mu minus 4mu，thickmuskip = 5mu plus 5mu minus 5mu。

(in-package :svg-tex)

(defparameter *math-spacing-classes*
  '(:ord :op :bin :rel :open :close :punct :inner)
  "行/列序：与 TeX noad 类型 ord_noad..inner_noad 一一对应。")

(defparameter *math-spacing-codes*
  (make-array '(8 8)
              :initial-contents
              '((0 2 3 4 0 0 0 1)                ; ord  行
                (2 2 :impossible 4 0 0 0 1)      ; op   行
                (3 3 :impossible :impossible 3 :impossible :impossible 3) ; bin 行
                (4 4 :impossible 0 4 0 0 4)      ; rel  行
                (0 0 :impossible 0 0 0 0 0)      ; open 行
                (0 2 3 4 0 0 0 1)                ; close 行
                (1 1 :impossible 1 1 1 1 1)      ; punct 行
                (1 2 3 4 1 0 1 1)))              ; inner 行
  "TeX 间距码表（tex.web L15064 的 64 字符串按 8×8 行展开）。")

;;; plain TeX muskip 值（mu 单位；med/thick 带伸缩）
(defconstant +thin-mu+ 3)
(defconstant +med-mu+ 4)
(defconstant +med-stretch-mu+ 2)
(defconstant +med-shrink-mu+ 4)
(defconstant +thick-mu+ 5)
(defconstant +thick-stretch-mu+ 5)
(defconstant +thick-shrink-mu+ 5)

(defun spacing-class-index (class)
  "CLASS（:ord..:inner）在间距表中的下标，未知类按 :ord（0）处理。"
  (or (position class *math-spacing-classes*) 0))

(defun math-spacing-code (left-type right-type)
  "查原始间距码（tex.web 语义）：0/1/2/3/4 或 :impossible。"
  (aref *math-spacing-codes*
        (spacing-class-index left-type)
        (spacing-class-index right-type)))

(defun math-style-nonscript-p (style)
  "条件码生效条件：cur_style < script_style（display/cramped-display/text/
cramped-text 四种风格）。"
  (< style script-style))

(defun spacing-code->glue-mu (code style)
  "把间距码在 STYLE 下求值为 (values mu stretch-mu shrink-mu)。
条件码在 script 风格下为 0（tex.web L15077–15080）。"
  (flet ((maybe (mu stretch shrink)
           (if (math-style-nonscript-p style)
               (values mu stretch shrink)
               (values 0 0 0))))
    (case code
      (0            (values 0 0 0))
      (1            (maybe +thin-mu+ 0 0))
      (2            (values +thin-mu+ 0 0))
      (3            (maybe +med-mu+ +med-stretch-mu+ +med-shrink-mu+))
      (4            (maybe +thick-mu+ +thick-stretch-mu+ +thick-shrink-mu+))
      (t            (values 0 0 0)))))          ; :impossible —— 不可达，防御为 0

(defun compute-math-spacing (left-type right-type &optional (style display-style))
  "求 LEFT-TYPE 与 RIGHT-TYPE 之间在 STYLE 下的间距规格：
\(values mu stretch-mu shrink-mu)。间距码见 *math-spacing-codes*。"
  (spacing-code->glue-mu (math-spacing-code left-type right-type) style))

(defun compute-math-spacing-mu (left-type right-type &optional (style display-style))
  "Return the mu value of the spacing between LEFT-TYPE and RIGHT-TYPE in
STYLE, or 0 if none. Conditional codes (thin/med/thick) vanish in script
styles, matching TeX's mlist_to_hlist (tex.web L15073–15089)."
  (nth-value 0 (compute-math-spacing left-type right-type style)))

(defun mu-glue (mu-width mu)
  "Width in sp of MU math units, given MU-WIDTH = width of 1mu in sp.
\(1mu = 1em/18 = math-quad/18; see math-font-mu-width.)"
  (the fixnum (* (the fixnum mu-width) (the fixnum mu))))
