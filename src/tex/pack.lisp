;;;; pack.lisp — TeX's box packing: hpack, vpackage, rebox, char_box, overbar
;;;;
;;;; Literal ports of tex.web §649 (hpack), §668 (vpackage/vpack), §the rebox
;;;; subroutine (L14064), char_box (L13980), overbar (L13884) and
;;;; fraction_rule (L13874). Boxes carry a glue setting (glue_sign /
;;;; glue_order / glue_set) exactly as TeX does; the actual per-glue width is
;;;; recovered at output time by GLUE-WIDTH-IN-BOX, mirroring hlist_out.

(in-package :svg-tex)

;;; tex.web §133-§135: the running dimension sentinel (null_flag).
(defconstant +null-flag+ (- (ash 1 30)))
(defun is-running (x) (= x +null-flag+))

;;; tex.web §the dimension parameters: exactly / additional.
(defparameter +exactly+ 0)
(defparameter +additional+ 1)

;;; ---------------------------------------------------------------------------
;;; Character metrics (tex.web: char_width / char_height / char_depth / italic)
;;; ---------------------------------------------------------------------------

(defun char-width-of (font code) (math-font-char-width font code))
(defun char-height-of (font code) (math-font-char-height font code))
(defun char-depth-of (font code) (math-font-char-depth font code))
(defun char-italic-of (font code) (math-font-char-italic font code))
(defun char-exists-of (font code)
  (and font (math-font-char-exists-p font code)))

;;; ---------------------------------------------------------------------------
;;; hpack (tex.web L12912)
;;; ---------------------------------------------------------------------------

(defun hpack (p w m)
  "Package the horizontal list P into an hlist box. W is the target width;
M is :EXACTLY (0) to set the width to W or :ADDITIONAL (1) to add W to the
natural width. Returns the new box node. The natural-width call is
(hpack P 0 :ADDITIONAL)."
  (let ((r (new-hlist))
        (h 0) (d 0) (x 0) (s 0)
        (total-stretch (make-array 4 :initial-element 0))
        (total-shrink (make-array 4 :initial-element 0)))
    (setf (n-list r) p)
    (loop while p do
      (if (char-node-p p)
          (let ((f (n-font p)) (c (n-character p)))
            (incf x (char-width-of f c))
            (setf h (max h (char-height-of f c)))
            (setf d (max d (char-depth-of f c)))
            (setf p (n-link p)))
          (progn
            (case (n-type p)
              ((:hlist :vlist :rule)
               (incf x (n-width p))
               (setf s (if (eq (n-type p) :rule) 0 (n-shift p)))
               (setf h (max h (- (n-height p) s)))
               (setf d (max d (+ (n-depth p) s))))
              (:glue
               (let ((g (n-glue p)))
                 (incf x (glue-width g))
                 (incf (aref total-stretch (glue-stretch-order g))
                       (glue-stretch g))
                 (incf (aref total-shrink (glue-shrink-order g))
                       (glue-shrink g))))
              (:kern
               (incf x (n-width p))))
            (setf p (n-link p)))))
    (setf (n-height r) h (n-depth r) d)
    (let ((target (if (= m +additional+) (+ x w) w)))
      (setf (n-width r) target)
      (let ((excess (- target x)))
        (cond
          ((zerop excess)
           (setf (n-glue-sign r) +glue-normal+ (n-glue-order r) +normal+
                 (n-glue-set r) 0.0d0))
          ((plusp excess) (set-h-glue-stretch r excess total-stretch))
          (t (set-h-glue-shrink r excess total-shrink)))))
    r))

(defun determine-stretch-order (total-stretch)
  (cond ((plusp (aref total-stretch +filll+)) +filll+)
        ((plusp (aref total-stretch +fill+)) +fill+)
        ((plusp (aref total-stretch +fil+)) +fil+)
        (t +normal+)))

(defun determine-shrink-order (total-shrink)
  (cond ((plusp (aref total-shrink +filll+)) +filll+)
        ((plusp (aref total-shrink +fill+)) +fill+)
        ((plusp (aref total-shrink +fil+)) +fil+)
        (t +normal+)))

(defun unfloat (r)
  "tex.web: clamp a glue-set ratio to a finite value."
  (if (> r 10000000.0d0) 10000000.0d0 r))

