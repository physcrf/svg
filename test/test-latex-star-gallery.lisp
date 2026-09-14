;;;; test-latex-star-gallery.lisp --- latex* gallery mirroring `typesetting'
;;;;
;;;; Load with:  sbcl --non-interactive --load test/test-latex-star-gallery.lisp
;;;;
;;;; This is the LaTeX-source twin of the sibling `typesetting' system's own
;;;; gallery (typesetting/examples/render-svgs.lisp), so the two can be
;;;; compared side by side in a browser: same formulas, same names, same
;;;; output files. Every formula is written as the LaTeX a user would type,
;;;; parsed by latex*, and typeset by the vendored svg-tex engine.
;;;;
;;;; Where the sibling pins an exact (width height depth) snapshot
;;;; (typesetting/test/snapshots.lisp, `*expected-geometry*' and friends), the
;;;; same sp triple is pinned here, so a drift in either system shows up.

(ql:quickload :svg :silent t)

(in-package #:svg)

(defparameter *gallery-cases*
  ;; name, LaTeX source, expected (width height depth) in sp or nil.
  '(;; --- core constructs, mirrored from render-svgs.lisp ------------------
    ("char-x"              "$x$"                                        (374556 282168 0))
    ("superscript"         "$x^2$"                                      (668559 566233 0))
    ("subscript"           "$x_2$"                                      (668559 282168 98303))
    ;; the sibling's :both-scripts is x with superscript 2 and subscript 1
    ("both-scripts"        "$x_1^2$"                                    (668559 566233 162016))
    ("fraction"            "$\\frac{1}{2}$"                             (484967 865699 449545))
    ("nested-fraction"     "$\\frac{\\frac{1}{2}}{3}$"                  (575807 1035257 449545))
    ("radical"             "$\\sqrt{x}$"                                (920691 556461 125111))
    ("frac-sqrt"           "$\\frac{\\sqrt{x}}{2}$"                     (1077977 967822 449545))
    ("nested-superscript"  "$x^{y^2}$"                                  (945347 679538 0))
    ("overline"            "$\\overline{x}$"                            (374556 413233 0))
    ("under-rule"          "$\\underline{x}$"                           (374556 282168 131065))
    ("accent"              "$\\tilde{x}$"                               (374556 437688 0))
    ("accent-hat"          "$\\hat{x}$"                                 (374556 455111 0))
    ("delimited"           "$(x)$"                                      (884282 491520 163840))
    ;; We lay the grid out the way LaTeX does (per-row strut, 1em column gap,
    ;; \vcenter), so this matches a real latex run -- 1342882 950272 622592 --
    ;; and not the sibling's grid, which keeps the rows unstrutted and the box
    ;; floating above the baseline (1015202 1237902 0). See
    ;; *GALLERY-KNOWN-DEVIATIONS*.
    ("matrix-2x2"          "$\\begin{matrix}a&b\\\\c&d\\end{matrix}$"   (1342883 950273 622593))
    ("binomial"            "$\\binom{n}{k}$"                            (1358210 950279 622600))
    ("spacing-ord-bin-ord" "$a-b$"                                      (1428664 455111 54613))
    ("op-limits-scripts"   "$\\sum_0^n$"                                nil)
    ;; --- extended gallery -------------------------------------------------
    ("continued-fraction"  "$\\frac{1}{\\frac{1}{\\frac{1}{2}}}$"       (694866 865699 902258))
    ("nested-radical"      "$\\sqrt{\\sqrt{\\sqrt{x}}}$"                (2231413 1164403 434689))
    ("superscripts-deep"   "$x^{y^{z^2}}$"                              (1215911 811774 0))
    ("sqrt-compound"       "$\\sqrt{b^2-4ac}$"                          (2989320 696093 116559))
    ("integral"            "$\\int_0^1 x^2 dx$"                         (2442809 1025647 597113))
    ("left-fraction"       "$\\left(\\frac{1}{2}\\right)$"              (1449807 950279 622600))
    ("left-fraction-nested"
     "$\\left(\\frac{\\frac{1}{2}}{\\frac{3}{4}}\\right)$"              (1540647 1035257 707577))
    ("sum-fraction"        "$\\sum_{i=1}^{n}\\frac{1}{i^2}$"            (1732926 1082257 838772))
    ("quadratic"           "$x=\\frac{-b\\pm\\sqrt{b^2-4ac}}{2a}$"      (5877716 1041915 449545))
    ;; --- Greek gallery ----------------------------------------------------
    ("greek-alphabet"
     "$\\Gamma\\Delta\\Theta\\Lambda\\Xi\\Pi\\Sigma\\Upsilon\\Phi\\Psi\\Omega\\alpha\\beta\\gamma\\delta\\epsilon\\zeta\\eta\\theta\\iota\\kappa\\lambda\\mu\\nu\\xi\\pi\\rho\\sigma\\tau\\upsilon\\phi\\chi\\psi\\omega$"
     nil)
    ("greek-alpha-plus-beta" "$\\alpha+\\beta$"                         (1627927 455111 127431))
    ("greek-pi-over-two"   "$\\frac{\\pi}{2}$"                          (554372 725524 449545))
    ("greek-sqrt-alpha"    "$\\sqrt{\\alpha}$"                          (967796 556461 125111))
    ("greek-gamma-function" "$\\Gamma(\\frac{n}{2})$"                   (1469983 725524 449545))
    ("greek-euler-pi"      "$e^{i\\pi}+1=0$"                            (3176426 574151 54613))
    ("greek-trig"          "$\\sin^2\\theta+\\cos^2\\theta=1$"          nil)
    ("greek-euler-trig"    "$\\cos\\theta+i\\sin\\theta=e^{i\\theta}$"  nil)
    ("greek-discriminant"  "$\\Delta=\\beta^2-4\\alpha\\gamma$"         nil)
    ("greek-golden-ratio"  "$\\varphi=\\frac{1+\\sqrt{5}}{2}$"          nil)
    ("greek-binomial-sum"
     "$\\sum_{k=0}^{n}\\binom{n}{k}\\alpha^k\\beta^{n-k}$"              nil)
    ("greek-standard-deviation"
     "$\\sigma=\\sqrt{\\frac{1}{n}\\sum_{i=1}^{n}(x_i-\\mu)^2}$"        nil)
    ("greek-gamma-integral"
     "$\\Gamma(z)=\\int_0^\\infty t^{z-1}e^{-t}dt$"                     nil)
    ("greek-wave"          "$\\psi(x)=A\\sin(kx+\\varphi)$"             nil)
    ("greek-omega-frequency" "$\\omega=\\sqrt{\\frac{k}{m}}$"           nil)
    ("greek-pi-squared-sixth"
     "$\\sum_{n=1}^{\\infty}\\frac{1}{n^2}=\\frac{\\pi^2}{6}$"          nil)))

(defparameter *gallery-dir*
  (merge-pathnames "gallery/"
                   (make-pathname :directory (pathname-directory *load-truename*))))

(defparameter *typesetting-output-dir*
  #p"/home/crf/.quicklisp/local-projects/typesetting/examples/output/"
  "The sibling system's own gallery, when it is checked out next to this one.
Copied in beside our SVGs so index.html can show both renderings of the same
formula side by side.")

(defun gallery-sp-pt (sp) (/ sp 65536.0))

(defun gallery-write-file (path string)
  (ensure-directories-exist path)
  (with-open-file (out path :direction :output :if-exists :supersede
                            :if-does-not-exist :create :external-format :utf-8)
    (write-string string out)))

(defun gallery-svg-name (name)
  (make-pathname :name name :type "svg" :defaults *gallery-dir*))

(defun gallery-normalize (svg)
  "Drop the font-family fallback lists SVG-FONT-NAME writes. The sibling names
the script fonts by their primary family alone; we append `Latin Modern Roman'
so a renderer with a restricted font view still resolves them. That is the one
deliberate difference between the two outputs, so removing it here leaves only
real rendering differences for the mirror check."
  (str:replace-all ", Latin Modern Roman" ""
                   (str:replace-all ", Latin Modern Math" "" svg)))

