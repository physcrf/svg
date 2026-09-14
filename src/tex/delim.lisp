;;;; delim.lisp — TeX's variable-size delimiters
;;;;
;;;; Literal port of tex.web §var_delimiter (L13905) together with its local
;;;; subroutines char_box (L13980), stack_into_box (L14032) and
;;;; height_plus_depth (L14015). A delimiter field is the four-quarterword
;;;; (small_fam, small_char, large_fam, large_char) record of tex.web §706.

(in-package :svg-tex)

;;; ---------------------------------------------------------------------------
;;; char_info helpers (tex.web: char_tag / rem_byte / height / depth)
;;; ---------------------------------------------------------------------------
;;; Our TFM stand-in exposes a "next larger variant" list chain and an
;;; extensible recipe, which correspond to char_tag=list_tag / ext_tag.

(defun font-char-tag (font code)
  "Return :ext for an extensible char, :list for a char with a next-larger
variant, else nil (tex.web char_tag)."
  (cond ((math-font-char-extensible-p font code) :ext)
        ((math-font-char-larger-variant font code) :list)
        (t nil)))

(defun font-rem-byte (font code)
  "The next-larger character code stored with a list-tag char."
  (math-font-char-larger-variant font code))

(defun height-plus-depth (font code)
  (+ (char-height-of font code) (char-depth-of font code)))

;;; ---------------------------------------------------------------------------
;;; Extensible character construction (tex.web L14023)
;;; ---------------------------------------------------------------------------

(defun stack-into-box (b font code)
  "tex.web stack_into_box: put char BOX (FONT, CODE) on top of box B."
  (let ((p (char-box font code)))
    (setf (n-link p) (n-list b)
          (n-list b) p
          (n-height b) (n-height p))))

(defun make-extensible-delimiter (font code v)
  "tex.web <Construct an extensible character...>: build the recipe's pieces
into a vlist box at least V tall. Recipe is (top mid bot rep)."
  (destructuring-bind (top mid bot rep)
      (math-font-char-extensible-parts font code)
    (let* ((b (new-vlist))
           (u (height-plus-depth font rep))
           (w 0)
           (n 0))
      (setf (n-width b) (+ (char-width-of font rep) (char-italic-of font rep)))
      (when (/= bot 0) (incf w (height-plus-depth font bot)))
      (when (/= mid 0) (incf w (height-plus-depth font mid)))
      (when (/= top 0) (incf w (height-plus-depth font top)))
      (when (plusp u)
        (loop while (< w v) do
          (incf w u) (incf n)
          (when (/= mid 0) (incf w u))))
      (when (/= bot 0) (stack-into-box b font bot))
      (dotimes (i n) (stack-into-box b font rep))
      (when (/= mid 0)
        (stack-into-box b font mid)
        (dotimes (i n) (stack-into-box b font rep)))
      (when (/= top 0) (stack-into-box b font top))
      (setf (n-depth b) (- w (n-height b)))
      b)))

;;; ---------------------------------------------------------------------------
;;; var_delimiter (tex.web L13905)
;;; ---------------------------------------------------------------------------

(defun look-for-math-char-variant (g x w v)
  "tex.web <Look at the list of characters starting with x in font g...>.
Walks the list-tag chain from X, keeping the best (font, char, h+d) so far.
Returns (values best-font best-char best-heightplusdepth large-enough-p)."
  (let ((y x) (f nil) (c 0) (large nil) (done nil))
    (when (char-exists-of g y)
      (loop while (and (not done) (char-exists-of g y)) do
        (let ((tag (font-char-tag g y)))
          (cond
            ((eq tag :ext)
             (setf f g c y large t done t))
            (t
             (let ((u (height-plus-depth g y)))
               (when (> u w)
                 (setf f g c y w u)
                 (when (>= u v) (setf large t done t))))
             (unless done
               (if (eq tag :list)
                   (setf y (font-rem-byte g y))
                   (setf done t))))))))
    (values f c w large)))

(defun var-delimiter (d s v fonts)
  "tex.web var_delimiter: the smallest variant of delimiter D at size code S
whose height+depth is at least V. Returns a box vertically centered on the
axis (its shift_amount is set)."
  (block found
    (let ((f nil) (c 0) (w 0))
      (labels ((deliver (b)
               (setf (n-shift b)
                     (- (tex-half (- (n-height b) (n-depth b)))
                        (math-font-style-param fonts +param-axis-height+ s)))
               (return-from found b))
             (build ()
               (deliver (if f
                            (if (eq (font-char-tag f c) :ext)
                                (make-extensible-delimiter f c v)
                                (char-box f c))
                            (make-null-delimiter-box))))
             (look (z x)
               ;; tex.web <Look at the variants of (z,x)>: same family at the
               ;; current size down to text size.
               (when (or (/= z 0) (/= x 0))
                 (loop for sc from s downto 0 do
                   (let ((g (math-font-for fonts z sc)))
                     (when g
                       (multiple-value-bind (ff cc ww largep)
                           (look-for-math-char-variant g x w v)
                         (when ff (setf f ff c cc w ww))
                         (when largep (build)))))))))
        (look (delim-small-family d) (delim-small-char d))
        (look (delim-large-family d) (delim-large-char d))
        (build)))))

;;; ---------------------------------------------------------------------------
;;; Delimiter constructors
;;; ---------------------------------------------------------------------------

(defun make-delimiter (small-family small-char large-family large-char)
  (let ((d (null-delimiter)))
    (setf (delim-small-family d) small-family (delim-small-char d) small-char
          (delim-large-family d) large-family (delim-large-char d) large-char)
    d))

(defun make-null-delimiter-box ()
  "tex.web <if f=null_font>: a null box of width \\nulldelimiterspace."
  (let ((b (new-hlist)))
    (setf (n-width b) +null-delimiter-space+)
    b))
