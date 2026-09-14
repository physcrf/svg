;;;; math-mode.lisp — math-builder: a local accumulator that pushes noads
;;;;
;;;; The functional env (env.lisp) is the sole state carrier; the builder holds
;;;; the env (read-only) plus a reversed mlist. with-math-builder returns
;;;; (values mlist env) so the caller can feed the mlist into mlist-to-box.

(in-package :svg-tex)

(defstruct math-builder
  (env nil :type (or null typesetting-env))
  (mlist nil :type (or null node)))

(defun builder-add-noad (builder noad)
  (setf (n-link noad) (math-builder-mlist builder))
  (setf (math-builder-mlist builder) noad)
  noad)

(defun builder-add-char (builder family code)
  (builder-add-noad builder
    (ord-noad (make-math-char-field
               (make-mchar :family family :code code)))))

(defun builder-add-fraction (builder num-mlist den-mlist)
  (builder-add-noad builder
    (make-fraction-noad nil
                        (make-sub-mlist-field num-mlist)
                        (make-sub-mlist-field den-mlist))))

(defun builder-add-radical (builder radicand-mlist &optional index-mlist)
  (let ((noad (make-radical-noad
               (make-sub-mlist-field radicand-mlist)
               (make-delimiter 2 112 3 112))))
    (when index-mlist
      (setf (n-supscr noad) (make-sub-mlist-field index-mlist)))
    (builder-add-noad builder noad)))

(defun builder-add-subscript (builder mlist)
  (let ((last (math-builder-mlist builder)))
    (when (noad-p last)
      (setf (n-subscr last) (make-sub-mlist-field mlist)))))

(defun builder-add-superscript (builder mlist)
  (let ((last (math-builder-mlist builder)))
    (when (noad-p last)
      (setf (n-supscr last) (make-sub-mlist-field mlist)))))

(defun builder-add-left-delimiter (builder delimiter)
  (builder-add-noad builder
    (open-noad (make-math-char-field
                (make-mchar :family (delim-small-family delimiter)
                            :code (delim-small-char delimiter))))))

(defun builder-add-right-delimiter (builder delimiter)
  (builder-add-noad builder
    (close-noad (make-math-char-field
                 (make-mchar :family (delim-large-family delimiter)
                             :code (delim-large-char delimiter))))))

(defun builder-add-accent (builder accent)
  (builder-add-noad builder
    (make-accent-noad accent (make-empty-field))))

(defun builder-add-matrix (builder rows)
  (builder-add-noad builder (make-matrix-noad rows)))

(defun builder-mlist (builder)
  "Return the accumulated mlist in left-to-right order (head node)."
  (nl-reverse (math-builder-mlist builder)))

(defun builder-env (builder)
  (math-builder-env builder))

(defmacro with-math-builder ((builder-var &key (style 'display-style)
                                           (fonts nil) (env nil))
                             &body body)
  "Bind BUILDER-VAR to a fresh math-builder and return (values mlist env)."
  (let ((e (gensym "ENV")))
    `(let* ((,e (or ,env (make-env :style ,style :fonts ,fonts))))
       (declare (ignorable ,e))
       (let ((,builder-var (make-math-builder :env ,e)))
         (declare (ignorable ,builder-var))
         ,@body
         (values (nl-reverse (math-builder-mlist ,builder-var)) ,e)))))

;;; ---------------------------------------------------------------------------
;;; Functional entry points
;;; ---------------------------------------------------------------------------

(defun typeset-math (mlist env)
  "Typeset an mlist using the style and fonts carried by ENV."
  (mlist-to-box mlist (env-math-style env) (env-math-fonts env)))
