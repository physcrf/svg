;;;; test-latex-star.lisp --- native LaTeX math rendering (no external TeX)
;;;;
;;;; Load with:  sbcl --non-interactive --load test/test-latex-star.lisp
;;;;
;;;; Two things are checked:
;;;;   1. geometry: the TeX box each formula compiles to must match the
;;;;      (width height depth) real LaTeX produces for \hbox{$\displaystyle
;;;;      ...$}. The pinned numbers below were measured from a TeX Live run;
;;;;      they are the same values the geometry was validated against.
;;;;   2. SVG: every formula renders to well-formed markup at a sensible size.
;;;; The end-to-end gallery is written to test/test-latex-star.svg.

(ql:quickload :svg :silent t)

(in-package #:svg)

(defparameter *latex-star-cases*
  ;; formula, width, height, depth in pt (measured with real LaTeX)
  '(("$E = mc^2$"                                      38.88536 8.64003 0.0)
    ("$\\int_0^\\infty e^{-x^2} dx = \\frac{\\sqrt{\\pi}}{2}$"
                                                        81.02849 14.76779 9.11122)
    ("$\\sum_{i=1}^{n} x_i^2$"                         26.31250 16.51393 12.79865)
    ("$\\alpha, \\beta, \\gamma, \\delta$"             36.50705 6.94444 1.94444)
    ("$\\alpha+\\beta+\\gamma+\\delta+\\epsilon$"      76.12140 6.94444 1.94444)
    ("$\\nabla \\times \\vec{E} = -\\frac{\\partial \\vec{B}}{\\partial t}$"
                                                        65.97621 16.43729 6.85951)
    ("$\\frac{1}{1+\\frac{1}{x}}$"                     26.55687 13.20952 10.79677)
    ("$\\sqrt{x^2 + y^2} = r$"                         60.29387 10.06598 2.33410)
    ("$\\lim_{x\\to 0}\\frac{\\sin x}{x}=1$"           58.55266 13.44366 7.17776)
    ("$x \\leq y \\geq z \\neq w \\in S \\subset T$"   102.99138 6.94444 1.94444)
    ("$\\left(\\frac{a}{b}\\right)$"                   19.63034 11.50008 6.85951)
    ("$\\left[\\frac{a}{b}\\right]$"                   17.13034 11.50008 6.85951)
    ("$\\binom{n}{k}$"                                 20.72464 14.50010 9.50012)
    ("$\\overline{x+y}$"                               23.19900 7.83322 1.94444)
    ("$\\mathrm{d}x$"                                  11.27084 6.94444 0.0)
    ("$\\operatorname{sin}(x)$"                        25.77087 7.50000 2.50000)
    ("$\\gcd(a,b)$"                                    36.79979 7.50000 2.50000)
    ("$\\langle x, y \\rangle$"                        23.19908 7.50000 2.50000)
    ("$\\pi r^2$"                                      15.33455 8.64003 0.0)
    ("$\\left(\\sum_{i=1}^{n} i\\right)$"              35.38960 17.50014 12.79865)
    ("$\\frac{d}{dx}\\left(\\int_a^x f(t)\\,dt\\right) = f(x)$"
                                                       107.05275 14.50010 9.50012)
    ;; the wide accents step through cmex10's NEXTLARGER chain (98 -> 99 -> 100
    ;; for \widehat, 101 -> 102 -> 103 for \widetilde), so these pin one
    ;; formula per variant plus a stretched tilde with depth
    ("$\\widehat{H}$"          9.12405 9.75000 0.0)
    ("$\\widehat{abc}$"       13.90511 10.13890 0.0)
    ("$\\widetilde{abc}$"     13.90511 10.13890 0.0)
    ("$\\widetilde{xyz}$"     16.06693  7.50000 1.94444)
    ;; \text{...} is text mode: spaces count (6mu, cmr10's fontdimen 2) and the
    ;; text font's italic corrections are suppressed
    ("$\\text{a b}$"          13.88843  6.94444 0.0)
    ("$\\text{if and only if}$"
                              56.38904  6.94444 1.94444)
    ;; \operatorname* takes its scripts above/below in display style
    ("$\\operatorname*{arg\\,max}_x f(x)$"
                              55.46484  7.50000 8.94443)
    ;; matrices: per-row \strut, 1em column gap, centered on the math axis
    ("$\\begin{matrix}a&b\\\\c&d\\end{matrix}$"
                              20.49077 14.50002 9.50002)
    ("$\\begin{pmatrix}a&b\\\\c&d\\end{pmatrix}$"
                              35.21280 14.50011 9.50012)
    ("$\\begin{bmatrix}a&b\\\\c&d\\end{bmatrix}$"
                              31.04614 14.50011 9.50012)
    ("$\\begin{vmatrix}a&b\\\\c&d\\end{vmatrix}$"
                              27.15741 14.50011 9.50012)
    ;; delimiters: each family steps through cmex's 12/18/24/30pt designs, and
    ;; the vertical bars are stacked from CM's extenders
    ("$\\left\\|\\frac{a}{b}\\right\\|$"
                              18.79703 11.50009 6.85951)
    ("$\\left\\{\\frac{a}{b}\\right\\}$"
                              21.01926 11.50008 6.85951)
    ("$\\left\\lfloor\\frac{a}{b}\\right\\rfloor$"
                              18.24149 11.50008 6.85951)
    ("$\\left\\langle\\frac{a}{b}\\right\\rangle$"
                              19.90811 11.50008 6.85951)
    ("$\\left|\\begin{matrix}a&b\\\\c&d\\end{matrix}\\right|$"
                              27.15741 14.50012 9.50012)
    ;; \sqrt[n] puts the index in the crook of the radical sign, raised to
    ;; 3/5 of the radicand's height-above-depth plus .135em, and -- as in
    ;; LaTeX -- the index adds no height or depth to the box
    ("$\\sqrt[3]{x+y}$"       32.15749  8.28259 2.11737)
    ("$\\sqrt[3]{\\frac{a}{b}}$"
                              18.31102 15.44382 8.95639)
    ("$\\sqrt[\\beta]{x}$"    15.48103  8.49092 1.90904)
    ("$\\sqrt[n]{x}$"         15.67491  8.49092 1.90904)))

