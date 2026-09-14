;;;; mlist.lisp — TeX's math typesetting: mlist_to_hlist and its helpers
;;;;
;;;; A literal port of tex.web §726 (mlist_to_hlist) and the math construction
;;;; procedures of §727-§736:
;;;;   clean_box (L14173)         fetch (L14196)
;;;;   make_over (L14434)         make_under (L14442)
;;;;   make_vcenter (L14455)      make_radical (L14476)
;;;;   make_math_accent (L14498)  make_fraction (L14583)
;;;;   make_op (L14679)           make_ord (L14759)
;;;;   make_scripts (L14884)      make_left_right (L15018)
;;;; plus the two-pass driver and the 8x8 inter-element spacing table.
;;;;
;;;; tex.web keeps cur_style / cur_size / cur_mu / cur_f / cur_c / cur_i in
;;;; globals; we mirror them with special variables so the recursion through
;;;; clean_box reads exactly like the original.

(in-package :svg-tex)

;;; ---------------------------------------------------------------------------
;;; tex.web globals (cur_style, cur_size, cur_mu, cur_f, cur_c, cur_i)
;;; ---------------------------------------------------------------------------

(defvar *fonts* nil "The math-font vector in effect (tex.web font vectors).")
(defvar *cur-style* text-style "tex.web cur_style.")
(defvar *cur-size* text-size "tex.web cur_size: 0=text, 1=script, 2=scriptscript.")
(defvar *cur-mu* 65536 "tex.web cur_mu: width of 1mu in sp at *cur-size*.")
(defvar *cur-f* nil "tex.web cur_f: font of the last fetch.")
(defvar *cur-c* 0 "tex.web cur_c: character code of the last fetch.")
(defvar *cur-i* nil "tex.web cur_i: true when the last fetch found the char.")

(defparameter +inf-penalty+ 10000)
(defparameter +bin-op-penalty+ 700 "plain TeX \\binoppenalty.")
(defparameter +rel-penalty+ 500 "plain TeX \\relpenalty.")

(defun cur-param (key)
  (math-font-style-param *fonts* key *cur-style*))
(defun cur-param-at (key size-code)
  (math-font-param-at-size *fonts* key size-code))
(defun cur-drt () (cur-param +param-default-rule-thickness+))
(defun cur-axis () (cur-param +param-axis-height+))
(defun cur-x-height () (cur-param +param-x-height+))

(defun set-up-cur-size ()
  "tex.web <Set up the values of cur_size and cur_mu, based on cur_style>."
  (setf *cur-size* (math-style-size-code *cur-style*))
  ;; tex.web: cur_mu := x_over_n(math_quad(cur_size),18); math_quad is
  ;; mathsy(6). Our parameter table keeps quad in family 0 (cmr fd6 = cmsy fd6).
  ;; x_over_n truncates toward zero, so 655361/18 gives 36408 (not 36409):
  ;; using round() made every mu of spacing 1sp too wide.
  (let ((quad (math-font-param-at-size *fonts* +param-quad+ *cur-size*)))
    (setf *cur-mu* (if (plusp quad) (floor quad 18) (floor 655361 18)))))

(defun hpack-natural (list) (hpack list 0 +additional+))
(defun vpack-natural (list) (vpack list 0 +additional+))

;;; ---------------------------------------------------------------------------
;;; fetch (tex.web L14196)
;;; ---------------------------------------------------------------------------

(defun fetch (a)
  "Unpack the math-char A: set *cur-f*/*cur-c*/*cur-i* (tex.web fetch)."
  (let* ((f (math-font-for *fonts* (mc-family a) *cur-size*))
         (c (mc-code a)))
    (setf *cur-f* f *cur-c* c
          *cur-i* (and f (char-exists-of f c) t))
    *cur-i*))

(defun font-space-nonzero (font)
  "tex.web space(f): the font's fontdimen 2. Our math fonts leave it at 0."
  (plusp (math-font-param font :space)))

;;; ---------------------------------------------------------------------------
;;; clean_box (tex.web L14173)
;;; ---------------------------------------------------------------------------

(defun simplify-trivial-box (x)
  "tex.web <Simplify a trivial box>: drop an unneeded italic-correction kern."
  (let ((q (n-list x)))
    (when (char-node-p q)
      (let ((r (n-link q)))
        (when (and r (null (n-link r)) (not (char-node-p r)) (eq (n-type r) :kern))
          (setf (n-link q) nil)))))
  x)