(defun gallery-first-difference (ours theirs)
  "The first line pair where OURS and THEIRS differ, or NIL when equal."
  (loop for a in (str:split #\Newline ours)
        for b in (str:split #\Newline theirs)
        unless (string= a b)
          do (return (list a b))))

(defparameter *gallery-known-deviations*
  '(("accent-hat" .
     "the sibling previews \\hat with the ASCII caret U+005E, whose ink sits
      .5pt higher than the accent in LaTeX's own cmr10 (measured against a
      real latex run); we preview it with U+02C6, cmr10's design")
    ("matrix-2x2" .
     "we centre the grid on the math axis and give every row LaTeX's \strut,
      which is what a real latex run does (height 14.5pt, depth 9.5pt); the
      sibling's grid leaves the rows unstrutted, so its matrix is 18.889pt
      high with zero depth")
    ;; The sibling draws the large operators' Latin Modern outlines at their
    ;; design size; CM's display designs sit 1.1pt inside their 16pt operator
    ;; box (cmex10.pfb, measured off a real latex run), so we scale each one
    ;; onto its own ink box. Same for the text sizes to within .04pt.
    ("op-limits-scripts" .
     "we fit the operator outline onto cmex10's own ink box (see above)")
    ("sum-fraction" .
     "we fit the operator outline onto cmex10's own ink box (see above)")
    ("greek-binomial-sum" .
     "we fit the operator outline onto cmex10's own ink box (see above)")
    ("greek-standard-deviation" .
     "we fit the operator outline onto cmex10's own ink box (see above)")
    ("greek-pi-squared-sixth" .
     "we fit the operator outline onto cmex10's own ink box (see above)"))
  "Formulas whose SVG deliberately differs from the sibling's, name -> why.
Everything else must match once *GALLERY-NORMALIZE* has removed the
font-family fallback lists.")

(defun gallery-mirror-check (written)
  "Compare every SVG we wrote against the sibling's copy of the same formula.
Returns (SAME DIFFERENT MISSING KNOWN): the names that match, the names that
drifted (with the first differing line printed), the names the sibling has no
gallery entry for at all, and the names that differ as documented in
*GALLERY-KNOWN-DEVIATIONS*."
  (let ((same nil) (different nil) (missing nil) (known nil))
    (dolist (entry (reverse written))
      (let* ((name (first entry))
             (why (cdr (assoc name *gallery-known-deviations* :test #'string=)))
             (theirs (merge-pathnames (str:concat name ".svg")
                                      (merge-pathnames "typesetting/" *gallery-dir*))))
        (cond
          ((not (probe-file theirs)) (push name missing))
          ((string= (gallery-normalize
                     (uiop:read-file-string (gallery-svg-name name)))
                    (gallery-normalize (uiop:read-file-string theirs)))
           (push name same))
          (why (push name known))
          (t
           (push name different)
           (let ((lines (gallery-first-difference
                         (gallery-normalize (uiop:read-file-string (gallery-svg-name name)))
                         (gallery-normalize (uiop:read-file-string theirs)))))
             (format t "     mirror differs: ~a~%       ours:   ~a~%       theirs: ~a~%"
                     name (first lines) (second lines)))))))
    (list (nreverse same) (nreverse different) (nreverse missing) (nreverse known))))

(defun gallery-mirror-typesetting (written)
  "Copy the sibling's SVG for every name we also render; return the names that
made it, so the index can put the two side by side."
  (let ((dir (merge-pathnames "typesetting/" *gallery-dir*))
        (copied nil))
    (dolist (entry written (nreverse copied))
      (let* ((name (first entry))
             (src (merge-pathnames (str:concat name ".svg") *typesetting-output-dir*))
             (dst (merge-pathnames (str:concat name ".svg") dir)))
        (when (probe-file src)
          (ensure-directories-exist dst)
          (uiop:copy-file src dst)
          (push name copied))))))

(defun gallery-index (written)
  "HTML gallery in the same shape as typesetting/examples/output/index.html."
  (let ((mirrored (gallery-mirror-typesetting written)))
    (with-output-to-string (s)
    (format s "<!DOCTYPE html>~%<html><head><meta charset=\"utf-8\">~%")
    (format s "<title>svg latex* gallery (mirrors typesetting)</title>~%")
    (format s "<style>~%")
    (format s "body{font-family:system-ui,sans-serif;margin:2em;background:#fafafa}~%")
    (format s "h1{font-size:1.4em}~%")
    (format s ".grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(260px,1fr));gap:1em}~%")
    (format s ".card{background:#fff;border:1px solid #ddd;border-radius:6px;padding:1em}~%")
    (format s ".card h3{font-size:0.95em;margin:0 0 0.3em;font-family:monospace}~%")
    (format s ".card code{font-size:0.8em;color:#666;display:block;margin:0 0 0.6em}~%")
    (format s ".pair{display:grid;grid-template-columns:1fr 1fr;gap:0.6em}~%")
    (format s ".pair figure{margin:0}~%")
    (format s ".pair figcaption{font-size:0.7em;color:#888;margin-top:0.3em}~%")
    (format s ".card img{max-width:100%;height:auto;display:block;background:#fff}~%")
    (format s "</style></head><body>~%")
    (format s "<h1>svg <code>latex*</code> gallery</h1>~%")
    (format s "<p>~D formulas, mirroring <code>typesetting/examples/render-svgs.lisp</code>.~@[ Left: this library (<code>latex*</code>). Right: the sibling <code>typesetting</code> gallery.~]</p>~%"
            (length written) mirrored)
    (format s "<div class=\"grid\">~%")
    (loop for (name source) in (reverse written)
          do (progn
               (format s "<div class=\"card\"><h3>~A</h3><code>~A</code>~%"
                       name (xml-escape source))
               (if (member name mirrored :test #'string=)
                   (format s "<div class=\"pair\"><figure><img src=\"~A.svg\" alt=\"~A\"><figcaption>latex*</figcaption></figure><figure><img src=\"typesetting/~A.svg\" alt=\"~A\"><figcaption>typesetting</figcaption></figure></div>~%"
                           name name name name)
                   (format s "<img src=\"~A.svg\" alt=\"~A\">~%" name name))
               (format s "</div>~%")))
    (format s "</div></body></html>~%"))))

(defun test-latex-star-gallery ()
  (format t "~%=== latex* gallery (mirrors the typesetting corpus) ===~%")
  (let ((pass 0) (fail 0) (written nil) (geometry-checked 0))
    (dolist (entry *gallery-cases*)
      (destructuring-bind (name source expected) entry
        (handler-case
            (let* ((box (latex-typeset source))
                   (got (list (svg-tex:n-width box)
                              (svg-tex:n-height box)
                              (svg-tex:n-depth box)))
                   (ok (or (null expected) (equal got expected))))
              (incf geometry-checked (if expected 1 0))
              (if ok (incf pass) (incf fail))
              (format t "~:[FAIL~;ok  ~] ~a~@[~%       got ~a~%       want ~a~]~%"
                      ok name (unless ok got) (unless ok expected))
              (let ((svg (latex*-svg source)))
                (if (and (> (length svg) 200) (search "</svg>" svg))
                    (progn (incf pass)
                           (gallery-write-file (gallery-svg-name name) svg)
                           (push (list name source) written))
                    (progn (incf fail)
                           (format t "     the SVG for ~a is malformed~%" name)))))
          (error (e)
            (incf fail)
            (format t "FAIL ~a~%       ~a~%" name e)))))
    (when written
      (gallery-write-file (merge-pathnames "index.html" *gallery-dir*)
                          (gallery-index written)))
    ;; The sibling's gallery is written into test/gallery/typesetting/ above, so
    ;; both renderings of every formula can be compared.
    (let ((mirror (when written (gallery-mirror-check written))))
      (when mirror
        (destructuring-bind (same different missing known) mirror
          (format t "~%Mirror check: ~D identical, ~D documented differences, ~D not in the sibling's gallery~%"
                  (length same) (length known) (length missing))
          (dolist (name known)
            (format t "     ~a: ~a~%" name (cdr (assoc name *gallery-known-deviations*
                                                       :test #'string=))))
          (when different
            (incf fail (length different))
            (format t "the SVGs listed above no longer match the sibling's~%")))))
    (format t "~%~D passed, ~D failed (~D geometry snapshots pinned from typesetting)~%"
            pass fail geometry-checked)
    (format t "Gallery: ~a~%" *gallery-dir*)
    (when (plusp fail) (error "latex* gallery failed"))))

(test-latex-star-gallery)
