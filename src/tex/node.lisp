;;;; node.lisp — TeX's node model (the `mem` array of tex.web)
;;;;
;;;; Everything below follows tex.web's data structures directly:
;;;;   * a box is an hlist_node / vlist_node with width, height, depth,
;;;;     shift_amount, list_ptr and a glue setting (glue_sign/glue_order/
;;;;     glue_set) — see tex.web §133-§136 (`box_node`);
;;;;   * glue is a shared glue_spec record (width/stretch/shrink/orders)
;;;;     — tex.web §149-§152 (`glue_spec`);
;;;;   * a noad is a four-word record whose nucleus/supscr/subscr fields are
;;;;     two-word math fields — tex.web §681 (`noad`), §689 (`math_type`);
;;;;   * char/rule/kern/penalty/style nodes are the remaining node kinds.
;;;;
;;;; TeX addresses mem words by integer; we use a CLOS-free defstruct with a
;;;; slot per mem word. Lists are singly linked through NODE-LINK exactly as in
;;;; tex.web, so every procedure below can be a literal port (link(q), etc.).

(in-package :svg-tex)

;;; ---------------------------------------------------------------------------
;;; Infinity orders (tex.web: normal/fil/fill/filll)
;;; ---------------------------------------------------------------------------

(defconstant +normal+ 0)
(defconstant +fil+ 1)
(defconstant +fill+ 2)
(defconstant +filll+ 3)

;;; glue signs (tex.web: normal/stretching/shrinking)
(defconstant +glue-normal+ 0)
(defconstant +stretching+ 1)
(defconstant +shrinking+ 2)

;;; ---------------------------------------------------------------------------
;;; Glue specification (tex.web §149)
;;; ---------------------------------------------------------------------------

(defstruct (glue-spec (:conc-name glue-)
                      (:constructor make-glue-spec
                          (width stretch shrink
                           &optional (stretch-order +normal+)
                                     (shrink-order +normal+))))
  (width 0 :type integer)
  (stretch 0 :type integer)
  (shrink 0 :type integer)
  (stretch-order +normal+ :type (integer 0 3))
  (shrink-order +normal+ :type (integer 0 3)))

;;; ---------------------------------------------------------------------------
;;; Math fields (tex.web §681: math_type + info)
;;; ---------------------------------------------------------------------------
;;; A field's TYPE is one of:
;;;   :empty         — tex.web `empty` (math_type=empty)
;;;   :math-char     — tex.web `math_char`  (value is an MCHAR)
;;;   :sub-box       — tex.web `sub_box`    (value is a box NODE)
;;;   :sub-mlist     — tex.web `sub_mlist`  (value is a list of nodes)
;;;   :math-text-char— tex.web `math_text_char` (value is an MCHAR)

(defstruct (field (:conc-name field-)
                  (:constructor %make-field (type value)))
  (type :empty :type keyword)
  (value nil))

(defun make-empty-field () (%make-field :empty nil))
(defun make-math-char-field (mc) (%make-field :math-char mc))
(defun make-math-text-char-field (mc) (%make-field :math-text-char mc))
(defun make-sub-box-field (box) (%make-field :sub-box box))
(defun make-sub-mlist-field (mlist) (%make-field :sub-mlist mlist))

(defun field-empty-p (f) (eq (field-type f) :empty))

