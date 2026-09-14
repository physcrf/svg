;;;; render.lisp — SVG / text rendering of TeX boxes
;;;;
;;;; Walks the hlist/vlist node lists produced by mlist_to_hlist and emits SVG.
;;;; Geometry comes straight from the TeX boxes (width/height/depth/
;;;; shift_amount + the box's glue setting), so no extra bookkeeping is needed.
;;;;
;;;; Coordinate convention: box coordinates are in sp (1pt = 65536 sp), y grows
;;;; UP. SVG coordinates are pt (sp*scale), y grows DOWN.

(in-package :svg-tex)

(defstruct (svg-ctx (:conc-name svg-))
  (out nil)
  (scale 1/65536 :type ratio)
  (fonts nil))

(defun sp->pt (ctx sp) (* sp (svg-scale ctx)))

(defun xml-escape (s)
  (with-output-to-string (o)
    (dotimes (i (length s))
      (let ((c (char s i)))
        (case c
          (#\< (princ "&lt;" o)) (#\> (princ "&gt;" o))
          (#\& (princ "&amp;" o)) (#\" (princ "&quot;" o))
          (#\' (princ "&apos;" o))
          (t (when (>= (char-code c) 32) (princ c o))))))))

;;; ---------------------------------------------------------------------------
;;; Glyph preview mapping (CM encoding → visible Unicode)
;;; ---------------------------------------------------------------------------

(defparameter *cmex-glyph-unicode*
  '((80 . 8721) (81 . 8719) (82 . 8747) (83 . 8747) (84 . 8721)
    (85 . 8721) (86 . 8721) (87 . 8721)
    (88 . 8721) (89 . 8719) (90 . 8747) (91 . 8747) (92 . 8721)
    (93 . 8721) (94 . 8721) (95 . 8721)
    (0 . 40) (1 . 41) (16 . 40) (17 . 41) (18 . 40) (19 . 41)
    (40 . 40) (41 . 41)
    (112 . 8730) (113 . 8730) (114 . 8730) (115 . 8730)
    (116 . 8730) (117 . 9474) (118 . 8730)))

(defparameter *cmsy-glyph-unicode*
  '((0 . 8722) (1 . 8901) (2 . 215) (3 . 2217) (4 . 247) (5 . 8900)
    (6 . 177) (7 . 8723) (8 . 8853) (9 . 8854) (10 . 8855) (11 . 8856)
    (12 . 8857) (18 . 8725) (49 . 8734)
    ;; cmsy radical signs (cmsy10 112 = \sqrt; 113–115 are larger variants).
    (112 . 8730) (113 . 8730) (114 . 8730) (115 . 8730)))

(defparameter *cmmi-glyph-unicode*
  (append
   ;; Latin capitals A-Z -> MATHEMATICAL ITALIC CAPITAL (U+1D434..)
   (loop for i from 0 below 26 collect (cons (+ 65 i) (+ #x1D434 i)))
   ;; Latin small a-z -> MATHEMATICAL ITALIC SMALL (U+1D44E..)
   (loop for i from 0 below 26 collect (cons (+ 97 i) (+ #x1D44E i)))
   ;; cmmi10 Greek capitals (slots 0-10) -> MATH ITALIC CAPITAL GREEK
   '((0 . #x1D6E4) (1 . #x1D6E5) (2 . #x1D6E9) (3 . #x1D6EB) (4 . #x1D6EC)
     (5 . #x1D6EF) (6 . #x1D6F1) (7 . #x1D6F3) (8 . #x1D6F7) (9 . #x1D6F9)
     (10 . #x1D6FA))
   ;; cmmi10 Greek small (slots 11-33) -> MATH ITALIC SMALL GREEK (no omicron)
   '((11 . #x1D6FC) (12 . #x1D6FD) (13 . #x1D6FE) (14 . #x1D6FF) (15 . #x1D700)
     (16 . #x1D701) (17 . #x1D702) (18 . #x1D703) (19 . #x1D704) (20 . #x1D705)
     (21 . #x1D706) (22 . #x1D707) (23 . #x1D708) (24 . #x1D709) (25 . #x1D70B)
     (26 . #x1D70C) (27 . #x1D70E) (28 . #x1D70F) (29 . #x1D710) (30 . #x1D711)
     (31 . #x1D712) (32 . #x1D713) (33 . #x1D714))
   ;; The cmmi variant letters have no Mathematical Italic codepoint; Unicode
   ;; keeps them in the Greek block (\varsigma is final sigma U+03C2).
   '((34 . #x03F5)   ; \varepsilon (lunate epsilon)
     (35 . #x03D1)   ; \vartheta
     (36 . #x03D6)   ; \varpi
     (37 . #x03F1)   ; \varrho
     (38 . #x03C2)   ; \varsigma
     (39 . #x03C6))  ; \varphi
   ;; cmmi10 ',' is at slot 59
   '((59 . 44)))
  "cmmi (CM math italic) slot -> Unicode. Letters map to the Mathematical
Italic block, which is where Latin Modern Math keeps the slanted math letters
(U+0078 etc. are the upright text letters).")

(defparameter *cmr-glyph-unicode*
  '(;; OT1 slots 0-10: upright uppercase Greek (TeX \Gamma..\Omega live here,
     ;; family 0, not in the math italic font).
     (0 . #x0393) (1 . #x0394) (2 . #x0398) (3 . #x039B) (4 . #x039E)
     (5 . #x03A0) (6 . #x03A3) (7 . #x03A5) (8 . #x03A6) (9 . #x03A8)
     (10 . #x03A9)
     (39 . #x2019) (96 . #x2018) (123 . #x2013) (124 . #x2014)
     ;; OT1 slot 126 is the HIGH tilde that \tilde uses; Unicode puts that
     ;; glyph at U+02DC, whereas U+007E is a low (mid-x-height) tilde.
     (126 . #x02DC))
  "cmr (OT1) code -> Unicode preview glyph for the slots whose Unicode
counterpart is not the same code point.")

(defparameter *lm-glyph-ink*
  '((8721 . (1.0560 -0.25 0.75)) (8719 . (0.9440 -0.25 0.75))
    (8747 . (0.6650 -0.306 0.805)) (40 . (0.3890 -0.248 0.748))
    (41 . (0.3890 -0.248 0.748)) (8730 . (0.8330 -0.96 0.04))
    (9474 . (0.6660 -0.2702 0.7702))))

(defun cm-glyph-code (font code)
  (let ((name (and (typep font 'math-font) (math-font-name font))))
    (cond ((and (equal name "cmex") (cdr (assoc code *cmex-glyph-unicode*))))
          ((and (equal name "cmsy") (cdr (assoc code *cmsy-glyph-unicode*))))
          ((and (equal name "cmmi") (cdr (assoc code *cmmi-glyph-unicode*))))
          ((and (equal name "cmr") (cdr (assoc code *cmr-glyph-unicode*))))
          (t code))))

;;; ---------------------------------------------------------------------------
;;; MATH-table size variants (drawn as outlines — they have no codepoint)
;;; ---------------------------------------------------------------------------
;;; CM's cmex10 and cmsy10 carry several *design* sizes of the big operators,
;;; radicals and delimiters. Latin Modern Math keeps the same designs in
;;; MATH-table variants (summation.v1, radical.v1…, parenleft.v2…) which are
;;; not reachable through Unicode, so we map the CM code to the LM glyph name
;;; and draw its outline (src/glyph-paths.lisp).

(defparameter *cmex-glyph-names*
  ;; delimiters: cmex 0/16/18 = "(" at ~12/18/24pt, 1/17/19 = ")"
  '((0 . "parenleft.v2") (1 . "parenright.v2")
    (16 . "parenleft.v4") (17 . "parenright.v4")
    (18 . "parenleft.v6") (19 . "parenright.v6")
    (80 . "summation") (84 . "summation") (85 . "summation")
    (86 . "summation") (87 . "summation")
    (88 . "summation.v1") (92 . "summation.v1") (93 . "summation.v1")
    (94 . "summation.v1") (95 . "summation.v1")
    (81 . "product") (89 . "product.v1")
    (82 . "integral") (83 . "integral") (90 . "integral.v1") (91 . "integral.v1")
    ;; radicals: 112..115 = 12/18/24/30pt, 116/117/118 = extensible pieces
    (112 . "radical.v1") (113 . "radical.v2")
    (114 . "radical.v3") (115 . "radical.v4")
    (116 . "uni23B7") (117 . "radical.ex") (118 . "radical.tp"))
  "cmex10 code -> Latin Modern Math glyph name.")

(defparameter *cmsy-glyph-names* '((112 . "radical"))
  "cmsy10 code -> Latin Modern Math glyph name.")

(defparameter *extra-glyph-outlines* nil
  "Outline glyphs registered from outside the engine, as
\(FONT-NAME CODE NAME DX DY [FIT [X0 Y0 X1 Y1]]): CM-CODE of the font called
FONT-NAME is drawn as the *MATH-GLYPH-PATHS* outline NAME -- like the two
tables above -- and the outline is shifted by (DX . DY) font units. The tables
above only reach glyphs whose Latin Modern design sits where CM puts it; a
glyph that Latin Modern keeps as a combining mark needs that shift, since its
ink lies left of the origin. With FIT the outline's ink box is instead mapped
onto the CM char box vertically (scaled, not just moved), which is what a
glyph whose Latin Modern design is a different size than CM's needs -- the
vertical-bar extenders, for instance, are 6.42pt in CM but a 12pt design in
Latin Modern. When FIT is followed by CM's own ink box (X0 Y0 X1 Y1, in 1/100
em units, y up) the outline's ink box is mapped onto that box on *both* axes:
Latin Modern's bar repeaters differ from cmex10's pieces in stroke weight and
gap as well as in size, so no single scale puts their ink where CM's is. A
list of such boxes draws the outline once per box, which is how cmex10's
vextenddouble is built -- two copies of vextendsingle's stroke.
The svg front end registers cmmi10 126 (TeX's \\vec arrow) and the bars here.")

(defun extra-glyph-outline (font code)
  "The *EXTRA-GLYPH-OUTLINES* entry for CODE of FONT, or NIL."
  (let ((name (and (typep font 'math-font) (math-font-name font))))
    (and name
         (find-if (lambda (entry)
                    (and (equal (first entry) name) (= (second entry) code)))
                  *extra-glyph-outlines*))))

(defun cm-glyph-name (font code)
  (let ((name (and (typep font 'math-font) (math-font-name font)))
        (extra (extra-glyph-outline font code)))
    (if extra
        (third extra)
        (cond ((equal name "cmex") (cdr (assoc code *cmex-glyph-names*)))
              ((equal name "cmsy") (cdr (assoc code *cmsy-glyph-names*)))
              (t nil)))))

(defun svg-draw-glyph-path (ctx x y font code w h d)
  "Draw the glyph CM-CODE as an outline, mapping its ink box onto the CM char
box (x .. x+w horizontally, -d .. +h vertically). TeX's own shift_amount
(for a hanging cmex design) then places it exactly as in pdftex."
  (let ((entry (assoc (cm-glyph-name font code) *math-glyph-paths*
                      :test #'string=)))
    (when entry
      (destructuring-bind (name adv (gx0 gy0 gx1 gy1) . dstr) entry
        (declare (ignore name))
        (declare (ignore adv w))
        (let* ((scale (svg-scale ctx))
               (extra (extra-glyph-outline font code))
               ;; One font unit = size/1000 sp (natural size, as TeX draws it:
               ;; glyph origin at the box origin). Only the vertical placement
               ;; needs compensating, because CM's cmex/cmex-like symbols are
               ;; "hanging" designs while Latin Modern Math centres them on the
               ;; axis; mapping the ink's bottom onto the box depth restores
               ;; cmex placement, and TeX's own shift_amount then finishes it.
               (unit (/ (float (math-font-size font) 1d0) 1000.0d0))
               ;; FIT: stretch the ink vertically onto the CM piece box, which
               ;; is what the stacked delimiter pieces need -- Latin Modern's
               ;; paren extender is 4.98pt where the box it is stacked in is
               ;; 6pt, so an unfitted fence breaks at every joint. The
               ;; horizontal placement is left alone: the pieces' advances are
               ;; CM's box widths, so the design already puts the ink where
               ;; CM does.
               (fit (and extra (sixth extra)))
               ;; A FIT entry may name CM's own ink box (X0 Y0 X1 Y1, 1/100 em
               ;; units, y up). The design's ink box is then mapped onto it on
               ;; both axes, which is what the bar pieces need: Latin Modern's
               ;; repeaters are a 12pt design whose stroke and gap are a
               ;; different fraction of the height than cmex10's 6.42pt
               ;; pieces, so one scale cannot place their ink where CM does.
               ;; A *list* of boxes draws the outline once per box: cmex10's
               ;; vextenddouble is two copies of vextendsingle's stroke, so
               ;; the interface draws the single-bar outline twice rather
               ;; than stretching Latin Modern's double-bar design over it.
               (ink (and fit (seventh extra)))
               (boxes (if (and ink (consp (first ink))) ink (list ink)))
               (transforms
                 (mapcar
                  (lambda (box)
                    (cond
                      (box
                       (let ((ux (* unit (/ (float (- (third box) (first box)) 1d0)
                                            (max 1 (- gx1 gx0)))))
                             (uy (* unit (/ (float (- (fourth box) (second box)) 1d0)
                                            (max 1 (- gy1 gy0))))))
                         (list ux uy
                               (- (* (first box) unit) (* gx0 ux))
                               (- (* (second box) unit) (* gy0 uy)))))
                      (fit
                       (let ((uy (/ (float (+ h d) 1d0) (max 1 (- gy1 gy0)))))
                         (list unit uy 0 (- (- d) (* gy0 uy)))))
                      ;; A registered glyph instead carries its own shift: its
                      ;; ink is not a hanging design, it is CM's own position
                      ;; in LM units.
                      (extra (list unit unit (* (fourth extra) unit)
                                   (* (fifth extra) unit)))
                      (t (list unit unit 0 (- (- d) (* gy0 unit))))))
                  boxes)))
          (dolist (tr transforms)
            (destructuring-bind (ux uy tx ty) tr
              (format (svg-out ctx)
                      "<g transform=\"translate(~F,~F) scale(~F,~F)\"><path d=\"~A\"/></g>~%"
                      (* (+ x tx) scale)
                      (- (* (+ y ty) scale))
                      (* ux scale)
                      (- (* uy scale))
                      dstr)))
          t)))))

(defun svg-font-name (font)
  "Font family to put in the SVG. For cmr we select the Latin Modern
optical size (10/7/5pt) that matches the TFM the metrics came from: a 7pt
design is NOT cmr10 scaled (widths differ ~0.79 vs 0.70), so drawing cmr7
metrics with lmroman10 at 7pt would be too narrow.

The script sizes carry a fallback list. `LM Roman Seven' / `LM Roman Five'
are the names fontconfig matches on a normal desktop, but they are not
families of the OpenType files (which declare `Latin Modern Roman' and
`LM Roman 7'), so a renderer with a restricted font view -- a snap-confined
browser, say -- resolves neither and silently draws the digits with its
own default serif. Listing `Latin Modern Roman' second keeps the exact 7pt
design where it is reachable and degrades to the 10pt design, still Latin
Modern, where it is not."
  (let ((name (and (typep font 'math-font) (math-font-name font))))
    (cond ((null name) "serif")
          ((search "cmr" name)
           (case (math-font-design-size font)
             (458752 "LM Roman Seven, Latin Modern Roman")  ; cmr7  (script)
             (327680 "LM Roman Five, Latin Modern Roman")   ; cmr5  (scriptscript)
             (t "Latin Modern Roman"))) ; cmr10 (text)
          ((or (search "cmmi" name) (search "cmsy" name) (search "cmex" name))
           ;; LM Math ships a single design; CM's cmmi7/cmsy7 have no LM
           ;; OpenType counterpart, so script math stays scaled.
           "Latin Modern Math")
          (t name))))

(defun cmex-preview-transform (font code w h d)
  "Scale/translate to map Latin Modern's Unicode ink onto the CM metric box."
  (if (not (and (typep font 'math-font) (equal (math-font-name font) "cmex")))
      (values 1 1 0)
      (let* ((uni (cm-glyph-code font code))
             (ink (cdr (assoc uni *lm-glyph-ink*))))
        (if (null ink)
            (values 1 1 0)
            (let* ((f (math-font-size font))
                   (adv (first ink)) (y0 (second ink)) (y1 (third ink))
                   (ic (math-font-char-italic font code))
                   (sx (/ (+ w ic) (* adv f)))
                   (sy (/ (+ h d) (* (- y1 y0) f)))
                   (ty (/ (+ d (* y0 f sy)) 65536)))
              (values sx sy ty))))))

;;; ---------------------------------------------------------------------------
;;; Drawing primitives
;;; ---------------------------------------------------------------------------

(defun optical-stretch-x (ctx font code)
  "CM's 7pt/5pt math fonts are separate optical designs: their advances are
~13-18% wider than cmmi10/cmsy10 scaled down to that size. Latin Modern Math
ships a single design, so we stretch the glyph horizontally to the TFM advance
as an approximation (no effect at text size, and never for cmr, which has real
optical sizes in lmroman7/lmroman5)."
  (let ((name (and (typep font 'math-font) (math-font-name font))))
    (if (and name (member name '("cmmi" "cmsy") :test #'string=)
             (< (math-font-size font) 655360))
        (let ((f10 (math-font-ten-point font)))
          (if f10
              (let ((wbox (math-font-char-width font code))
                    (w10 (math-font-char-width f10 code)))
                (if (plusp w10)
                    (/ (float wbox 1d0)
                       (* w10 (/ (float (math-font-size font) 1d0) 655360.0d0)))
                    1.0d0))
              1.0d0))
        1.0d0)))

(defun svg-draw-char (ctx x y font code w h d)
  (let ((out (svg-out ctx)))
    (if (svg-draw-glyph-path ctx x y font code w h d)
        nil
    (multiple-value-bind (sx sy ty) (cmex-preview-transform font code w h d)
      (setf sx (* sx (optical-stretch-x ctx font code)))
      (let ((px (sp->pt ctx x))
            (py (- (sp->pt ctx y)))
            (text (xml-escape (string (code-char (cm-glyph-code font code)))))
            (fam (svg-font-name font))
            (size (sp->pt ctx (math-font-size font))))
        (flet ((emit ()
                 (format out "<text x=\"~F\" y=\"~F\" font-family=\"~A\" font-size=\"~F\">~A</text>~%"
                         px py fam size text)))
          (cond ((and (= sx 1) (= sy 1) (= ty 0)) (emit))
                (t
                 (format out "<g transform=\"translate(~F,~F) scale(~F,~F)\">~%"
                         px (+ py ty) (coerce sx 'double-float)
                         (coerce sy 'double-float))
                 (format out "<text x=\"0\" y=\"0\" font-family=\"~A\" font-size=\"~F\">~A</text>~%"
                         fam size text)
                 (format out "</g>~%")))))))))

(defun svg-draw-rule (ctx x y width height depth)
  (format (svg-out ctx)
          "<rect x=\"~F\" y=\"~F\" width=\"~F\" height=\"~F\" fill=\"black\"/>~%"
          (sp->pt ctx x)
          (- (sp->pt ctx (+ y height)))
          (sp->pt ctx width)
          (sp->pt ctx (+ height depth))))

;;; ---------------------------------------------------------------------------
;;; Box traversal
;;; ---------------------------------------------------------------------------

(defun rule-width-in (rule box)
  (if (is-running (n-width rule)) (n-width box) (n-width rule)))
(defun rule-height-in (rule box)
  (if (is-running (n-height rule)) (n-height box) (n-height rule)))
(defun rule-depth-in (rule box)
  (if (is-running (n-depth rule)) (n-depth box) (n-depth rule)))

(defun render-hlist (ctx box x y)
  (let ((cx 0))
    (let ((p (n-list box)))
      (loop while p do
        (case (n-type p)
          (:char
           (let ((f (n-font p)) (c (n-character p)))
             (svg-draw-char ctx (+ x cx) y f c
                            (char-width-of f c) (char-height-of f c)
                            (char-depth-of f c))
             (incf cx (char-width-of f c))))
          (:glue
           (incf cx (glue-width-in-box (n-glue p) box)))
          (:kern
           (incf cx (n-width p)))
          (:rule
           (let ((w (rule-width-in p box))
                 (h (rule-height-in p box))
                 (d (rule-depth-in p box)))
             (svg-draw-rule ctx (+ x cx) y w h d)
             (incf cx w)))
          ((:hlist :vlist)
           (render-box ctx p (+ x cx) (- y (n-shift p)))
           (incf cx (n-width p)))
          (t nil))
        (setf p (n-link p))))))

(defun render-vlist (ctx box x y)
  ;; The vlist's reference point is the last child's baseline; walk top-down
  ;; from the top edge (y + height).
  (let ((cursor (+ y (n-height box)))
        (p (n-list box)))
    (loop while p do
      (case (n-type p)
        (:kern (decf cursor (n-width p)))
        (:glue (decf cursor (glue-width-in-box (n-glue p) box)))
        (:rule
         (let ((w (rule-width-in p box))
               (h (rule-height-in p box))
               (d (rule-depth-in p box)))
           (svg-draw-rule ctx (+ x (n-shift p)) (- cursor h) w h d)
           (decf cursor (+ h d))))
        ((:hlist :vlist)
         (let ((baseline (- cursor (n-height p))))
           (render-box ctx p (+ x (n-shift p)) baseline)
           (decf cursor (+ (n-height p) (n-depth p)))))
        (:char
         ;; char nodes never occur in a vlist in TeX; ignore defensively.
         nil)
        (t nil))
      (setf p (n-link p)))))

(defun render-box (ctx box x y)
  (case (n-type box)
    (:hlist (render-hlist ctx box x y))
    (:vlist (render-vlist ctx box x y))
    (t nil)))

;;; ---------------------------------------------------------------------------
;;; Top-level entry points
;;; ---------------------------------------------------------------------------

(defparameter *svg-padding-fraction* 1/25
  "Fraction of a box's total height added as viewBox padding on every side.
Latin Modern's glyph ink overshoots the CM/TFM box by a fraction of a point
(e.g. math-italic letters by ~0.11pt top and bottom), so without padding a
browser clips the outermost pixels.")

(defun render-to-svg (box &key (scale 1/65536) (fonts nil))
  "Render the TeX box BOX to an SVG string."
  (let* ((out (make-string-output-stream))
         (ctx (make-svg-ctx :out out :scale scale :fonts fonts))
         (w (n-width box))
         (h (n-height box))
         (d (n-depth box))
         (pad (max 6554 (round (* (+ h d) *svg-padding-fraction*))))
         (vw (+ w pad pad))
         (vh (+ h d pad pad)))
    (format out "<?xml version=\"1.0\" encoding=\"UTF-8\"?>~%")
    (format out "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"~Fpt\" height=\"~Fpt\" viewBox=\"~F ~F ~F ~F\">~%"
            (sp->pt ctx vw) (sp->pt ctx vh)
            (sp->pt ctx (- pad)) (- (sp->pt ctx (+ h pad)))
            (sp->pt ctx vw) (sp->pt ctx vh))
    (render-box ctx box 0 0)
    (format out "</svg>~%")
    (get-output-stream-string out)))

(defun dump-node (out box x y indent)
  (format out "~v,0T~A at (~A,~A) w=~A h=~A d=~A~%"
          indent (string-upcase (symbol-name (n-type box)))
          x y (n-width box) (n-height box) (n-depth box))
  (when (member (n-type box) '(:hlist :vlist))
    (dump-children out box x y (+ indent 2))))

(defun dump-children (out box x y indent)
  (let ((p (n-list box)))
    (if (eq (n-type box) :hlist)
        (let ((cx 0))
          (loop while p do
            (cond ((char-node-p p)
                   (format out "~v,0TCHAR #\\~A at (~A,~A)~%"
                           indent
                           (code-char (cm-glyph-code (n-font p) (n-character p)))
                           (+ x cx) y)
                   (incf cx (char-width-of (n-font p) (n-character p))))
                  ((eq (n-type p) :rule)
                   (format out "~v,0TRULE at (~A,~A) w=~A h=~A d=~A~%"
                           indent (+ x cx) y (n-width p) (n-height p) (n-depth p))
                   (incf cx (n-width p)))
                  ((eq (n-type p) :glue) (incf cx (glue-width-in-box (n-glue p) box)))
                  ((eq (n-type p) :kern) (incf cx (n-width p)))
                  (t (dump-node out p (+ x cx) (- y (n-shift p)) indent)
                     (incf cx (n-width p))))
            (setf p (n-link p))))
        (let ((cursor (+ y (n-height box))))
          (loop while p do
            (cond ((eq (n-type p) :kern) (decf cursor (n-width p)))
                  ((eq (n-type p) :glue) (decf cursor (glue-width-in-box (n-glue p) box)))
                  (t (dump-node out p x (- cursor (n-height p)) indent)
                     (decf cursor (+ (n-height p) (n-depth p)))))
            (setf p (n-link p)))))))

(defun render-to-string (box &key (fonts nil))
  "Human-readable dump of a TeX box tree (for tests/debugging)."
  (declare (ignore fonts))
  (let ((out (make-string-output-stream)))
    (dump-node out box 0 0 0)
    (get-output-stream-string out)))
