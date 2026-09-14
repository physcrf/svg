(in-package :svg-tex)

;;; Math styles are defparameter (not defconstant) so they can be reassigned
;;; at runtime (e.g. to retarget a style table) without recompiling. They hold
;;; the integers 0–7, satisfying the math-style type below. Code uses them as
;;; runtime values (default args, initforms, predicate comparisons) — never as
;;; non-evaluated case keys — so the constant→variable switch is safe.
(defparameter display-style 0)
(defparameter cramped-display-style 1)
(defparameter text-style 2)
(defparameter cramped-text-style 3)
(defparameter script-style 4)
(defparameter cramped-script-style 5)
(defparameter script-script-style 6)
(defparameter cramped-script-script-style 7)

;;; cur_size 语义（tex.web）：0=text 1=script 2=script-script。普通字号公式
;;; （display/text 及 cramped，style 0–3）用 text 尺寸；script 系（4–7）用
;;; script/script-script 尺寸。字体向量按 (family + 4×size-code) 槽位选真实
;;; CM 字体（cmr10/7/5 等），见 math-font-for。
(defparameter text-size 0)
(defparameter script-size 1)
(defparameter script-script-size 2)

(deftype math-style () '(integer 0 7))

(defun math-style-p (x) (typep x 'math-style))

(defun math-style-cramped-p (s)
  (oddp s))

(defun math-style-display-p (s)
  (< s 2))

(defun math-style-script-p (s)
  (<= 4 s 5))

(defun math-style-script-script-p (s)
  (<= 6 s 7))

(defun math-style-size-code (s)
  "tex.web L13865–13866：cur_style<script_style → text_size；否则
16×((cur_style−text_style) div 2)。CL 尺寸码压缩为 0/1/2。"
  (cond ((< s script-style) text-size)                    ; 0–3
        ((<= s cramped-script-style) script-size)         ; 4–5
        (t script-script-size)))                          ; 6–7

(defun math-style-cramped (s)
  (logior (logand s 6) 1))

(defun math-style-uncramped (s)
  (logand s 6))

(defun math-style-sub-style (s)
  "Subscripts are always cramped; otherwise advance one style level (display/
text → cramped-script, script/script-script → cramped-script-script), matching
TeX's sub_style. Idempotent at script-script."
  (logior (math-style-sup-style s) 1))

(defun math-style-sup-style (s)
  "Advance one style level: display/text (0–3) → script (4/5), script/
script-script (4–7) → script-script (6/7), preserving crampedness. Idempotent
at script-script."
  (+ (if (< s 4) script-style script-script-style)
     (logand s 1)))

(defun math-style-num-style (s)
  (+ s 2 (* -2 (floor s 6))))

(defun math-style-denom-style (s)
  (+ (* 2 (floor s 2)) 1 2 (* -2 (floor s 6))))

(defun math-style-name (s)
  (case s
    (0 "display")
    (1 "cramped display")
    (2 "text")
    (3 "cramped text")
    (4 "script")
    (5 "cramped script")
    (6 "scriptscript")
    (7 "cramped scriptscript")
    (t "unknown")))