(defun field-math-char-p (f)
  (member (field-type f) '(:math-char :math-text-char)))

(defun field-math-char (f)
  "Return the MCHAR of a :math-char / :math-text-char field, else nil."
  (when (field-math-char-p f) (field-value f)))

(defun field-box (f)
  "Return the box of a :sub-box field, else nil."
  (when (eq (field-type f) :sub-box) (field-value f)))

(defun field-mlist (f)
  "Return the mlist of a :sub-mlist field, else nil."
  (when (eq (field-type f) :sub-mlist) (field-value f)))

;;; ---------------------------------------------------------------------------
;;; Math characters and delimiters
;;; ---------------------------------------------------------------------------

(defstruct (mchar (:conc-name mc-))
  (family 0 :type (integer 0 15))
  ;; TeX characters are 8-bit, but the mock fonts use full Unicode code points
  ;; for preview glyphs (∑/√/…), so the range is relaxed.
  (code 0 :type (integer 0 1114111)))

(defstruct (delimiter (:conc-name delim-)
                      (:constructor %make-delimiter ()))
  ;; tex.web §706: small_fam/small_char/large_fam/large_char quarterwords.
  ;; The null delimiter is (0, min_quarterword=0, 0, 0); a zero small char
  ;; with a zero family is treated as "no delimiter" by var-delimiter.
  (small-family 0 :type (integer 0 15))
  (small-char 0 :type (integer 0 1114111))
  (large-family 0 :type (integer 0 15))
  (large-char 0 :type (integer 0 1114111)))

(defun null-delimiter ()
  (%make-delimiter))

(defun null-delimiter-p (d)
  (and (zerop (delim-small-family d)) (zerop (delim-small-char d))
       (zerop (delim-large-family d)) (zerop (delim-large-char d))))

;;; ---------------------------------------------------------------------------
;;; The node record (tex.web: memory_word + link)
;;; ---------------------------------------------------------------------------
;;; TYPE is a keyword naming the node kind:
;;;   box nodes:   :hlist  :vlist
;;;   leaf nodes:  :rule  :glue  :kern  :char  :penalty  :style
;;;   noads:       :ord :op :bin :rel :open :close :punct :inner
;;;                :radical :fraction :under :over :accent :vcenter
;;;                :left :right

(defstruct (node (:conc-name n-)
                 (:constructor %make-node ()))
  ;; list linkage and identity (tex.web: link, type, subtype)
  (type nil :type (or null keyword))
  (subtype +normal+)
  (link nil)
  (info 0)
  ;; box / rule / kern geometry (tex.web: width/height/depth/shift_amount)
  (width 0 :type integer)
  (height 0 :type integer)
  (depth 0 :type integer)
  (shift 0 :type integer)
  (list nil)
  ;; glued boxes (tex.web: glue_ptr + glue_sign/order/set)
  (glue nil :type (or null glue-spec))
  (glue-sign +glue-normal+ :type (integer 0 2))
  (glue-order +normal+ :type (integer 0 3))
  (glue-set 0.0d0 :type double-float)
  ;; char node (tex.web: font, character)
  (font nil)
  (character 0 :type integer)
  ;; penalty node
  (penalty 0 :type integer)
  ;; noad fields (tex.web §689: nucleus, supscr, subscr)
  (nucleus nil :type (or null field))
  (supscr nil :type (or null field))
  (subscr nil :type (or null field))
  ;; tex.web new_hlist(#)==mem[nucleus(#)].int: the hlist a noad translates to
  (new-hlist nil)
  ;; fraction noad (tex.web: thickness, numerator, denominator, delimiters)
  (thickness nil)
  (numerator nil)
  (denominator nil)
  (left-delimiter nil :type (or null delimiter))
  (right-delimiter nil :type (or null delimiter))
  ;; radical noad shares LEFT-DELIMITER; accent noad uses ACCENT-CHR
  (accent-chr nil :type (or null mchar))
  ;; \root...\of index of a radical. tex.web keeps it out of the noad, in the
  ;; global \rootbox, and make_radical places it; we store it here so the
  ;; engine's make_radical can do the same (see RADICAL-INDEX-BOX).
  (index nil :type (or null field)))

;;; --- Node constructors (tex.web §138-§165, §681, §1080) --------------------

(defun new-hlist ()
  (let ((n (%make-node))) (setf (n-type n) :hlist) n))

(defun new-vlist ()
  (let ((n (%make-node))) (setf (n-type n) :vlist) n))

(defun new-rule (height depth)
  (let ((n (%make-node)))
    (setf (n-type n) :rule (n-height n) height (n-depth n) depth)
    n))

(defun new-glue (g)
  "tex.web new_glue (§149): a glue node pointing at glue spec G."
  (let ((n (%make-node))) (setf (n-type n) :glue (n-glue n) g) n))

(defun new-kern (w)
  (let ((n (%make-node))) (setf (n-type n) :kern (n-width n) w) n))

(defun new-char (font char-code)
  (let ((n (%make-node)))
    (setf (n-type n) :char (n-font n) font (n-character n) char-code)
    n))

(defun new-penalty (pen)
  (let ((n (%make-node))) (setf (n-type n) :penalty (n-penalty n) pen) n))

(defun new-style (style)
  (let ((n (%make-node))) (setf (n-type n) :style (n-subtype n) style) n))

(defun new-noad (&optional (type :ord))
  "tex.web new_noad (§698): a null ord noad with empty nucleus/supscr/subscr."
  (let ((n (%make-node)))
    (setf (n-type n) type
          (n-subtype n) +normal+
          (n-nucleus n) (make-empty-field)
          (n-supscr n) (make-empty-field)
          (n-subscr n) (make-empty-field)
          (n-index n) (make-empty-field))
    n))

;;; --- Named noad constructors (tex.web §689-§706) --------------------------

(defun ord-noad (nucleus
                 &optional (supscr (make-empty-field)) (subscr (make-empty-field)))
  (let ((n (new-noad :ord)))
    (setf (n-nucleus n) nucleus (n-supscr n) supscr (n-subscr n) subscr)
    n))

(defun op-noad (nucleus &key (supscr (make-empty-field)) (subscr (make-empty-field))
                              (subtype :normal))
  (let ((n (new-noad :op)))
    (setf (n-nucleus n) nucleus (n-supscr n) supscr (n-subscr n) subscr
          (n-subtype n) subtype)
    n))

(defun bin-noad (nucleus)
  (let ((n (new-noad :bin))) (setf (n-nucleus n) nucleus) n))
(defun rel-noad (nucleus)
  (let ((n (new-noad :rel))) (setf (n-nucleus n) nucleus) n))
(defun open-noad (nucleus)
  (let ((n (new-noad :open))) (setf (n-nucleus n) nucleus) n))
(defun close-noad (nucleus)
  (let ((n (new-noad :close))) (setf (n-nucleus n) nucleus) n))
(defun punct-noad (nucleus)
  (let ((n (new-noad :punct))) (setf (n-nucleus n) nucleus) n))
(defun inner-noad (nucleus
                   &optional (supscr (make-empty-field)) (subscr (make-empty-field)))
  (let ((n (new-noad :inner)))
    (setf (n-nucleus n) nucleus (n-supscr n) supscr (n-subscr n) subscr)
    n))

(defun make-fraction-noad (thickness numerator denominator
                           &optional left-delimiter right-delimiter)
  "tex.web fraction_noad. NUMERATOR/DENOMINATOR are :sub-mlist fields."
  (let ((n (new-noad :fraction)))
    (setf (n-thickness n) thickness
          (n-numerator n) numerator
          (n-denominator n) denominator
          (n-left-delimiter n) (or left-delimiter (null-delimiter))
          (n-right-delimiter n) (or right-delimiter (null-delimiter)))
    n))

(defun make-radical-noad (nucleus left-delimiter
                          &optional (supscr (make-empty-field))
                                    (subscr (make-empty-field)))
  (let ((n (new-noad :radical)))
    (setf (n-nucleus n) nucleus (n-left-delimiter n) left-delimiter
          (n-supscr n) supscr (n-subscr n) subscr)
    n))

(defun make-accent-noad (accent nucleus
                         &optional (supscr (make-empty-field))
                                   (subscr (make-empty-field)))
  (let ((n (new-noad :accent)))
    (setf (n-accent-chr n) accent (n-nucleus n) nucleus
          (n-supscr n) supscr (n-subscr n) subscr)
    n))

(defun left-noad (delimiter)
  "tex.web left_noad: the delimiter is stored in the nucleus field."
  (let ((n (new-noad :left)))
    (setf (n-left-delimiter n) delimiter)
    n))

(defun right-noad (delimiter)
  "tex.web right_noad: the delimiter is stored in the nucleus field."
  (let ((n (new-noad :right)))
    (setf (n-right-delimiter n) delimiter)
    n))

(defun make-over-noad (nucleus) (let ((n (new-noad :over))) (setf (n-nucleus n) nucleus) n))
(defun make-under-noad (nucleus) (let ((n (new-noad :under))) (setf (n-nucleus n) nucleus) n))
(defun make-vcenter-noad (nucleus) (let ((n (new-noad :vcenter))) (setf (n-nucleus n) nucleus) n))

(defun make-matrix-noad (rows)
  "An engine extension (not tex.web): ROWS is a list of rows, each a list of
cell mlists. Laid out as a centered grid."
  (let ((n (new-noad :matrix)))
    (setf (n-list n) rows)
    n))

;;; --- Node predicates (tex.web: is_char_node, box_node, …) ------------------

(defun char-node-p (n) (and n (eq (n-type n) :char)))
(defun box-node-p (n) (member (and n (n-type n)) '(:hlist :vlist)))
(defun glue-node-p (n) (and n (eq (n-type n) :glue)))
(defun kern-node-p (n) (and n (eq (n-type n) :kern)))
(defun rule-node-p (n) (and n (eq (n-type n) :rule)))
(defun style-node-p (n) (and n (eq (n-type n) :style)))
(defun penalty-node-p (n) (and n (eq (n-type n) :penalty)))

;;; --- Noad type classification (tex.web §689-§706) --------------------------

(defparameter *ordinary-noad-types*
  '(:ord :op :bin :rel :open :close :punct :inner))

(defun noad-p (n)
  (and n (member (n-type n)
                 '(:ord :op :bin :rel :open :close :punct :inner
                   :radical :fraction :under :over :accent :vcenter
                   :left :right :matrix))))

(defun scripts-allowed-p (n)
  "tex.web scripts_allowed(#)==(type(#)>=ord_noad)and(type(#)<left_noad)."
  (and n (member (n-type n) '(:ord :op :bin :rel :open :close :punct :inner
                              :radical :fraction :under :over :accent
                              :vcenter))))

(defun noad-type-index (n)
  "Spacing-class index 0-7 of a noad (tex.web: type(q)-ord_noad)."
  (case (n-type n)
    (:ord 0) (:op 1) (:bin 2) (:rel 3)
    (:open 4) (:close 5) (:punct 6) (:inner 7)
    (t 0)))

(defun noad-type-name (n)
  (case (n-type n)
    (:ord "Ord") (:op "Op") (:bin "Bin") (:rel "Rel")
    (:open "Open") (:close "Close") (:punct "Punct") (:inner "Inner")
    (:radical "Radical") (:fraction "Fraction") (:under "Under")
    (:over "Over") (:accent "Accent") (:vcenter "VCenter")
    (:left "Left") (:right "Right")
    (t "Unknown")))

;;; --- List helpers (tex.web: link/type traversal) ---------------------------

(defun last-node (list)
  (let ((p list))
    (when p (loop while (n-link p) do (setf p (n-link p))))
    p))

(defun nl-reverse (head)
  "Reverse a node-linked list in place; return the new head."
  (let ((prev nil))
    (loop while head do
      (let ((next (n-link head)))
        (setf (n-link head) prev)
        (setf prev head head next)))
    prev))

(defun append-node-list (a b)
  "Destructively concatenate node lists A and B (either may be nil)."
  (cond ((null a) b)
        ((null b) a)
        (t (setf (n-link (last-node a)) b) a)))

(defun nl (&rest nodes)
  "Link NODES into a node-linked list (returns the head node or nil)."
  (let ((head nil) (tail nil))
    (dolist (n nodes)
      (when n
        (setf (n-link n) nil)
        (if head (setf (n-link tail) n tail n)
            (setf head n tail n))))
    head))

(defun nl-append (&rest lists)
  "Concatenate node-linked lists (each a head node or nil) through N-LINK."
  (let ((head nil) (tail nil))
    (dolist (l lists)
      (when l
        (if head (setf (n-link tail) l tail (last-node l))
            (setf head l tail (last-node l)))))
    head))

(defun list-length-nodes (list)
  (let ((n 0) (p list))
    (loop while p do (incf n) (setf p (n-link p)))
    n))

;;; Every list node is a NODE struct, so a node is trivially `box-p` in the
;;; old API sense. Kept for the renderer/front-end convenience.
(defun box-p (x) (typep x 'node))
