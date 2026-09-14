;;;; test-latex-symbols.lisp --- every LaTeX math symbol renders
;;;;
;;;; Load with:  sbcl --non-interactive --load test/test-latex-symbols.lisp
;;;;
;;;; The generated table (src/latex-tables.lisp) holds the full LaTeX symbol
;;;; set from fontmath.ltx. This walks it and checks that each command
;;;; typesets to a non-empty box and a non-trivial SVG; a missing glyph shows
;;;; up here immediately. Geometry for a representative subset is pinned in
;;;; test-latex-star.lisp (validated against real LaTeX).

(ql:quickload :svg :silent t)

(in-package #:svg)

(defun latex-symbol-command-names ()
  "Every symbol command (multi-character name) in *latex-symbols*."
  (let ((names nil))
    (dolist (entry *latex-symbols* (nreverse names))
      (let ((name (first entry)))
        ;; single-character entries are literal mathcodes, not \commands
        (when (and (> (length name) 1)
                   (not (char= (char name 0) #\@)))   ; internal names
          (push name names))))))

(defun test-latex-symbols ()
  (format t "~%=== Test native LaTeX symbols (latex*) ===~%")
  (let ((pass 0) (fail 0))
    (dolist (name (latex-symbol-command-names))
      (handler-case
          (let* ((formula (concatenate 'string "\\" name))
                 (box (latex-typeset formula))
                 (svg (latex*-svg formula)))
            ;; a few symbols are zero-width building blocks (\not,
            ;; \mapstochar), so check that a glyph was actually drawn.
            (if (and (> (length svg) 150)
                     (or (search "<text" svg) (search "<path" svg))
                     (search "</svg>" svg))
                (incf pass)
                (progn (incf fail) (format t "FAIL ~a (empty box/svg)~%" name))))
        (error (e)
          (incf fail)
          (format t "FAIL ~a : ~a~%" name e))))
    (format t "~%~d symbols passed, ~d failed~%" pass fail)
    (when (plusp fail) (error "latex symbol tests failed"))))

(test-latex-symbols)
