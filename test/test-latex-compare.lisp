;;;; test-latex-compare.lisp --- gallery: `latex' next to `latex*'
;;;;
;;;; Load with:  sbcl --non-interactive --load test/test-latex-compare.lisp
;;;;
;;;; Every formula is rendered twice, from the same source string:
;;;;
;;;;   latex   -- shells out to latex + dvisvgm (the reference rendering)
;;;;   latex*  -- typesets in-process with the vendored TeX engine
;;;;
;;;; and the two are placed on one shared baseline in a card of their own, so a
;;;; difference in glyph position, accent height, delimiter size or script size
;;;; shows up as a visible shift between the columns. The cards are collected
;;;; in test/gallery-compare/index.html.
;;;;
;;;; The reference column needs a TeX installation; its box geometry is
;;;; measured live (\\setbox + \\typeout, in sp) and compared with the box
;;;; latex* computes, so the gallery reports drift instead of only pictures.

(ql:quickload :svg :silent t)

(in-package #:svg)

(defparameter *compare-cases*
  ;; name, formula -- the syntax latex* supports, in roughly the order the
  ;; README lists it (see also *gallery-cases*, which mirrors the sibling
  ;; `typesetting' corpus)
  '(;; --- atoms, scripts, spacing -----------------------------------------
    ("char-x"             "$x$")
    ("italic-letters"     "$E = mc^2$")
    ("superscript"        "$x^2$")
    ("subscript"          "$x_2$")
    ("both-scripts"       "$x_i^2$")
    ("deep-scripts"       "$x^{y^{z^2}}$")
    ("spacing-ord-bin"    "$a - b = c + d$")
    ("thin-space"         "$f(x)\\,dx$")
    ("quad"               "$a \\quad b \\qquad c$")
    ;; --- fractions, radicals, binomials ----------------------------------
    ("fraction"           "$\\frac{1}{2}$")
    ("continued-fraction" "$\\frac{1}{1+\\frac{1}{x}}$")
    ("nested-fraction"    "$\\frac{\\frac{1}{2}}{3}$")
    ("dfrac"              "$\\dfrac{a}{b}$")
    ("binom"              "$\\binom{n}{k}$")
    ("radical"            "$\\sqrt{x}$")
    ("sqrt-index"         "$\\sqrt[3]{x+y}$")
    ("sqrt-index-frac"    "$\\sqrt[3]{\\frac{a}{b}}$")
    ("sqrt-index-greek"   "$\\sqrt[\\beta]{x}$")
    ("sqrt-index-nested"  "$\\sqrt[3]{\\sqrt{x}}$")
    ("nested-radical"     "$\\sqrt{\\sqrt{\\sqrt{x}}}$")
    ("quadratic"          "$x = \\frac{-b \\pm \\sqrt{b^2-4ac}}{2a}$")
    ;; --- accents ---------------------------------------------------------
    ("accent-hat"         "$\\hat{x}$")
    ("accent-tilde"       "$\\tilde{x}$")
    ("accent-vec"         "$\\vec{E}$")
    ("accent-bar-dot"     "$\\bar{x} + \\dot{y} + \\ddot{z}$")
    ("accent-caron"       "$\\check{a} \\breve{b} \\acute{c} \\grave{d}$")
    ("accent-ring"        "$\\mathring{x}$")
    ("accent-overline"    "$\\overline{x+y}$")
    ("accent-underline"   "$\\underline{x+y}$")
    ("accent-wide"        "$\\widehat{H} \\quad \\widehat{abc} \\quad \\widetilde{xyz}$")
    ;; --- delimiters, matrices -------------------------------------------
    ("left-right"         "$\\left(\\frac{a}{b}\\right)$")
    ("left-bracket"       "$\\left[\\frac{a}{b}\\right]$")
    ("big-delimiters"     "$\\left\\{\\frac{x}{y}\\right\\} \\quad \\left\\langle x \\right\\rangle$")
    ("matrix"             "$\\begin{pmatrix} a & b \\\\ c & d \\end{pmatrix}$")
    ("bmatrix"            "$\\begin{bmatrix} 1 & 0 \\\\ 0 & 1 \\end{bmatrix}$")
    ("vmatrix"            "$\\begin{vmatrix} a & b \\\\ c & d \\end{vmatrix}$")
    ("Bmatrix"            "$\\begin{Bmatrix} a & b \\\\ c & d \\end{Bmatrix}$")
    ("determinant"        "$\\left|\\begin{matrix} a & b \\\\ c & d \\end{matrix}\\right|$")
    ("tall-matrix"        "$\\begin{pmatrix} a & b \\\\ c & d \\\\ e & f \\\\ g & h \\\\ i & j \\end{pmatrix}$")
    ("braces-delims"      "$\\left\\{\\frac{a}{b}\\right\\}$")
    ("floor-delims"       "$\\left\\lfloor\\frac{a}{b}\\right\\rfloor$")
    ("angle-delims"       "$\\left\\langle\\frac{a}{b}\\right\\rangle$")
    ("norm"               "$\\left\\|\\frac{a}{b}\\right\\|$")
    ;; --- operators, relations, arrows -----------------------------------
    ("sum-limits"         "$\\sum_{i=1}^{n} x_i^2$")
    ("integral"           "$\\int_0^\\infty e^{-x^2} dx$")
    ("oint"               "$\\oint_C \\vec{B}\\cdot d\\vec{l}$")
    ("prod-limits"        "$\\prod_{k=1}^{n} a_k$")
    ("bigcup"             "$\\bigcup_{i \\in I} A_i$")
    ("lim"                "$\\lim_{x\\to 0}\\frac{\\sin x}{x}=1$")
    ("named-operators"    "$\\sin^2\\theta + \\cos^2\\theta = 1$")
    ("operatorname"       "$\\operatorname{Tr}(\\rho \\log \\rho)$")
    ("relations"          "$x \\leq y \\geq z \\neq w \\in S \\subset T$")
    ("notin"              "$x \\notin S \\qquad \\not\\subset T$")
    ("arrows"             "$A \\to B \\Rightarrow C \\leftrightarrow D$")
    ;; --- alphabets, text, math-mode switches ----------------------------
    ("greek"              "$\\alpha + \\beta + \\gamma + \\delta + \\epsilon$")
    ("greek-upper"        "$\\Gamma\\Delta\\Theta\\Lambda\\Psi\\Omega$")
    ("mathrm-mathcal"     "$\\mathrm{d}x \\quad \\mathcal{L}$")
    ("text-in-math"       "$x = 0 \\quad \\text{if and only if}$")
    ("operatorname-star"  "$\\operatorname*{arg\\,max}_x f(x)$")
    ;; --- formulae from the README and the test suite ---------------------
    ("maxwell"            "$\\nabla \\times \\vec{E} = -\\frac{\\partial \\vec{B}}{\\partial t}$")
    ("derivative"         "$\\frac{d}{dx}\\left(\\int_a^x f(t)\\,dt\\right) = f(x)$")
    ("gaussian"           "$\\int_{-\\infty}^{\\infty} e^{-x^2}\\,dx = \\sqrt{\\pi}$")
    ("standard-deviation" "$\\sigma = \\sqrt{\\frac{1}{n}\\sum_{i=1}^{n}(x_i-\\mu)^2}$")
    ("binomial-sum"       "$\\sum_{k=0}^{n}\\binom{n}{k}\\alpha^k\\beta^{n-k}$")))

(defparameter *compare-dir*
  (merge-pathnames "gallery-compare/"
                   (make-pathname :directory (pathname-directory *load-truename*))))

(defparameter *card-width* 720)
(defparameter *latex-column-x* 190)
(defparameter *star-column-x* 460)

(defun compare-pt (sp) (/ sp 65536.0))

(defun compare-latex-source (formula)
  "FORMULA as the external `latex' should see it: display style, to match
latex*'s default. The case list carries the $...$ delimiters."
  (if (and (> (length formula) 1)
           (char= (char formula 0) #\$)
           (char= (char formula (1- (length formula))) #\$))
      (concatenate 'string "$\\displaystyle " (subseq formula 1))
      (concatenate 'string "$\\displaystyle " formula "$")))

;;; --- the reference geometry, straight from a real LaTeX run ---------------

(defun compare-latex-box (formula)
  "Measure FORMULA with real LaTeX in display style: (width height depth) in sp,
or NIL when the toolchain is missing or the run fails."
  (let* ((dir (uiop:ensure-directory-pathname
               (merge-pathnames "svg-latex-compare/" (uiop:temporary-directory))))
         (tex (merge-pathnames "measure.tex" dir))
         (log (merge-pathnames "measure.log" dir))
         ;; the case list carries the $...$ delimiters; measure the same math
         ;; in display style, which is what latex* does by default
         (body (if (and (> (length formula) 1)
                        (char= (char formula 0) #\$)
                        (char= (char formula (1- (length formula))) #\$))
                   (subseq formula 1 (1- (length formula)))
                   formula)))
    (ensure-directories-exist tex)
    (with-open-file (s tex :direction :output :if-exists :supersede
                           :if-does-not-exist :create)
      (format s "\\documentclass[preview]{standalone}~%")
      (dolist (package *latex-packages*) (format s "\\usepackage{~a}~%" package))
      (format s "\\begin{document}~%")
      (format s "\\setbox0=\\hbox{$\\displaystyle ~a$}~%" body)
      (format s "\\typeout{SVGBOX|\\number\\wd0|\\number\\ht0|\\number\\dp0|}~%")
      (format s "\\end{document}~%"))
    (handler-case
        (progn
          (uiop:run-program (list "latex" "-interaction=nonstopmode" "measure.tex")
                            :directory dir :ignore-error-status t
                            :output nil :error-output nil)
          (when (probe-file log)
            (ppcre:register-groups-bind (w h d)
                ("SVGBOX\\|(-?\\d+)\\|(-?\\d+)\\|(-?\\d+)\\|"
                 (uiop:read-file-string log))
              (list (parse-integer w) (parse-integer h) (parse-integer d)))))
      (error () nil))))

;;; --- one card per formula -------------------------------------------------

(defun compare-card (path name formula)
  "Write a card with both renderings of FORMULA on a shared baseline.
Returns (values box-in-pt latex-box-in-sp); the latter is NIL when the TeX
toolchain is unavailable.

Both columns are typeset in *display* style -- latex*'s default. The external
`latex' would otherwise take the bare $...$ of the source string as inline math,
where a nested radical or a fraction comes out smaller, and the two columns
would not be comparable at all."
  (let* ((box (latex-typeset formula))
         (w (compare-pt (svg-tex:n-width box)))
         (h (compare-pt (svg-tex:n-height box)))
         (d (compare-pt (svg-tex:n-depth box)))
         (tex (compare-latex-box formula))
         (top 22)                       ; room for the column captions
         (base (+ top h))
         (height (+ base d 26)))
    (with-svg (path *card-width* height)
      (rect (p 0 0) *card-width* height :fill "white")
      (text (p 8 15) name :font-size 10 :fill "#555")
      (text (p (- *latex-column-x* 8) 15) "latex (dvisvgm)"
            :font-size 10 :fill "#c62828")
      (text (p (- *star-column-x* 8) 15) "latex* (native)"
            :font-size 10 :fill "#1976d2")
      ;; a baseline guide across both columns: an accent that sits too high or
      ;; a script that hangs too low shows up as a shift against this line
      (line (p (- *latex-column-x* 10) base) (p (- *card-width* 10) base)
            :stroke "#e8e8e8" :stroke-width 1)
      (latex (p *latex-column-x* base) (compare-latex-source formula))
      (latex* (p *star-column-x* base) formula)
      (text (p 8 (+ base d 18)) (str:concat "$" formula "$")
            :font-size 10 :fill "#999"))
    (values (list w h d) tex)))

(defun compare-geometry-matches-p (ours tex)
  "Whether our box (pt) agrees with a LaTeX box (sp) to within a rounding unit."
  (and tex
       (every #'identity
              (mapcar (lambda (a b) (< (abs (- a (compare-pt b))) 0.001))
                      ours tex))))

;;; --- index ----------------------------------------------------------------

(defun compare-index (written)
  "HTML page listing every card, in the style of the sibling's gallery."
  (with-output-to-string (s)
    (format s "<!DOCTYPE html>~%<html><head><meta charset=\"utf-8\">~%")
    (format s "<title>latex vs latex* gallery</title>~%")
    (format s "<style>~%")
    (format s "body{font-family:system-ui,sans-serif;margin:2em;background:#fafafa}~%")
    (format s "h1{font-size:1.4em}p.lead{color:#555}~%")
    (format s ".card{background:#fff;border:1px solid #ddd;border-radius:6px;padding:0.8em 1em;margin:0 0 1em}~%")
    (format s ".card h3{font-size:0.95em;margin:0 0 0.3em;font-family:monospace}~%")
    (format s ".card .box{font-size:0.75em;color:#888;font-family:monospace}~%")
    (format s ".card img{max-width:100%;height:auto;display:block}~%")
    (format s ".ok{color:#2e7d32}.bad{color:#c62828}~%")
    (format s "</style></head><body>~%")
    (format s "<h1><code>latex</code> (dvisvgm) vs <code>latex*</code> (native)</h1>~%")
    (format s "<p class=\"lead\">~D formulas, one card each: the same source string typeset by the external pipeline and by the in-process TeX engine, both in display style, on a shared baseline (the light grey line). Below each card the two box geometries, measured in pt.</p>~%"
            (length written))
    (dolist (entry (reverse written))
      (destructuring-bind (name formula ours tex match) entry
        (format s "<div class=\"card\"><h3>~A</h3>~%" name)
        (format s "<img src=\"~A.svg\" alt=\"~A\">~%" name name)
        (format s "<div class=\"box\">latex* ~,3f ~,3f ~,3f&nbsp;&nbsp;|&nbsp;&nbsp;latex ~A~A</div>~%"
                (first ours) (second ours) (third ours)
                (if tex
                    (format nil "~,3f ~,3f ~,3f"
                            (compare-pt (first tex)) (compare-pt (second tex))
                            (compare-pt (third tex)))
                    "not measured (no TeX toolchain)")
                (if match " <span class=\"ok\">geometry matches</span>"
                    (if tex " <span class=\"bad\">geometry differs</span>" "")))
        (format s "</div>~%")))
    (format s "</body></html>~%")))

(defun compare-write-file (path string)
  (ensure-directories-exist path)
  (with-open-file (out path :direction :output :if-exists :supersede
                            :if-does-not-exist :create :external-format :utf-8)
    (write-string string out)))

(defun test-latex-compare ()
  (format t "~%=== latex vs latex* gallery ===~%")
  (ensure-directories-exist (merge-pathnames "index.html" *compare-dir*))
  (let ((written nil) (fail 0) (mismatch 0) (measured 0))
    (dolist (entry *compare-cases*)
      (destructuring-bind (name formula) entry
        (handler-case
            (multiple-value-bind (ours tex)
                (compare-card (merge-pathnames (str:concat name ".svg") *compare-dir*)
                              name formula)
              (let ((match (compare-geometry-matches-p ours tex)))
                (push (list name formula ours tex match) written)
                (when tex
                  (incf measured)
                  (unless match
                    (incf mismatch)
                    (format t "GEOMETRY ~14a latex* ~{~,3f~^ ~}  latex ~{~,3f~^ ~}~%"
                            name ours (mapcar #'compare-pt tex))))))
          (error (e)
            (incf fail)
            (format t "FAIL ~a~%     ~a~%" name e)))))
    (when written
      (compare-write-file (merge-pathnames "index.html" *compare-dir*)
                          (compare-index written)))
    (format t "~%~D cards, ~D rendered~@[, ~D geometry mismatch~]~@[ -- ~D failed~]~%"
            (length *compare-cases*) (length written) (and (plusp mismatch) mismatch)
            (and (plusp fail) fail))
    (format t "Gallery: ~a~%" *compare-dir*)
    (when (plusp fail) (error "latex vs latex* gallery failed"))))

(test-latex-compare)