(defun set-h-glue-stretch (r excess total-stretch)
  (let ((o (determine-stretch-order total-stretch)))
    (setf (n-glue-order r) o (n-glue-sign r) +stretching+)
    (if (plusp (aref total-stretch o))
        (setf (n-glue-set r) (unfloat (/ (coerce excess 'double-float)
                                         (coerce (aref total-stretch o)
                                                 'double-float))))
        (setf (n-glue-sign r) +glue-normal+ (n-glue-set r) 0.0d0))))

(defun set-h-glue-shrink (r excess total-shrink)
  (let ((o (determine-shrink-order total-shrink)))
    (setf (n-glue-order r) o (n-glue-sign r) +shrinking+)
    (if (plusp (aref total-shrink o))
        (setf (n-glue-set r) (unfloat (/ (coerce (- excess) 'double-float)
                                         (coerce (aref total-shrink o)
                                                 'double-float))))
        (setf (n-glue-sign r) +glue-normal+ (n-glue-set r) 0.0d0))
    (when (and (> (aref total-shrink o) (- excess))
               (= o +normal+)
               (n-list r))
      (setf (n-glue-set r) 1.0d0))))

;;; ---------------------------------------------------------------------------
;;; vpackage / vpack (tex.web L13161)
;;; ---------------------------------------------------------------------------

(defparameter +max-dimen+ (- (ash 1 30) 1))

(defun vpack (p h m)
  (vpackage p h m +max-dimen+))

(defun vpackage (p h m l)
  "Package vertical list P. H/M as in hpack; L caps the depth (max_dimen in
the vpack special case)."
  (let ((r (new-vlist))
        (w 0) (d 0) (x 0) (s 0)
        (total-stretch (make-array 4 :initial-element 0))
        (total-shrink (make-array 4 :initial-element 0)))
    (setf (n-list r) p)
    (loop while p do
      (case (n-type p)
        ((:hlist :vlist :rule)
         (incf x (+ d (n-height p)))
         (setf d (n-depth p))
         (setf s (if (eq (n-type p) :rule) 0 (n-shift p)))
         (setf w (max w (+ (n-width p) s))))
        (:glue
         (let ((g (n-glue p)))
           (incf x d) (setf d 0)
           (incf x (glue-width g))
           (incf (aref total-stretch (glue-stretch-order g)) (glue-stretch g))
           (incf (aref total-shrink (glue-shrink-order g)) (glue-shrink g))))
        (:kern
         (incf x (+ d (n-width p)))
         (setf d 0)))
      (setf p (n-link p)))
    (setf (n-width r) w)
    (if (> d l)
        (progn (incf x (- d l)) (setf (n-depth r) l))
        (setf (n-depth r) d))
    (let ((target (if (= m +additional+) (+ x h) h)))
      (setf (n-height r) target)
      (let ((excess (- target x)))
        (cond
          ((zerop excess)
           (setf (n-glue-sign r) +glue-normal+ (n-glue-order r) +normal+
                 (n-glue-set r) 0.0d0))
          ((plusp excess) (set-h-glue-stretch r excess total-stretch))
          (t (set-h-glue-shrink r excess total-shrink)))))
    r))

;;; ---------------------------------------------------------------------------
;;; rebox (tex.web L14064)
;;; ---------------------------------------------------------------------------

(defparameter +ss-glue+
  (make-glue-spec 0 65536 65536 +fil+ +fil+)
  "tex.web ss_glue: 0pt plus 1fil minus 1fil.")

(defun rebox (b w)
  "Change box B so that it is centered in a box of width W (tex.web rebox).
The centering uses \\hss (ss_glue) on both sides and packs with :exactly."
  (if (and (/= (n-width b) w) (n-list b))
      (let* ((b (if (eq (n-type b) :vlist) (hpack b 0 +additional+) b))
             (p (n-list b))
             (f nil) (v 0))
        ;; Compensate for a single character's italic correction having been
        ;; added to the box width (tex.web <Simplify a trivial box>).
        (when (and (char-node-p p) (null (n-link p)))
          (setf f (n-font p)
                v (char-width-of f (n-character p)))
          (when (/= v (n-width b))
            (setf (n-link p) (new-kern (- (n-width b) v)))))
        (let* ((leading (new-glue +ss-glue+))
               (trailing (new-glue +ss-glue+)))
          (setf (n-link leading) p)
          (setf (n-link (last-node p)) trailing)
          (hpack leading w +exactly+)))
      (progn (setf (n-width b) w) b)))

;;; ---------------------------------------------------------------------------
;;; char_box / overbar / fraction_rule (tex.web L13980, L13884, L13874)
;;; ---------------------------------------------------------------------------

(defun char-box (font code)
  "tex.web char_box: a single-character hlist whose width includes the
italic correction for the character."
  (let ((b (new-hlist)))
    (when (char-exists-of font code)
      (setf (n-width b) (+ (char-width-of font code) (char-italic-of font code))
            (n-height b) (char-height-of font code)
            (n-depth b) (char-depth-of font code)
            (n-list b) (new-char font code)))
    b))

(defun fraction-rule (thickness)
  "tex.web fraction_rule: a rule of height THICKNESS and running width."
  (let ((r (new-rule thickness 0)))
    (setf (n-width r) +null-flag+)
    r))

(defun overbar (b k thickness)
  "tex.web overbar (§L13884): box B with a kern K under a rule of thickness T
under additional space T, packed into a vlist."
  (let* ((p (new-kern k)))
    (setf (n-link p) b)
    (let* ((q (fraction-rule thickness)))
      (setf (n-link q) p)
      (let ((p2 (new-kern thickness)))
        (setf (n-link p2) q)
        (vpack p2 0 +additional+)))))

;;; ---------------------------------------------------------------------------
;;; Output-time glue width (tex.web hlist_out / vlist_out glue handling)
;;; ---------------------------------------------------------------------------

(defun glue-width-in-box (g box)
  "Actual width (hlist) / height (vlist) of glue spec G inside BOX, applying
BOX's glue setting exactly as DVI output does."
  (let ((w (glue-width g))
        (sign (n-glue-sign box))
        (order (n-glue-order box))
        (set (n-glue-set box)))
    (cond
      ((and (= sign +stretching+) (= (glue-stretch-order g) order))
       (+ w (round (* set (glue-stretch g)))))
      ((and (= sign +shrinking+) (= (glue-shrink-order g) order))
       (- w (round (* set (glue-shrink g)))))
      (t w))))

;;; ---------------------------------------------------------------------------
;;; free_node (no-op: Lisp is garbage-collected)
;;; ---------------------------------------------------------------------------

(defun free-node (node &optional size)
  (declare (ignore node size))
  nil)