(defun test-latex-star ()
  (format t "~%=== Test native LaTeX (latex*) ===~%")
  (let ((pass 0) (fail 0))
    (dolist (entry *latex-star-cases*)
      (destructuring-bind (formula width height depth) entry
        (let ((box (latex-typeset formula)))
          (flet ((pt (x) (/ x 65536.0)))
            (let ((ok (and (< (abs (- (pt (svg-tex:n-width box)) width)) 0.001)
                           (< (abs (- (pt (svg-tex:n-height box)) height)) 0.001)
                           (< (abs (- (pt (svg-tex:n-depth box)) depth)) 0.001))))
              (if ok (incf pass) (incf fail))
              (format t "~:[FAIL~;ok  ~] ~8,5f ~8,5f ~8,5f   ~a~%"
                      ok (pt (svg-tex:n-width box)) (pt (svg-tex:n-height box))
                      (pt (svg-tex:n-depth box)) formula)))))
      ;; the SVG must render and be non-trivial
      (let ((svg (latex*-svg (first entry))))
        (if (and (> (length svg) 200) (search "</svg>" svg))
            (incf pass) (incf fail))))
    (format t "~%~d passed, ~d failed~%" pass fail)
    (when (plusp fail) (error "latex* geometry tests failed"))))

(defparameter *latex-accent-cases*
  ;; accent, LaTeX command, the preview glyph the SVG must draw for it
  '(("hat"      "hat"      #x2C6)   ; circumflex accent
    ("tilde"    "tilde"    #x2DC)   ; small tilde
    ("bar"      "bar"      #xAF)    ; macron
    ("dot"      "dot"      #x2D9)   ; dot above
    ("ddot"     "ddot"     #xA8)    ; diaeresis
    ("check"    "check"    #x2C7)   ; caron
    ("breve"    "breve"    #x2D8)   ; breve
    ("acute"    "acute"    #xB4)    ; acute accent
    ("grave"    "grave"    #x60)    ; grave accent
    ("mathring" "mathring" #x2DA))  ; ring above
  "Every TeX math accent with the Latin Modern *spacing* glyph that previews it.
TeX's make_math_accent keeps the accent on the base line and relies on the CM
design sitting high in the em box; a combining mark, which is what unicode-math
names each accent by, has zero advance and its ink left of the origin -- meant
to follow a base character -- so a renderer drops it or draws it beside the
formula. See CURATED_UNI in tools/gen-latex-tables.py.")

(defun latex-star-combining-p (char)
  (let ((code (char-code char)))
    (or (<= #x0300 code #x036F)         ; combining diacritical marks
        (<= #x20D0 code #x20FF))))      ; combining marks for symbols

(defun test-latex-star-accents ()
  (format t "~%=== Test native LaTeX accents (latex*) ===~%")
  (let ((pass 0) (fail 0))
    (dolist (entry *latex-accent-cases*)
      (destructuring-bind (name command code) entry
        (let* ((formula (format nil "$\\~a{x}$" command))
               (svg (latex*-svg formula))
               ;; the accent is drawn as a text element holding that one glyph;
               ;; nothing in the SVG may be a combining mark
               (ok (and (search (format nil ">~a</text>" (code-char code)) svg)
                        (not (find-if #'latex-star-combining-p svg)))))
          (if ok (incf pass) (incf fail))
          (format t "~:[FAIL~;ok  ~] ~10a preview ~a~%" ok name (code-char code)))))
    ;; The accents that are not cmr designs are drawn as outlines: \vec is
    ;; cmmi10 126, which Latin Modern keeps as the combining mark U+20D7, and
    ;; the wide accents are cmex10 designs with no matching spacing glyph at
    ;; all. A text preview would be invisible (zero-advance marks) or a stray
    ;; ASCII letter (the raw cmex code), so assert on the outline instead.
    (dolist (case '(("\\vec{x}"        #x1D465)   ; cmmi x
                    ("\\widehat{abc}"  #x1D44E)   ; cmmi a
                    ("\\widetilde{abc}" #x1D44E)))
      (destructuring-bind (body base) case
        (let* ((svg (latex*-svg (format nil "$~a$" body)))
               (ok (and (search "<path" svg)
                        (search (format nil ">~a</text>" (code-char base)) svg)
                        (not (find-if #'latex-star-combining-p svg)))))
          (if ok (incf pass) (incf fail))
          (format t "~:[FAIL~;ok  ~] ~10a drawn as a glyph outline~%" ok body))))
    (format t "~%~d passed, ~d failed~%" pass fail)
    (when (plusp fail) (error "latex* accent tests failed"))))

(defun latex-star-italic-preview-code (letter)
  "The code point the SVG must preview LETTER with, per the Math Alphanumeric
block: a -> U+1D44E, except that U+1D455 is unassigned (the block has a hole
at small h, which Unicode keeps at U+210E, Planck's constant). An arithmetic
mapping leaves h with a code point no font can have a glyph for, so it
previews as nothing at all -- see MATH_ALPHABET_HOLES in
tools/gen-latex-tables.py."
  (if (char= letter #\h)
      #x210E
      (+ #x1D44E (- (char-code letter) (char-code #\a)))))

(defun test-latex-star-italic-letters ()
  "Check the math italic preview alphabet: every letter must draw the Math
Alphanumeric character Unicode gives it, the letters must not collide, and
none may use a code point the block leaves unassigned."
  (format t "~%=== Test native LaTeX italic letter previews (latex*) ===~%")
  (let ((pass 0) (fail 0) (drawn nil) (on-hole nil))
    (loop for i from 0 below 26
          for letter = (code-char (+ 97 i))
          for cp = (latex-star-italic-preview-code letter)
          do (let* ((svg (latex*-svg (format nil "$~a$" letter)))
                    (ok (search (format nil ">~a</text>" (code-char cp)) svg)))
               (if ok (incf pass) (incf fail))
               (push cp drawn)
               (when (= cp #x1D455) (push letter on-hole))
               (format t "~:[FAIL~;ok  ~] ~10a preview U+~4,'0X ~a~%"
                       ok letter cp (code-char cp))))
    (let ((distinct (= 26 (length (remove-duplicates drawn)))))
      (if distinct (incf pass) (incf fail))
      (format t "~:[FAIL~;ok  ~] ~10a ~d distinct previews~%"
              distinct "alphabet" (length (remove-duplicates drawn))))
    (if (null on-hole) (incf pass) (incf fail))
    (format t "~:[FAIL~;ok  ~] ~10a never uses the unassigned U+1D455~%"
            (null on-hole) "alphabet")
    (format t "~%~d passed, ~d failed~%" pass fail)
    (when (plusp fail) (error "latex* italic letter tests failed"))))

(defun test-latex-star-symbol-glyphs ()
  "Every symbol slot the LaTeX tables can typeset must draw something real:
either an outline the renderer has a path for, or a preview with a Unicode
mapping. A symbol-font slot with neither draws its raw font code instead --
that is how \\oint came out as the letter I, and \\lfloor as an unscaled 10pt
glyph inside an 18pt fence. (Family 0 is cmr, whose slots *are* their Unicode
codes, so it needs no entry.)

The two hook strokes \\lhook/\\rhook are the known exception: Latin Modern Math
ships only the whole arrows that use them (U+21A9/U+21AA and their pieces), so
there is no glyph to point the slots at; they still preview as their raw codes
(\",\" for \\lhook), which shows in \\hookrightarrow. Fixing them means drawing
cmex/cmmi's own hook outlines."
  (format t "~%=== Test native LaTeX symbol glyph coverage (latex*) ===~%")
  (let ((fonts (latex-math-fonts)) (pass 0) (fail 0) (known 0) (seen nil)
        ;; family . code -> why it is still missing
        (documented-gaps '(((1 . 44) . "\\lhook: no Latin Modern hook glyph")
                           ((1 . 45) . "\\rhook: no Latin Modern hook glyph"))))
    (loop for (name class family code) in *latex-symbols*
          when (member family '(1 2 3))
            do (unless (member (cons family code) seen :test #'equal)
                 (push (cons family code) seen)
                 (let* ((font (svg-tex:math-font-for fonts family 0))
                        (outline (svg-tex::cm-glyph-name font code))
                        (path (and outline
                                   (assoc outline svg-tex::*math-glyph-paths*
                                          :test #'string=)))
                        (preview (case family
                                   (1 (cdr (assoc code svg-tex::*cmmi-glyph-unicode*)))
                                   (2 (cdr (assoc code svg-tex::*cmsy-glyph-unicode*)))
                                   (3 (cdr (assoc code svg-tex::*cmex-glyph-unicode*)))))
                        (ok (and (or path preview)
                                 (or (null outline) path))))
                   (cond (ok (incf pass))
                         ((assoc (cons family code) documented-gaps :test #'equal)
                          (incf known)
                          (format t "known gap ~10a family ~d code ~3d -> ~a~%" name family code
                                  (cdr (assoc (cons family code) documented-gaps :test #'equal))))
                         (t
                          (incf fail)
                          (format t "FAIL ~10a family ~d code ~3d -> ~a~%" name family code
                                  (or (and outline (format nil "outline ~a has no path" outline))
                                      "no outline and no preview mapping")))))))
    (format t "~%~d passed, ~d failed (~d symbol slots, ~d documented gap~:p)~%"
            pass fail (length seen) known)
    (when (plusp fail) (error "latex* symbol glyph coverage failed"))))

(defparameter *latex-star-script-holes*
  ;; capitals with no Mathematical Script codepoint, which Unicode keeps in
  ;; Letterlike Symbols: B E F H I L M R
  '((1 . #x212C) (4 . #x2130) (5 . #x2131) (7 . #x210B)
    (8 . #x2110) (11 . #x2112) (12 . #x2133) (17 . #x211B)))

(defun latex-star-script-preview-code (letter)
  "The code point the SVG must preview LETTER with inside \\mathcal, per the
Math Alphanumeric block: A -> U+1D49C, but the block leaves holes at the
capitals above (e.g. U+1D4A7 -> ℒ U+2112). See MATH_ALPHABET_HOLES in
tools/gen-latex-tables.py."
  (let ((index (- (char-code letter) (char-code #\A))))
    (or (cdr (assoc index *latex-star-script-holes*)) (+ #x1D49C index))))

(defun test-latex-star-script-letters ()
  "Check \\mathcal's alphabet the way TEST-LATEX-STAR-ITALIC-LETTERS checks the
math italic one. latex.ltx declares \\mathcal rather than listing it in
fontmath.ltx's symbol tables, so nothing derived from those tables reached
cmsy10's 26 calligraphic capitals -- \\mathcal{L} previewed as its raw font
code, a plain upright \"L\"."
  (format t "~%=== Test native LaTeX script alphabet previews (latex*) ===~%")
  (let ((pass 0) (fail 0) (drawn nil))
    (loop for i from 0 below 26
          for letter = (code-char (+ 65 i))
          for cp = (latex-star-script-preview-code letter)
          do (let* ((svg (latex*-svg (format nil "$\\mathcal{~a}$" letter)))
                    (ok (search (format nil ">~a</text>" (code-char cp)) svg)))
               (if ok (incf pass) (incf fail))
               (push cp drawn)
               (format t "~:[FAIL~;ok  ~] ~10a preview U+~4,'0X ~a~%"
                       ok letter cp (code-char cp))))
    (let ((distinct (= 26 (length (remove-duplicates drawn)))))
      (if distinct (incf pass) (incf fail))
      (format t "~:[FAIL~;ok  ~] ~10a ~d distinct previews~%"
              distinct "alphabet" (length (remove-duplicates drawn))))
    (format t "~%~d passed, ~d failed~%" pass fail)
    (when (plusp fail) (error "latex* script alphabet tests failed"))))

(defun render-latex-star-gallery (filename)
  ;; one 26pt row per case plus top and bottom margins; the canvas has to grow
  ;; with the case list or the tail of the gallery falls outside the viewport.
  (let ((width 540)
        (height (+ 52 (* 26 (length *latex-star-cases*)))))
    (with-svg (filename width height)
      (rect (p 0 0) width height :fill "white")
      (loop for entry in *latex-star-cases*
            for i from 0
            do (latex* (p 24 (+ 26 (* i 26))) (first entry) :scale 0.5))))
  (format t "Output: ~a~%" filename))

(test-latex-star)
(test-latex-star-accents)
(test-latex-star-italic-letters)
(test-latex-star-script-letters)
(test-latex-star-symbol-glyphs)
(render-latex-star-gallery "test/test-latex-star.svg")
