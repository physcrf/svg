;;;; math-font.lisp — CLOS math font with named-key parameter table
;;;;
;;;; A math font carries the TFM metrics TeX's `fetch`/`char_info` need
;;;; (per-character width/height/depth/italic plus variant chains) and the
;;;; `font_info` math parameters (tex.web mathsy/mathex fontdimens) used by
;;;; mlist_to_hlist. Parameters are stored in an eq-hash-table keyed by
;;;; +param-*+ symbols.

(in-package :svg-tex)

(defclass math-font ()
  ((family           :reader math-font-family           :initarg :family           :type (integer 0 15))
   (name             :reader math-font-name             :initarg :name             :type (or null string))
   (design-size      :reader math-font-design-size      :initarg :design-size      :initform 0 :type fixnum)
   (size             :accessor math-font-size          :initarg :size             :initform 0 :type fixnum)
   (params           :reader math-font-params           :initform (make-hash-table :test 'eq))
   (chars            :reader math-font-chars            :initform (make-hash-table :test 'eql))
   (larger-variants  :reader math-font-larger-variants  :initform (make-hash-table :test 'eql))
   (smaller-variants :reader math-font-smaller-variants :initform (make-hash-table :test 'eql))
   (extensible-parts :reader math-font-extensible-parts :initform (make-hash-table :test 'eql))
   (skew-chars       :reader math-font-skew-chars       :initform (make-hash-table :test 'eql))
   ;; The same family at text (10pt) size. CM's script sizes are separate
   ;; optical designs; the renderer needs the 10pt metrics to compensate for
   ;; Latin Modern Math shipping a single design.
   (ten-point        :accessor math-font-ten-point      :initform nil)))

(defun make-math-font (&key family name (size 0) (design-size 0))
  (make-instance 'math-font :family family :name name :size size :design-size design-size))

(defun math-font-p (x) (typep x 'math-font))

;;; Parameter access (key is a +param-*+ symbol)

(defun math-font-param (font key)
  (gethash key (math-font-params font) 0))

(defun (setf math-font-param) (value font key)
  (setf (gethash key (math-font-params font)) value))

(defun set-math-font-param (font key value)
  (setf (math-font-param font key) value))

;;; Convenience accessors

(defun math-font-default-rule-thickness (font) (math-font-param font +param-default-rule-thickness+))
(defun math-font-axis-height            (font) (math-font-param font +param-axis-height+))
(defun math-font-x-height               (font) (math-font-param font +param-x-height+))
(defun math-font-math-quad              (font) (math-font-param font +param-quad+))
(defun math-font-mu-width               (font) (floor (math-font-math-quad font) 18))

(defun math-font-for (fonts family size-code)
  "tex.web font(fam, cur_size)：字体向量按 (family + 4×size-code) 槽位选取
真实 CM 字体（0–3 text / 4–7 script / 8–11 scriptscript；fam3 三个槽位都是
cmex10，与 plain TeX 的 \\scriptfont3=\\textfont3=\\tenex 一致）。"
  (or (aref fonts (+ family (* 4 size-code)))
      (aref fonts family)))

(defun math-font-param-family (param)
  "The math family a named parameter belongs to (tex.web mathsy/mathex).
  * x-height, quad            → fam0 (cmr, \\fontdimen5/6);
  * num*/denom*/sup*/sub*/sup_drop/sub_drop/delim*/axis → fam2 (mathsy);
  * default-rule-thickness, big-op-spacing1–5          → fam3 (mathex)."
  (cond ((member param (list +param-x-height+ +param-quad+)) 0)
        ((member param (list +param-default-rule-thickness+
                             +param-big-op-spacing1+
                             +param-big-op-spacing2+
                             +param-big-op-spacing3+
                             +param-big-op-spacing4+
                             +param-big-op-spacing5+)) 3)
        (t 2)))

(defun math-font-param-at-size (fonts param size-code)
  "Named math parameter at an explicit size code (0/1/2), independent of a
style. Used by make_scripts for sup_drop/sub_drop at script sizes."
  (let ((font (math-font-for fonts (math-font-param-family param) size-code)))
    (if font (math-font-param font param) 0)))

(defun math-font-style-param (fonts param style)
  "tex.web L13813–13814 的字号参数语义：参数取自【参数所属族】在 cur_size
的真实字体（不做 0.7/0.5 缩放——7pt/5pt CM 字体有自有的 fontdimen）。
族归属（tex.web @d math_x_height/math_quad/mathsy/mathex）：
  * x-height、quad → fam0（cmr，\\fontdimen5/6）；
  * num*/denom*/sup*/sub*/sup_drop/sub_drop/delim*/axis → fam2（cmsy）；
  * default-rule-thickness、big-op-spacing1–5 → fam3（cmex，mathex）。"
  (math-font-param-at-size fonts param (math-style-size-code style)))

(defun font-x-height (font fonts size-code)
  "x-height of FONT, falling back to family 0 when FONT does not carry an
:x-height parameter (tex.web x_height(f) uses the font's own fontdimen 5;
our cmsy tables omit it because it equals cmr's)."
  (let ((v (math-font-param font +param-x-height+)))
    (if (plusp v) v (math-font-param-at-size fonts +param-x-height+ size-code))))

;;; Character metrics

(defun math-font-get-char (font char-code)
  (gethash char-code (math-font-chars font)))

(defun math-font-char-width  (font char-code)
  (let ((m (gethash char-code (math-font-chars font)))) (if m (first m) 0)))
(defun math-font-char-height (font char-code)
  (let ((m (gethash char-code (math-font-chars font)))) (if m (second m) 0)))
(defun math-font-char-depth  (font char-code)
  (let ((m (gethash char-code (math-font-chars font)))) (if m (third m) 0)))
(defun math-font-char-italic (font char-code)
  (let ((m (gethash char-code (math-font-chars font)))) (if m (fourth m) 0)))
(defun math-font-char-exists-p (font char-code)
  (not (null (gethash char-code (math-font-chars font)))))

(defun math-font-char-extensible-p     (font char-code)
  (not (null (gethash char-code (math-font-extensible-parts font)))))
(defun math-font-char-extensible-parts (font char-code)
  (gethash char-code (math-font-extensible-parts font)))
(defun math-font-char-larger-variant  (font char-code)
  (gethash char-code (math-font-larger-variants font)))
(defun math-font-char-smaller-variant (font char-code)
  (gethash char-code (math-font-smaller-variants font)))
(defun math-font-skew-char (font char-code)
  (gethash char-code (math-font-skew-chars font)))
(defun math-font-get-next-larger (font char-code)
  (math-font-char-larger-variant font char-code))

;;; Character / variant setters

(defun math-font-set-char (font char-code width height depth &optional (italic 0))
  (setf (gethash char-code (math-font-chars font)) (list width height depth italic)))
(defun math-font-set-larger-variant (font char-code larger)
  (setf (gethash char-code (math-font-larger-variants font)) larger))
(defun math-font-set-smaller-variant (font char-code smaller)
  (setf (gethash char-code (math-font-smaller-variants font)) smaller))
(defun math-font-set-extensible-parts (font char-code top mid bot rep)
  (setf (gethash char-code (math-font-extensible-parts font)) (list top mid bot rep)))
(defun math-font-set-skew-char (font char-code skew)
  (setf (gethash char-code (math-font-skew-chars font)) skew))

;;; Default parameters (approximate cmr10/cmmi10/cmsy10/cmex10 fontdimen values).
;;; All math params are set on every font; copy-math-pars merges family 3
;;; ext params into family 2 (the math main font) at make-default-fonts time.
;;; Values in sp (1pt = 65536 sp).

(defun math-font-set-default-params (font)
  "真实 Computer Modern fontdimen（tftopl + tex.web store_scaled L11126 精确
换算，sp）。mathsy 参数来自 cmsy10.tfm、mathex 参数来自 cmex10.tfm；与
plain TeX \showbox 输出逐一核对（sub2=2.47217pt、sup1=4.12892pt、
sub1=1.49998pt、θ=0.39998pt 等）。"
  ;; family-2 (cmmi/cmsy) mathsy 参数 —— cmsy10.tfm
  (setf (math-font-param font +param-x-height+)      282168   ; 4.30554pt
        (math-font-param font +param-quad+)          655361   ; 10.00003pt
        (math-font-param font +param-num1+)         443356   ; 6.76508pt
        (math-font-param font +param-num2+)         258036   ; 3.93732pt
        (math-font-param font +param-num3+)         290803   ; 4.43731pt
        (math-font-param font +param-denom1+)       449545   ; 6.85951pt
        (math-font-param font +param-denom2+)       225995   ; 3.44841pt
        (math-font-param font +param-sup1+)        270593   ; 4.12892pt
        (math-font-param font +param-sup2+)        237825   ; 3.62892pt
        (math-font-param font +param-sup3+)        189326   ; 2.88889pt
        (math-font-param font +param-sub1+)         98303   ; 1.49998pt
        (math-font-param font +param-sub2+)        162016   ; 2.47217pt
        (math-font-param font +param-sup-drop+)    253040   ; 3.86108pt
        (math-font-param font +param-sub-drop+)     32768   ; 0.5pt
        (math-font-param font +param-delim1+)     1566310   ; 23.9pt
        (math-font-param font +param-delim2+)      661913   ; 10.1pt
        (math-font-param font +param-axis-height+) 163840)  ; 2.5pt
  ;; family-3 (cmex) mathex 参数 —— cmex10.tfm（经 copy-math-pars 合入 family 2）
  (setf (math-font-param font +param-default-rule-thickness+) 26213  ; 0.39998pt
        (math-font-param font +param-big-op-spacing1+)       72818  ; 1.11112pt
        (math-font-param font +param-big-op-spacing2+)      109226  ; 1.66667pt
        (math-font-param font +param-big-op-spacing3+)      131071  ; 2pt
        (math-font-param font +param-big-op-spacing4+)      393216  ; 6pt
        (math-font-param font +param-big-op-spacing5+)       65536)) ; 1pt

;;;; Scaling
;;;
;;; ⑧A：math-font-scale 已删除——script/scriptscript 尺寸改用真实 CM 字体
;;; （cmr7/cmmi7/cmsy7/cmr5/...，见 math-font-for），不再对 10pt 度量做
;;; 0.7/0.5 缩放。