(defun finish-clean-box (q)
  (let ((x (cond ((or (null q) (char-node-p q)) (hpack-natural q))
                 ((and (null (n-link q))
                       (member (n-type q) '(:hlist :vlist))
                       (zerop (n-shift q)))
                  q)
                 (t (hpack-natural q)))))
    (simplify-trivial-box x)))

(defun clean-box (p s)
  "tex.web clean_box: put the math field P into a box using style S."
  (case (field-type p)
    (:empty (simplify-trivial-box (new-hlist)))
    ((:math-char :math-text-char)
     (let ((n (new-noad :ord)))
       (setf (n-nucleus n) p)
       (finish-clean-box (mlist-to-hlist n s *fonts*))))
    (:sub-box (finish-clean-box (field-value p)))
    (:sub-mlist
     (finish-clean-box (mlist-to-hlist (field-value p) s *fonts*)))
    (t (simplify-trivial-box (new-hlist)))))

;;; ---------------------------------------------------------------------------
;;; make_over / make_under / make_vcenter (tex.web L14434-14455)
;;; ---------------------------------------------------------------------------

(defun make-over (q)
  (setf (n-nucleus q)
        (make-sub-box-field
         (overbar (clean-box (n-nucleus q) (math-style-cramped *cur-style*))
                  (* 3 (cur-drt)) (cur-drt)))))

(defun make-under (q)
  (let* ((x (clean-box (n-nucleus q) *cur-style*))
         (p (new-kern (* 3 (cur-drt)))))
    (setf (n-link x) p)
    (setf (n-link p) (fraction-rule (cur-drt)))
    (let ((y (vpack-natural x)))
      (let ((delta (+ (n-height y) (n-depth y) (cur-drt))))
        (setf (n-height y) (n-height x)
              (n-depth y) (- delta (n-height x)))
        (setf (n-nucleus q) (make-sub-box-field y))))))

(defun make-vcenter (q)
  (let* ((v (field-value (n-nucleus q)))
         (delta (+ (n-height v) (n-depth v))))
    (setf (n-height v) (+ (cur-axis) (tex-half delta))
          (n-depth v) (- delta (n-height v)))))

;;; ---------------------------------------------------------------------------
;;; make_radical (tex.web L14476)
;;; ---------------------------------------------------------------------------

(defun radical-index-shift ()
  "How far the \\root index is tucked into the radical sign, in sp: 5/18 em,
the displacement a real LaTeX run shows (the index's origin sits .2778em to the
right of the radical box's left edge, and the sign follows it after the same
negative kern)."
  (round (* (cur-param +param-quad+) 5) 18))

(defun radical-index-box (index radicand)
  "The \\root index as a box ready to sit in the crook of the radical sign.

tex.web does not place the index in make_radical; it leaves it in the global
\\rootbox for the scanner to append. What that amounts to, and what a real
LaTeX run shows, is an index that rides *inside* the radical's box: raised to
3/5 of the radicand's height above its depth plus .135em, shifted right into
the crook, and invisible to the box's height and depth. The two constants are
fitted to real LaTeX output; they reproduce its index placement to a
sixtieth of a point over every radicand and radical-sign variant measured."
  (let* ((r (clean-box index script-script-style))
         (em (cur-param +param-quad+))
         (raise (+ (round (* 3 (- (n-height radicand) (n-depth radicand))) 5)
                   (round (* em 27) 200))))
    ;; a negative shift_amount moves the box up (tex.web's convention)
    (setf (n-shift r) (- raise)
          (n-height r) 0
          (n-depth r) 0)
    r))

(defun make-radical (q)
  "tex.web L14476. Our version also places the \\root index that tex.web keeps
in the global \\rootbox (see RADICAL-INDEX-BOX)."
  (let* ((x (clean-box (n-nucleus q) (math-style-cramped *cur-style*)))
         (drt (cur-drt))
         (x-height (cur-x-height))
         (clr (if (math-style-display-p *cur-style*)
                  (+ drt (floor (abs x-height) 4))
                  (+ drt (floor (abs drt) 4)))))
    (let* ((y (var-delimiter (n-left-delimiter q) *cur-size*
                             (+ (n-height x) (n-depth x) clr drt) *fonts*))
           (delta (- (n-depth y) (+ (n-height x) (n-depth x) clr))))
      (when (plusp delta) (incf clr (tex-half delta)))
      (setf (n-shift y) (- (+ (n-height x) clr)))
      (setf (n-link y) (overbar x clr (n-height y)))
      (let ((z (hpack-natural y)))
        (setf (n-nucleus q)
              (make-sub-box-field
               (if (field-empty-p (n-index q))
                   z
                   ;; The index's ink has to land .2778em inside the radical
                   ;; sign's crook, but tex.web's shift_amount only moves a box
                   ;; vertically, so the same displacement is a kern inside the
                   ;; index's box, and the sign is pulled back by twice that.
                   (let* ((s (radical-index-shift))
                          (lead (new-kern s))
                          (r (radical-index-box (n-index q) x))
                          (k (new-kern (- (* 2 s)))))
                     (setf (n-link lead) r
                           (n-link r) k
                           (n-link k) z)
                     (hpack-natural lead)))))))))

;;; ---------------------------------------------------------------------------
;;; make_math_accent (tex.web L14498)
;;; ---------------------------------------------------------------------------

(defun skew-kern (font code)
  "The kern from character CODE to the font's skew character (slot 127),
from the TFM lig/kern table, or 0 (tex.web skew_char)."
  (when font
    (let ((entry (assoc (math-font-design-size font) *skew-kerns*)))
      (when entry (cdr (assoc code (cdr entry)))))))

(defun accent-skew (q)
  "tex.web make_math_accent <Compute the amount of skew>: the amount by which
the accent is skewed to the right of the accentee."
  (if (field-math-char-p (n-nucleus q))
      (progn
        (fetch (field-value (n-nucleus q)))
        (or (skew-kern *cur-f* *cur-c*) 0))
      0))

(defun make-math-accent (q)
  (let ((a (n-accent-chr q)))
    (when (fetch a)
      (let* ((c *cur-c*) (f *cur-f*)
             (s (accent-skew q))          ; tex.web <Compute the amount of skew>
             (x (clean-box (n-nucleus q) (math-style-cramped *cur-style*)))
             (w (n-width x))
             (h (n-height x)))
        ;; <Switch to a larger accent if available and appropriate>
        (loop
          (let ((tag (font-char-tag f c)))
            (unless (eq tag :list) (return))
            (let ((y (font-rem-byte f c)))
              (unless (char-exists-of f y) (return))
              (when (> (char-width-of f y) w) (return))
              (setf c y))))
        (let* ((x-height (font-x-height f *fonts* *cur-size*))
               (delta (if (< h x-height) h x-height)))
          ;; <Swap the subscript and superscript into box x>
          (when (and (or (not (field-empty-p (n-supscr q)))
                         (not (field-empty-p (n-subscr q))))
                     (field-math-char-p (n-nucleus q)))
            (let ((n (new-noad :ord)))
              (setf (n-nucleus n) (n-nucleus q)
                    (n-supscr n) (n-supscr q)
                    (n-subscr n) (n-subscr q))
              (setf (n-supscr q) (make-empty-field)
                    (n-subscr q) (make-empty-field)
                    (n-nucleus q) (make-sub-mlist-field n))
              (setf x (clean-box (n-nucleus q) *cur-style*))
              (incf delta (- (n-height x) h))
              (setf h (n-height x))))
          (let* ((y (char-box f c)))
            (setf (n-shift y) (+ s (tex-half (- w (n-width y)))))
            (setf (n-width y) 0)
            (let ((p (new-kern (- delta))))
              (setf (n-link p) x)
              (setf (n-link y) p))
            (let ((y (vpack-natural y)))
              (setf (n-width y) (n-width x))
              (when (< (n-height y) h)
                (let ((p (new-kern (- h (n-height y)))))
                  (setf (n-link p) (n-list y))
                  (setf (n-list y) p))
                (setf (n-height y) h))
              (setf (n-nucleus q) (make-sub-box-field y)))))))))

;;; ---------------------------------------------------------------------------
;;; make_fraction (tex.web L14583)
;;; ---------------------------------------------------------------------------

(defun make-fraction (q)
  (let* ((thickness (or (n-thickness q) (cur-drt)))
         (x (clean-box (n-numerator q) (math-style-num-style *cur-style*)))
         (z (clean-box (n-denominator q) (math-style-denom-style *cur-style*)))
         (shift-up 0) (shift-down 0) (clr 0) (delta 0))
    (if (< (n-width x) (n-width z))
        (setf x (rebox x (n-width z)))
        (setf z (rebox z (n-width x))))
    (if (math-style-display-p *cur-style*)
        (setf shift-up (cur-param +param-num1+)
              shift-down (cur-param +param-denom1+))
        (progn
          (setf shift-down (cur-param +param-denom2+))
          (setf shift-up (if (/= thickness 0)
                             (cur-param +param-num2+)
                             (cur-param +param-num3+)))))
    (if (= thickness 0)
        (progn
          (setf clr (* (if (math-style-display-p *cur-style*) 7 3) (cur-drt)))
          (setf delta (tex-half (- clr (- (- shift-up (n-depth x))
                                          (- (n-height z) shift-down)))))
          (when (plusp delta)
            (incf shift-up delta)
            (incf shift-down delta)))
        (progn
          (setf clr (* (if (math-style-display-p *cur-style*) 3 1) thickness))
          (setf delta (tex-half thickness))
          (let ((delta1 (- clr (- (- shift-up (n-depth x))
                                  (+ (cur-axis) delta))))
                (delta2 (- clr (- (- (cur-axis) delta)
                                  (- (n-height z) shift-down)))))
            (when (plusp delta1) (incf shift-up delta1))
            (when (plusp delta2) (incf shift-down delta2)))))
    (let ((v (new-vlist)))
      (setf (n-height v) (+ shift-up (n-height x))
            (n-depth v) (+ (n-depth z) shift-down)
            (n-width v) (n-width x))
      (if (= thickness 0)
          (let ((p (new-kern (- (- shift-up (n-depth x))
                                (- (n-height z) shift-down)))))
            (setf (n-link p) z)
            (setf (n-link x) p))
          (let* ((y (fraction-rule thickness))
                 (p2 (new-kern (- (- (cur-axis) delta)
                                  (- (n-height z) shift-down)))))
            (setf (n-link y) p2)
            (setf (n-link p2) z)
            (let ((p1 (new-kern (- (- shift-up (n-depth x))
                                   (+ (cur-axis) delta)))))
              (setf (n-link p1) y)
              (setf (n-link x) p1))))
      (setf (n-list v) x)
      (let* ((delim-target (if (math-style-display-p *cur-style*)
                               (cur-param +param-delim1+)
                               (cur-param +param-delim2+)))
             (left (var-delimiter (n-left-delimiter q) *cur-size*
                                  delim-target *fonts*))
             (right (var-delimiter (n-right-delimiter q) *cur-size*
                                   delim-target *fonts*)))
        (setf (n-link left) v)
        (setf (n-link v) right)
        (setf (n-new-hlist q) (hpack-natural left))))))

;;; ---------------------------------------------------------------------------
;;; make_op (tex.web L14679)
;;; ---------------------------------------------------------------------------

(defun make-op (q)
  (let ((delta 0))
    (when (and (not (eq (n-subtype q) :nolimits))
               (not (eq (n-subtype q) :limits))
               (math-style-display-p *cur-style*))
      (setf (n-subtype q) :limits))
    (if (field-math-char-p (n-nucleus q))
        (progn
          (fetch (field-value (n-nucleus q)))
          (when (and (math-style-display-p *cur-style*)
                     (eq (font-char-tag *cur-f* *cur-c*) :list))
            (let ((c (font-rem-byte *cur-f* *cur-c*)))
              (when (char-exists-of *cur-f* c)
                (setf *cur-c* c
                      (mc-code (field-value (n-nucleus q))) c))))
          (setf delta (char-italic-of *cur-f* *cur-c*))
          (let ((x (clean-box (n-nucleus q) *cur-style*)))
            (when (and (not (field-empty-p (n-subscr q)))
                       (not (eq (n-subtype q) :limits)))
              (decf (n-width x) delta))
            (setf (n-shift x)
                  (- (tex-half (- (n-height x) (n-depth x))) (cur-axis)))
            (setf (n-nucleus q) (make-sub-box-field x))))
        (setf delta 0))
    (when (eq (n-subtype q) :limits)
      (make-op-with-limits q delta))
    delta))

(defun make-op-with-limits (q delta)
  "tex.web <Construct a box with limits above and below it, skewed by delta>."
  (let* ((x (clean-box (n-supscr q) (math-style-sup-style *cur-style*)))
         (y (clean-box (n-nucleus q) *cur-style*))
         (z (clean-box (n-subscr q) (math-style-sub-style *cur-style*)))
         (v (new-vlist)))
    (setf (n-width v) (n-width y))
    (when (> (n-width x) (n-width v)) (setf (n-width v) (n-width x)))
    (when (> (n-width z) (n-width v)) (setf (n-width v) (n-width z)))
    (setf x (rebox x (n-width v))
          y (rebox y (n-width v))
          z (rebox z (n-width v)))
    (setf (n-shift x) (tex-half delta)
          (n-shift z) (- (n-shift x)))
    (setf (n-height v) (n-height y)
          (n-depth v) (n-depth y))
    ;; <Attach the limits to y and adjust height/depth>
    (if (field-empty-p (n-supscr q))
        (setf (n-list v) y)
        (let ((shift-up (max (- (cur-param +param-big-op-spacing3+) (n-depth x))
                             (cur-param +param-big-op-spacing1+))))
          (let ((p (new-kern shift-up)))
            (setf (n-link p) y)
            (setf (n-link x) p))
          (let ((p (new-kern (cur-param +param-big-op-spacing5+))))
            (setf (n-link p) x)
            (setf (n-list v) p))
          (incf (n-height v)
                (+ (cur-param +param-big-op-spacing5+)
                   (n-height x) (n-depth x) shift-up))))
    (if (field-empty-p (n-subscr q))
        nil
        (let ((shift-down (max (- (cur-param +param-big-op-spacing4+)
                                  (n-height z))
                               (cur-param +param-big-op-spacing2+))))
          (let ((p (new-kern shift-down)))
            (setf (n-link y) p)
            (setf (n-link p) z))
          (let ((p (new-kern (cur-param +param-big-op-spacing5+))))
            (setf (n-link z) p))
          (incf (n-depth v)
                (+ (cur-param +param-big-op-spacing5+)
                   (n-height z) (n-depth z) shift-down))))
    (setf (n-new-hlist q) v)))

;;; ---------------------------------------------------------------------------
;;; make_ord (tex.web L14759)
;;; ---------------------------------------------------------------------------

(defun make-ord (q)
  "tex.web make_ord. Our fonts carry no ligature/kern programs, so the only
observable effect is the math_char→math_text_char reclassification (which
suppresses the italic correction for text-font mid-word chars; harmless here
because the math fonts have space=0)."
  (when (and (field-empty-p (n-subscr q))
             (field-empty-p (n-supscr q))
             (field-math-char-p (n-nucleus q)))
    (let ((p (n-link q)))
      (when (and p (member (n-type p) '(:ord :op :bin :rel :open :close :punct))
                 (field-math-char-p (n-nucleus p))
                 (= (mc-family (field-value (n-nucleus p)))
                    (mc-family (field-value (n-nucleus q)))))
        (setf (n-nucleus q)
              (make-math-text-char-field (field-value (n-nucleus q))))))))

;;; ---------------------------------------------------------------------------
;;; make_scripts (tex.web L14884)
;;; ---------------------------------------------------------------------------

(defun make-scripts (q delta)
  (let ((p (n-new-hlist q))
        (shift-up 0) (shift-down 0))
    (if (char-node-p p)
        (setf shift-up 0 shift-down 0)
        (let* ((z (hpack-natural p))
               (t-size (if (< *cur-style* script-style) script-size
                           script-script-size)))
          (setf shift-up (- (n-height z) (cur-param-at +param-sup-drop+ t-size))
                shift-down (+ (n-depth z) (cur-param-at +param-sub-drop+ t-size)))))
    (let ((x nil))
      (if (field-empty-p (n-supscr q))
          ;; <Construct a subscript box x when there is no superscript>
          (progn
            (setf x (clean-box (n-subscr q)
                               (math-style-sub-style *cur-style*)))
            (incf (n-width x) +script-space+)
            (setf shift-down (max shift-down (cur-param +param-sub1+)))
            (setf shift-down
                  (max shift-down
                       (- (n-height x)
                          (floor (abs (* (cur-x-height) 4)) 5))))
            (setf (n-shift x) shift-down))
          (progn
            ;; <Construct a superscript box x>
            (setf x (clean-box (n-supscr q)
                               (math-style-sup-style *cur-style*)))
            (incf (n-width x) +script-space+)
            (let ((clr (cond ((math-style-cramped-p *cur-style*)
                              (cur-param +param-sup3+))
                             ((math-style-display-p *cur-style*)
                              (cur-param +param-sup1+))
                             (t (cur-param +param-sup2+)))))
              (setf shift-up (max shift-up clr))
              (setf clr (+ (n-depth x)
                           (floor (abs (cur-x-height)) 4)))
              (setf shift-up (max shift-up clr)))
            (if (field-empty-p (n-subscr q))
                (setf (n-shift x) (- shift-up))
                ;; <Construct a sub/superscript combination box x>
                (let* ((y (clean-box (n-subscr q)
                                     (math-style-sub-style *cur-style*))))
                  (incf (n-width y) +script-space+)
                  (setf shift-down (max shift-down (cur-param +param-sub2+)))
                  (let ((clr (- (* 4 (cur-drt))
                                (- (- shift-up (n-depth x))
                                   (- (n-height y) shift-down)))))
                    (when (plusp clr)
                      (incf shift-down clr)
                      (setf clr (- (floor (abs (* (cur-x-height) 4)) 5)
                                   (- shift-up (n-depth x))))
                      (when (plusp clr)
                        (incf shift-up clr)
                        (decf shift-down clr))))
                  (setf (n-shift x) delta)
                  (let ((p (new-kern (- (- shift-up (n-depth x))
                                        (- (n-height y) shift-down)))))
                    (setf (n-link x) p)
                    (setf (n-link p) y))
                  (setf x (vpack-natural x))
                  (setf (n-shift x) shift-down)))))
      (cond ((null (n-new-hlist q)) (setf (n-new-hlist q) x))
            (t (setf (n-link (last-node (n-new-hlist q))) x))))))

;;; ---------------------------------------------------------------------------
;;; make_left_right (tex.web L15018)
;;; ---------------------------------------------------------------------------

(defun make-matrix (q)
  "Engine extension (not tex.web): lay out row/cell mlists the way LaTeX's
matrix does. Each row of N-LIST Q is a list of cell mlists. Cells are typeset
at the current style and reboxed to their column width, which keeps them
centered in the column (amsmath's `\\hfil$\\displaystyle#$\\hfil'); columns are
separated by one quad, matching LaTeX's \\arraycolsep of 5pt on each side.

Every row carries a strut (LaTeX's \\strut is 8.5pt high and 3.5pt deep at
10pt), so a plain matrix gets its \\baselineskip row pitch, and consecutive
rows are separated by whatever \\baselineskip still needs. The grid is then
centered on the math axis -- the \\vcenter LaTeX wraps every matrix in -- so
the box sits astride the baseline instead of floating above it."
  (let* ((rows (n-list q))
         (em (cur-param +param-quad+))
         ;; Array cells are typeset in \textstyle: a real LaTeX run gives the
         ;; same box for \frac inside a matrix as for \textstyle\frac, and a
         ;; smaller one than for \displaystyle\frac. TeX's \textstyle leaves
         ;; script sizes alone, hence the MIN.
         (cell-style (if (< *cur-style* text-style) text-style *cur-style*))
         (cell-boxes
           (mapcar (lambda (row)
                     (mapcar (lambda (cell)
                               (hpack-natural
                                (mlist-to-hlist cell cell-style *fonts*)))
                             row))
                   rows))
         (ncols (reduce #'max cell-boxes :key #'length :initial-value 0))
         (col-widths
           (loop for c below ncols
                 collect (loop for row in cell-boxes
                               maximize (if (nth c row) (n-width (nth c row)) 0))))
         (col-gap em)
         (baselineskip (round (* 6 em) 5))       ; 1.2em, as in the 10pt class
         (strut-height (round (* 17 em) 20))     ; 8.5pt at 10pt
         (strut-depth (round (* 7 em) 20))       ; 3.5pt at 10pt
         (row-boxes
           (loop for row in cell-boxes
                 collect
                 (let ((cells nil))
                   ;; the strut is a zero-width rule: invisible, but it sets
                   ;; the row's minimum height and depth
                   (push (new-rule strut-height strut-depth) cells)
                   (loop for c below ncols
                         for cell = (nth c row)
                         do (let ((b (if cell cell (new-hlist))))
                              (setf b (rebox b (nth c col-widths)))
                              (when (> c 0) (push (new-kern col-gap) cells))
                              (push b cells)))
                   (hpack-natural (apply #'nl (nreverse cells)))))))
    (let ((list nil))
      (loop for row in row-boxes
            for prev = nil then row
            do (when prev
                 ;; \baselineskip between row baselines (TeX's interline
                 ;; glue), never negative
                 (push (new-kern (max 0 (- baselineskip
                                           (+ (n-depth prev) (n-height row)))))
                       list))
               (push row list))
      (let ((v (vpack-natural (apply #'nl (nreverse list)))))
        ;; make_vcenter (tex.web L14455): centre on the math axis
        (let ((delta (+ (n-height v) (n-depth v))))
          (setf (n-height v) (+ (cur-axis) (tex-half delta))
                (n-depth v) (- delta (n-height v))))
        (setf (n-new-hlist q) v)))))

(defun make-left-right (q style max-d max-h)
  "Construct a \\left/\\right delimiter of the required size; return the
spacing type (4 for \\left, 5 for \\right)."
  (let* ((cur-size (if (< style script-style) 0
                       (* 2 (floor (- style text-style) 2))))
         (delta2 (+ max-d (math-font-param-at-size *fonts*
                                                   +param-axis-height+
                                                   cur-size)))
         (delta1 (- (+ max-h max-d) delta2)))
    (when (> delta2 delta1) (setf delta1 delta2))
    (let ((delta (* (floor delta1 500) +delimiter-factor+)))
      (setf delta2 (- (+ delta1 delta1) +delimiter-shortfall+))
      (when (< delta delta2) (setf delta delta2))
      (setf (n-new-hlist q)
            (var-delimiter (if (eq (n-type q) :left)
                               (n-left-delimiter q)
                               (n-right-delimiter q))
                           cur-size delta *fonts*))
      (if (eq (n-type q) :left) 4 5))))

;;; ---------------------------------------------------------------------------
;;; mlist_to_hlist (tex.web L14279)
;;; ---------------------------------------------------------------------------

(defun mlist-to-hlist (mlist style fonts &optional (penalties nil))
  "tex.web mlist_to_hlist: convert MLIST to an hlist node list. STYLE is the
initial math style; FONTS is the math-font vector. Returns the hlist head."
  ;; Bind *cur-size* / *cur-mu* too: set-up-cur-size mutates them, and TeX
  ;; restores cur_style/cur_size after every recursive mlist_to_hlist
  ;; (tex.web clean_box L14190, sub_mlist L14851). Without the binding a
  ;; nested (script-size) call would leak its size into the caller.
  (let ((*fonts* fonts) (*cur-style* style)
        (*cur-size* text-size) (*cur-mu* 65536))
    (set-up-cur-size)
    (let ((result (mlist-to-hlist-body mlist penalties)))
      result)))

(defun mlist-to-hlist-body (mlist penalties)
  (let ((q mlist) (r nil) (r-type :op) (max-h 0) (max-d 0)
        (initial-style *cur-style*))
    ;; ---------------------------------------------------------------- pass 1
    (loop while q do
      (let ((delta 0))
        (tagbody
         reswitch
          (case (n-type q)
            (:bin
             (when (member r-type '(:bin :op :rel :open :punct :left))
               (setf (n-type q) :ord)
               (go reswitch)))
            ((:rel :close :punct :right)
             (when (eq r-type :bin) (setf (n-type r) :ord))
             (when (eq (n-type q) :right) (go done-with-noad)))
            (:left (go done-with-noad))
            (:fraction (make-fraction q) (go check-dimensions))
            (:op
             (setf delta (make-op q))
             (when (eq (n-subtype q) :limits) (go check-dimensions)))
            (:ord (make-ord q))
            ((:open :inner) nil)
            (:radical (make-radical q))
            (:over (make-over q))
            (:under (make-under q))
            (:accent (make-math-accent q))
            (:vcenter (make-vcenter q))
            (:matrix (make-matrix q) (go check-dimensions))
            (:style
             (setf *cur-style* (n-subtype q))
             (set-up-cur-size)
             (go done-with-node))
            (:rule
             (when (> (n-height q) max-h) (setf max-h (n-height q)))
             (when (> (n-depth q) max-d) (setf max-d (n-depth q)))
             (go done-with-node))
            ((:penalty :glue :kern :insert :mark :adjust :whatsit :disc)
             (go done-with-node))
            (t (error "mlist_to_hlist: unexpected node type ~S" (n-type q))))
          ;; <Convert nucleus(q) to an hlist and attach the sub/superscripts>
          (case (field-type (n-nucleus q))
            ((:math-char :math-text-char)
             (fetch (field-value (n-nucleus q)))
             (if *cur-i*
                 (let ((p (new-char *cur-f* *cur-c*)))
                   (setf delta (char-italic-of *cur-f* *cur-c*))
                   (when (and (eq (field-type (n-nucleus q)) :math-text-char)
                              (font-space-nonzero *cur-f*))
                     (setf delta 0))
                   (when (and (field-empty-p (n-subscr q)) (/= delta 0))
                     (setf (n-link p) (new-kern delta))
                     (setf delta 0))
                   (setf (n-new-hlist q) p))
                 (setf (n-new-hlist q) nil)))
            (:empty (setf (n-new-hlist q) nil))
            (:sub-box (setf (n-new-hlist q) (field-value (n-nucleus q))))
            (:sub-mlist
             (setf (n-new-hlist q)
                   (hpack-natural (mlist-to-hlist (field-value (n-nucleus q))
                                                  *cur-style* *fonts*)))))
          (when (and (field-empty-p (n-subscr q))
                     (field-empty-p (n-supscr q)))
            (go check-dimensions))
          (make-scripts q delta)
         check-dimensions
          (let ((z (hpack-natural (n-new-hlist q))))
            (when (> (n-height z) max-h) (setf max-h (n-height z)))
            (when (> (n-depth z) max-d) (setf max-d (n-depth z))))
         done-with-noad
          (setf r q r-type (n-type r))
          (go done-with-node)
         done-with-node
          (setf q (n-link q)))))
    ;; <Convert a final bin_noad to an ord_noad>
    (when (eq r-type :bin) (setf (n-type r) :ord))
    ;; ---------------------------------------------------------------- pass 2
    (mlist-second-pass mlist penalties max-h max-d initial-style)))

;;; ---------------------------------------------------------------------------
;;; Second pass: remove noads, insert spacing/penalties, build left/right
;;; ---------------------------------------------------------------------------

(defun append-output (tail node)
  "Link NODE after sentinel TAIL; return the new tail. NODE's own link is
cleared (tex.web: link(p):=q; p:=q; link(p):=null)."
  (setf (n-link tail) node)
  node)

(defun mlist-second-pass (mlist penalties max-h max-d initial-style)
  (let ((head (new-hlist))           ; tex.web temp_head
        (tail nil)
        (q mlist)
        (r-type -1)                  ; -1 = no preceding noad (tex.web r_type:=0)
        (style initial-style))
    (setf tail head)
    (let ((*cur-style* style) (*cur-size* text-size) (*cur-mu* 65536))
      (set-up-cur-size)
      (loop while q do
        (cond
          ((eq (n-type q) :style)
           (setf *cur-style* (n-subtype q))
           (set-up-cur-size)
           (setf q (n-link q)))
          ((not (noad-p q))
           (let ((next (n-link q)))
             (setf tail (append-output tail q))
             (setf (n-link tail) nil)
             (setf q next)))
          (t
           (let ((noad-class 0) (pen +inf-penalty+))
             (case (n-type q)
               ((:op :open :close :punct :inner) (setf noad-class (noad-type-index q)))
               (:bin (setf noad-class 2 pen +bin-op-penalty+))
               (:rel (setf noad-class 3 pen +rel-penalty+))
               ((:ord :vcenter :over :under :radical :fraction :accent :matrix) nil)
               ((:left :right)
                (setf noad-class (make-left-right q style max-d max-h)))
               (t (setf noad-class 0)))
             ;; <Append inter-element spacing based on r_type and t>
             (when (>= r-type 0)
               (let ((code (aref *math-spacing-codes* r-type noad-class)))
                 (multiple-value-bind (mu stretch shrink)
                     (spacing-code->glue-mu code *cur-style*)
                   (when (plusp mu)
                     (let ((g (make-glue-spec (* mu *cur-mu*)
                                              (* stretch *cur-mu*)
                                              (* shrink *cur-mu*))))
                       (setf tail (append-output tail (new-glue g))))))))
             ;; <Append any new_hlist entries for q, and penalties>
             (let ((nh (n-new-hlist q)))
               (when nh
                 (setf (n-link tail) nh)
                 (setf tail (last-node nh))
                 (setf (n-link tail) nil)))
             (when (and penalties (n-link q) (< pen +inf-penalty+))
               (let ((next-type (n-type (n-link q))))
                 (unless (or (eq next-type :penalty) (eq next-type :rel))
                   (setf tail (append-output tail (new-penalty pen))))))
             (setf r-type noad-class)
             (setf q (n-link q)))))))
    (n-link head)))

;;; ---------------------------------------------------------------------------
;;; Public entry points
;;; ---------------------------------------------------------------------------

(defun mlist-to-box (mlist style fonts &optional (penalties nil))
  "Convert MLIST to a single hlist box (hpack the mlist_to_hlist result)."
  (hpack-natural (mlist-to-hlist mlist style fonts penalties)))
