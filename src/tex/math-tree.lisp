;;;; math-tree.lisp — declarative math tree → mlist (tex.web mlist builder)
;;;;
;;;; A `math-tree` is a labelled S-expression that compiles to a TeX mlist.
;;;; Lists are node-linked (TeX's `link`): a list is its head NODE (or nil),
;;;; and the chain runs through N-LINK. Most trees compile to a single noad;
;;;; :delimited compiles to left_noad …content… right_noad.

(in-package :svg-tex)

(defstruct math-tree
  (label nil :type symbol)
  (children nil :type list))

(defun make-math-char-tree (char) (make-math-tree :label :math-char :children (list char)))
(defun make-subscript-tree (base sub) (make-math-tree :label :subscript :children (list base sub)))
(defun make-superscript-tree (base sup) (make-math-tree :label :superscript :children (list base sup)))
(defun make-fraction-tree (num den) (make-math-tree :label :fraction :children (list num den)))
(defun make-radical-tree (radicand &optional index)
  (if index
      (make-math-tree :label :radical :children (list radicand index))
      (make-math-tree :label :radical :children (list radicand))))
(defun make-operator-tree (op &optional limits)
  (make-math-tree :label :operator :children (list op (or limits :normal))))
(defun make-accent-tree (accent base) (make-math-tree :label :accent :children (list accent base)))
(defun make-over-tree (base) (make-math-tree :label :over :children (list base)))
(defun make-under-tree (base) (make-math-tree :label :under :children (list base)))
(defun make-delimited-tree (left content right)
  (make-math-tree :label :delimited :children (list left content right)))
(defun make-matrix-tree (rows) (make-math-tree :label :matrix :children rows))
(defun make-binomial-tree (num den) (make-math-tree :label :binomial :children (list num den)))

(defun math-tree-single-math-char (tree)
  (when (and tree (eq (math-tree-label tree) :math-char))
    (first (math-tree-children tree))))

(defparameter *delimiter-delcodes*
  ;; plain TeX's \delcode assignments (plain.tex L122-130).  A \delcode has
  ;; six hex digits [small fam][small char][large fam][large char]; the char
  ;; key is the delimiter as written, i.e. cmr10 for ( ) [ ] / and cmsy10 for
  ;; \langle \rangle \| \\.  TeX leaves \delcode as -1 for everything else
  ;; (notably { and }, which must not get delcodes), and \delcode`. is 0: the
  ;; null delimiter that \left. produces.
  '(((0 . 40)  0 40 3 0)     ; (
    ((0 . 41)  0 41 3 1)     ; )
    ((0 . 91)  0 91 3 2)     ; [
    ((0 . 93)  0 93 3 3)     ; ]
    ((0 . 47)  0 47 3 14)    ; /
    ((0 . 46)  0 0  0 0)     ; .  (null delimiter)
    ((2 . 104) 2 104 3 10)   ; \langle
    ((2 . 105) 2 105 3 11)   ; \rangle
    ((2 . 106) 2 106 3 12)   ; \|
    ((2 . 110) 2 110 3 15))  ; \\
  "plain TeX's \\delcode table, keyed by (family . code) as written.")

(defun math-tree-to-delimiter (tree)
  "Build a delimiter from a single :math-char tree; nil means 'no fence'."
  (let ((mc (math-tree-single-math-char tree)))
    (when mc
      (let* ((fam (mc-family mc))
             (code (mc-code mc))
             (delcode (assoc (cons fam code) *delimiter-delcodes*
                             :test #'equal)))
        (if delcode
            (destructuring-bind (sf sc lf lc) (cdr delcode)
              (make-delimiter sf sc lf lc))
            ;; No \delcode for this character: keep both slots equal, so
            ;; var_delimiter can only use the character itself.
            (make-delimiter fam code fam code))))))

(defun math-tree-to-nucleus-field (tree)
  "A single :math-char tree becomes a math_char field (as TeX's scanner does);
anything else becomes a sub_mlist field. This matters for accents, whose skew
is only computed when the nucleus is a math_char (tex.web make_math_accent)."
  (let ((mc (math-tree-single-math-char tree)))
    (if mc
        (make-math-char-field mc)
        (make-sub-mlist-field (math-tree-to-mlist tree)))))

(defun math-tree-to-mlist (tree)
  "Compile TREE to a node-linked mlist (head node or nil)."
  (case (math-tree-label tree)
    (:math-char
     (ord-noad (make-math-char-field (first (math-tree-children tree)))))
    (:subscript
     (destructuring-bind (base sub) (math-tree-children tree)
       (let ((noads (math-tree-to-mlist base)))
         (when noads
           (setf (n-subscr noads) (make-sub-mlist-field (math-tree-to-mlist sub))))
         noads)))
    (:superscript
     (destructuring-bind (base sup) (math-tree-children tree)
       (let ((noads (math-tree-to-mlist base)))
         (when noads
           (setf (n-supscr noads) (make-sub-mlist-field (math-tree-to-mlist sup))))
         noads)))
    (:fraction
     (destructuring-bind (num den) (math-tree-children tree)
       (make-fraction-noad nil
                           (make-sub-mlist-field (math-tree-to-mlist num))
                           (make-sub-mlist-field (math-tree-to-mlist den)))))
    (:radical
     (destructuring-bind (radicand &optional index) (math-tree-children tree)
       ;; plain TeX \sqrt delcode "270370": small=(cmsy,112), large=(cmex,112).
       (let ((noad (make-radical-noad
                    (math-tree-to-nucleus-field radicand)
                    (make-delimiter 2 112 3 112))))
         (when index
           (setf (n-supscr noad) (make-sub-mlist-field (math-tree-to-mlist index))))
         noad)))
    (:operator
     (destructuring-bind (op limits) (math-tree-children tree)
       (op-noad (make-math-char-field op) :subtype limits)))
    (:accent
     (destructuring-bind (accent base) (math-tree-children tree)
       (make-accent-noad accent
                         (math-tree-to-nucleus-field base))))
    (:over
     (make-over-noad
      (math-tree-to-nucleus-field (first (math-tree-children tree)))))
    (:under
     (make-under-noad
      (math-tree-to-nucleus-field (first (math-tree-children tree)))))
    (:delimited
     ;; tex.web \left...\right: left_noad ...content... right_noad.
     (destructuring-bind (left content right) (math-tree-children tree)
       (nl-append (left-noad (or (math-tree-to-delimiter left) (null-delimiter)))
                  (math-tree-to-mlist content)
                  (right-noad (or (math-tree-to-delimiter right) (null-delimiter))))))
    (:matrix
     (make-matrix-noad
      (mapcar (lambda (row)
                (if (listp row)
                    (mapcar #'math-tree-to-mlist row)
                    (list (math-tree-to-mlist row))))
              (math-tree-children tree))))
    (:binomial
     ;; \binom = {n \atopwithdelims() k}: thickness 0, real paren delimiters.
     (destructuring-bind (num den) (math-tree-children tree)
       (make-fraction-noad 0
                           (make-sub-mlist-field (math-tree-to-mlist num))
                           (make-sub-mlist-field (math-tree-to-mlist den))
                           (make-delimiter 0 40 3 0)
                           (make-delimiter 0 41 3 1))))
    (t nil)))

(defun typeset-math-tree (tree env)
  "Compile TREE to an mlist and typeset it with ENV's style and fonts."
  (mlist-to-box (math-tree-to-mlist tree)
                (env-math-style env)
                (env-math-fonts env)))
