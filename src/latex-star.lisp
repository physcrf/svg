;;;; latex-star.lisp --- native LaTeX math rendering (no external TeX process)
;;;;
;;;; `latex*` typesets a LaTeX math string directly, on top of the vendored
;;;; tex.web port in src/tex/ (package `svg-tex': node model, hpack/vpackage,
;;;; mlist_to_hlist, var_delimiter) instead of shelling out to `latex`/`dvisvgm'.
;;;; That engine is a local copy of the sibling `typesetting' system: the svg
;;;; system has no run-time dependency on it.
;;;;
;;;; The LaTeX front end lives here:
;;;;   1. a small scanner/parser turning LaTeX math syntax into a TeX mlist
;;;;      (noads with the same classes TeX's scanner assigns: ord / op / bin /
;;;;      rel / open / close / punct / inner);
;;;;   2. symbol/accent/delimiter tables generated from LaTeX's fontmath.ltx
;;;;      (see tools/gen-latex-tables.py);
;;;;   3. an additive metric layer: the vendored engine ships only the CM
;;;;      glyphs its own tests exercise, so the remaining slots the LaTeX
;;;;      symbol tables need are filled in from the real TFM data.
;;;;
;;;; Like the external `latex`, a formula is placed with its baseline-left
;;;; origin at POSITION; :SCALE and other transform/attribute keywords behave
;;;; as in `write-raw-element`.

(in-package #:svg)

;;; ---------------------------------------------------------------------------
;;; Extended Computer Modern math fonts
;;; ---------------------------------------------------------------------------

(defvar *latex-math-fonts* nil
  "Cached font vector: the engine's default CM fonts plus the extra slots the
LaTeX symbol tables reference (filled from real TFM metrics).")

(defparameter *latex-mu* 36408
  "1mu in sp at text size (tex.web x_over_n(math_quad(cmr10), 18)).")

(defparameter *latex-cancel-slash-code* 54
  "The cmmi10 slot the \\notin overlay borrows for the text slash.
LATEX-AUGMENT-FONTS gives it cmmi10 61's (\"/\") width and height with no depth:
\\c@ncel is \\ooalign, whose box takes its height from the slash row and its
depth from the *base* row, so the slash's own 2.5pt depth must not reach the
atom (a real latex run's \\notin is 7.5pt high and .391pt deep -- the
extents of ∈). Ink placement is unaffected: the outline carries its own box.")

(defparameter *latex-quad* 655361
  "1em (math quad) in sp at text size.")

(defparameter *cmr-space* '(218454 176584 154740)
  "cmr10/7/5 fontdimen 2 (interword space) in sp. The vendored engine's cmr
fonts carry no :space parameter, but make_ord needs it: an upright letter
mid-word becomes math_text_char and its italic correction is dropped only when
the font's space is nonzero (hence \\gcd, \\mathrm{...}). cmmi/cmsy have
space 0 and must keep their italic corrections.")

(defvar *latex-upright* nil
  "When true the parser typesets bare letters upright (family 0), as inside
\\mathrm / \\text / \\operatorname.")

(defvar *latex-calligraphic* nil
  "When true the parser maps bare letters to the calligraphic alphabet
(cmsy slots `A'..`Z'), as inside \\mathcal.")

(defvar *latex-text-mode* nil
  "When true the parser is inside \\text{...}, which LaTeX typesets in text
mode: a run of spaces becomes one interword space (cmr10's fontdimen 2 is 6mu
at text size, the value *CMR-SPACE* restores for the metric layer), where the
math scanner used everywhere else drops spaces entirely. The width is the text
size one; \\text inside a script is rare and comes out a little narrow.")

(defun latex-install-unicode-map (family)
  "Merge this library's glyph previews for FAMILY into the svg-tex
renderer's CM-code -> Unicode tables. Our table is generated from LaTeX's own
symbol names and accents, so it replaces the engine's placeholder mappings."
  (let ((target (ecase family
                  (0 'svg-tex::*cmr-glyph-unicode*)
                  (1 'svg-tex::*cmmi-glyph-unicode*)
                  (2 'svg-tex::*cmsy-glyph-unicode*)
                  (3 'svg-tex::*cmex-glyph-unicode*))))
    (loop for ((fam . code) . cp) in *latex-glyph-unicode*
          when (= fam family)
            do (let ((entry (assoc code (symbol-value target))))
                 (if entry
                     (setf (cdr entry) cp)
                     (push (cons code cp) (symbol-value target)))))))

(defun latex-augment-fonts (fonts)
  "Add the extra Computer Modern char metrics to FONTS in place."
  (flet ((set-char (font family code w h d ic)
           (declare (ignore family))
           (svg-tex::math-font-set-char font code w h d ic)))
    (loop for (family size code w h d ic) in *cm-extra-chars*
          do (if (= family 3)
                 ;; cmex is a single 10pt design shared by all size codes
                 (loop for sc from 0 below 3
                       for font = (aref fonts (+ 3 (* 4 sc)))
                       when font do (set-char font family code w h d ic))
                 (let ((font (aref fonts (+ family (* 4 size)))))
                   (when font (set-char font family code w h d ic)))))
    ;; Restore each cmr optical size's interword space (fontdimen 2); see
    ;; *CMR-SPACE*. cmmi/cmsy stay at 0.
    (loop for sc from 0 below 3
          for font = (aref fonts (* 4 sc))     ; family 0 = cmr, size code SC
          when font do (svg-tex:set-math-font-param font :space (nth sc *cmr-space*)))
    ;; The \notin overlay's borrowed slash slot: cmmi10 61's width and height
    ;; ("/") with no depth -- see *LATEX-CANCEL-SLASH-CODE*.
    (loop for sc from 0 below 3
          for font = (aref fonts (+ 1 (* 4 sc)))     ; family 1 = cmmi
          when font do (set-char font 1 *latex-cancel-slash-code*
                                 (svg-tex:math-font-char-width font 61)
                                 (svg-tex:math-font-char-height font 61)
                                 0 0))
    (let ((cmex-fonts (loop for sc from 0 below 3
                            collect (aref fonts (+ 3 (* 4 sc))))))
      (dolist (font cmex-fonts)
        (when font
          (loop for (family code next) in *cm-extra-larger*
                do (svg-tex::math-font-set-larger-variant font code next))
          (loop for (family code top mid bot rep) in *cm-extra-extensible*
                do (svg-tex::math-font-set-extensible-parts
                    font code top mid bot rep))))))
  fonts)

(defun latex-math-fonts ()
  "Return the cached, augmented math-font vector."
  (unless *latex-math-fonts*
    (dolist (family '(0 1 2 3)) (latex-install-unicode-map family))
    (setf *latex-math-fonts* (latex-augment-fonts (svg-tex:make-default-fonts))))
  *latex-math-fonts*)

;;; ---------------------------------------------------------------------------
;;; Preview glyphs no Unicode table can reach
;;; ---------------------------------------------------------------------------

(defparameter *latex-vec-arrow-path*
  (list* "uni20D7" 0 '(-472 521 -56 711)
         "M-56 616C-56 623 -61 628 -67 630C-103 642 -132 668 -148 702C-150 707 -155 711 -161 711C-170 711 -176 704 -176 696C-176 694 -176 692 -175 690C-165 667 -149 647 -130 631H-457C-465 631 -472 624 -472 616C-472 608 -465 601 -457 601H-130C-149 585 -165 565 -175 542C-176 540 -176 538 -176 536C-176 528 -170 521 -161 521C-155 521 -150 525 -148 530C-132 564 -103 590 -67 602C-61 604 -56 609 -56 616Z")
  "Latin Modern Math's `uni20D7' outline (upm 1000, y up): the right arrow
above. TeX's \\vec accent is cmmi10 slot 126, and Latin Modern keeps that same
design as the combining mark U+20D7.")

(defparameter *latex-wide-accent-paths*
  '(;; \\widehat is cmex10 char 98, and <Switch to a larger accent if available
    ;; and appropriate> walks its NEXTLARGER chain (98 -> 99 -> 100) up to the
    ;; widest variant that still fits the accentee; \\widetilde walks 101 -> 102
    ;; -> 103. Those are cmex designs, and Latin Modern Math has no matching
    ;; *spacing* glyph for them (its tied accents are the unicode-math
    ;; circumflexcmb.h1.. / tildecomb.h1.. chains, which use other widths), so
    ;; the outlines here are Computer Modern's own, taken from cmex10.pfb --
    ;; the very font dvisvgm outlines, so `latex' and `latex*' agree.
    ("cmhatwide"     556 (-5 562 561 744) . "M277 685 549 562 561 584 278 744 -5 584 6 562Z")
    ("cmhatwider"    1000 (-4 575 1003 772) . "M499 713 995 575 1003 599 500 772 -4 599 4 575Z")
    ("cmhatwidest"   1444 (-3 575 1446 772) . "M1440 575 1446 599 721 772 -3 599 3 575 722 713Z")
    ("cmtildewide"   556 (0 608 555 722) . "M541 722C492 681 439 651 388 651C348 651 319 668 284 688C255 705 224 722 184 722C159 722 133 714 111 704C91 694 71 683 54 669L0 625L14 608C63 649 116 679 167 679C207 679 236 662 271 642C300 625 331 608 371 608C396 608 422 616 444 626C464 636 484 647 501 661L555 705Z")
    ("cmtildewider"  1000 (0 624 999 750) . "M989 750C962 736 816 662 689 662C616 662 572 680 503 710C455 730 406 750 337 750C220 750 104 694 0 644L10 624C37 638 183 712 310 712C383 712 427 694 496 664C544 644 593 624 662 624C779 624 895 680 999 730Z")
    ("cmtildewidest" 1444 (0 623 1443 750) . "M1436 750C1315 711 1147 657 985 657C880 657 798 684 791 686L690 719C658 730 581 750 490 750C361 750 210 712 102 677L0 644L7 623C128 662 296 716 458 716C563 716 645 689 652 687L753 654C785 643 862 623 953 623C1082 623 1233 661 1341 696L1443 729Z"))
  "Computer Modern outlines for the cmex10 wide accents (upm 1000, y up).")

(defparameter *latex-bar-piece-paths*
  '(;; Latin Modern Math's vertical-bar repeaters (upm 1000, y up); see the
    ;; :fit entries in *LATEX-EXTRA-GLYPH-OUTLINES*. Only the single stroke is
    ;; needed: CM's double bar is two of them, so cmex 13 draws it twice
    ;; rather than stretching Latin Modern's own (thicker, tighter) double-bar
    ;; design across the two strokes.
    ("divides.ex" 0 (100 0 179 1202) . "M179 0 178 1202H100V0Z"))
  "Latin Modern outlines for the vertical-bar delimiter pieces.")

(defparameter *latex-extra-cmex-glyph-names*
  '(;; cmex10's big delimiters come in 12/18/24/30pt designs, and Latin Modern
    ;; Math keeps the same designs as the .v2/.v4/.v6/.v7 variants (their ink
    ;; extents are 1200/1800/2400/3000 units, matching the CM designs to a
    ;; unit). The vendored engine maps only the parenthesised chains, so
    ;; \left[ ... \right] or a delimited matrix used to fall back on a 10pt
    ;; text glyph -- which is what made pmatrix/bmatrix look misplaced.
    (2 . "bracketleft.v2")   (3 . "bracketright.v2")
    (104 . "bracketleft.v4") (105 . "bracketright.v4")
    (20 . "bracketleft.v6")  (21 . "bracketright.v6")
    (34 . "bracketleft.v7")  (35 . "bracketright.v7")
    (4 . "uni2308.v2")   (5 . "uni2309.v2")
    (106 . "uni2308.v4") (107 . "uni2309.v4")
    (22 . "uni2308.v6")  (23 . "uni2309.v6")
    (36 . "uni2308.v7")  (37 . "uni2309.v7")
    (6 . "uni230A.v2")   (7 . "uni230B.v2")
    (108 . "uni230A.v4") (109 . "uni230B.v4")
    (24 . "uni230A.v6")  (25 . "uni230B.v6")
    (38 . "uni230A.v7")  (39 . "uni230B.v7")
    (8 . "braceleft.v2")   (9 . "braceright.v2")
    (110 . "braceleft.v4") (111 . "braceright.v4")
    (26 . "braceleft.v6")  (27 . "braceright.v6")
    (40 . "braceleft.v7")  (41 . "braceright.v7")
    (10 . "uni27E8.v2")  (11 . "uni27E9.v2")
    (68 . "uni27E8.v4")  (69 . "uni27E9.v4")
    (28 . "uni27E8.v6")  (29 . "uni27E9.v6")
    (42 . "uni27E8.v7")  (43 . "uni27E9.v7")
    ;; cmex10's contour integral, text size (72) and display size (73): the
    ;; engine's table stops at 82/90 (\int) and 83/91, so \oint -- whose
    ;; \delcode is 72, upgraded to 73 in display style -- had no outline and
    ;; previewed as its raw font slot, the letter "I".
    (72 . "contourintegral") (73 . "contourintegral.v1")
    (32 . "parenleft.v7") (33 . "parenright.v7")
    ;; the extensible recipes stack these pieces; Latin Modern names them by
    ;; their Unicode bracket pieces (top / extension / bottom / middle)
    (48 . "uni239B") (49 . "uni239E")   ; paren top
    (64 . "uni239D") (65 . "uni23A0")   ; paren bottom
    (66 . "uni239C") (67 . "uni239F")   ; paren extension
    (50 . "uni23A1") (51 . "uni23A4")   ; bracket top
    (52 . "uni23A3") (53 . "uni23A6")   ; bracket bottom
    (54 . "uni23A2") (55 . "uni23A5")   ; bracket extension
    (56 . "uni23A7") (57 . "uni23AB")   ; brace top
    (58 . "uni23A9") (59 . "uni23AD")   ; brace bottom
    (60 . "uni23A8") (61 . "uni23AC")   ; brace middle
    (62 . "braceleft.ex") (63 . "braceleft.ex"))  ; brace extender (shared)
  "cmex10 delimiter code -> Latin Modern Math glyph name, for the chains the
vendored SVG-TEX::*CMEX-GLYPH-NAMES* does not cover.")

(defparameter *latex-extra-glyph-outlines*
  '(("cmmi" 126 "uni20D7" 654 -5)
    ;; The vertical-bar delimiters are built by stacking CM's 6.42pt
    ;; vextendsingle/vextenddouble extenders; Latin Modern's repeaters are
    ;; 12pt designs, so they are fitted onto CM's own ink box (:fit plus the
    ;; X0 Y0 X1 Y1 box). That box is cmex10.pfb's, measured off the outlines
    ;; dvisvgm draws -- 1/100 em units, y up -- so the stacked pieces land
    ;; where CM puts them: an unmapped 12pt repeater is both too wide (79
    ;; units of stroke against CM's 42.8) and inset wrongly, which showed up
    ;; as bar-delimited matrices looking shifted inside their fences.
    ;; CM's vextenddouble is exactly vextendsingle's stroke drawn twice (the
    ;; two strokes are 2.2117pt apart at 10pt), so its entry reuses the single
    ;; stroke's outline with one box per stroke. The box is y-up, so CM's
    ;; stroke hangs from 618.68 units above the piece's origin to 20.92 below
    ;; it -- the reverse of dvisvgm's own y-down outline coordinates.
    ("cmex" 12 "divides.ex" 144.4583 -20.9215 :fit
     (144.4583 -618.68 187.2976 20.9215))
    ("cmex" 13 "divides.ex" 144.4583 -20.9215 :fit
     ((144.4583 -618.68 187.2976 20.9215)
      (365.6289 -618.68 408.4682 20.9215)))
    ;; The pieces the other delimiters (and the radical) are assembled from.
    ;; tex.web stacks them by their CM box, but Latin Modern's Unicode bracket
    ;; pieces are drawn to their own sizes -- its paren extender is 4.98pt
    ;; tall where the box is 6pt, its brace extender 7.48pt where the box is
    ;; 3pt -- so unfitted pieces leave a seam (or a doubled stroke) at every
    ;; joint. :fit stretches each piece's ink onto its CM box; the horizontal
    ;; position needs no help, as the pieces' advances are CM's box widths.
    ("cmex" 48 "uni239B" 0 0 :fit) ("cmex" 49 "uni239E" 0 0 :fit)
    ("cmex" 64 "uni239D" 0 0 :fit) ("cmex" 65 "uni23A0" 0 0 :fit)
    ("cmex" 66 "uni239C" 0 0 :fit) ("cmex" 67 "uni239F" 0 0 :fit)
    ("cmex" 50 "uni23A1" 0 0 :fit) ("cmex" 51 "uni23A4" 0 0 :fit)
    ("cmex" 52 "uni23A3" 0 0 :fit) ("cmex" 53 "uni23A6" 0 0 :fit)
    ("cmex" 54 "uni23A2" 0 0 :fit) ("cmex" 55 "uni23A5" 0 0 :fit)
    ("cmex" 56 "uni23A7" 0 0 :fit) ("cmex" 57 "uni23AB" 0 0 :fit)
    ("cmex" 58 "uni23A9" 0 0 :fit) ("cmex" 59 "uni23AD" 0 0 :fit)
    ("cmex" 60 "uni23A8" 0 0 :fit) ("cmex" 61 "uni23AC" 0 0 :fit)
    ("cmex" 62 "braceleft.ex" 0 0 :fit) ("cmex" 63 "braceleft.ex" 0 0 :fit)
    ;; The radical's pieces need no fit: Latin Modern's hook, extender and top
    ;; are already at least as tall as their CM boxes, so the stack closes.
    ;; The large operators whose slots the engine's table never named -- it
    ;; only has \sum, \prod and \int, and it points the rest of the range at
    ;; those, so \bigcup came out as an integral sign and \bigcap, \bigvee,
    ;; \bigwedge as sums. The slots are cmex10's own (LaTeX's \mathchar
    ;; tables), the names Latin Modern's, and each ink box is cmex10.pfb's as
    ;; dvisvgm outlines it (1/100 em, y up, relative to the shifted operator
    ;; baseline): CM's display operators sit 1.1pt inside their 16pt box, so
    ;; fitting a 14pt Latin Modern design onto the box would overshoot, while
    ;; the text-size ones fill their 10pt box to within .04pt.
    ("cmex" 70 "uni2A06" 0 0 :fit (55.79 -996.26 773.10 0))       ; \bigsqcup
    ("cmex" 71 "uni2A06.v1" 0 0 :fit (55.79 -1394.77 1050.06 0))
    ("cmex" 74 "uni2A00" 0 0 :fit (55.79 -996.26 1050.06 0))      ; \bigodot
    ("cmex" 75 "uni2A00.v1" 0 0 :fit (55.79 -1394.77 1448.57 0))
    ("cmex" 76 "uni2A01" 0 0 :fit (55.79 -996.26 1050.06 0))      ; \bigoplus
    ("cmex" 77 "uni2A01.v1" 0 0 :fit (55.79 -1394.77 1448.57 0))
    ("cmex" 78 "uni2A02" 0 0 :fit (55.79 -996.26 1050.06 0))      ; \bigotimes
    ("cmex" 79 "uni2A02.v1" 0 0 :fit (55.79 -1394.77 1448.57 0))
    ("cmex" 83 "uni22C3" 0 0 :fit (55.79 -996.26 773.10 0))       ; \bigcup
    ("cmex" 91 "uni22C3.v1" 0 0 :fit (55.79 -1394.77 1050.06 0))
    ("cmex" 84 "uni22C2" 0 0 :fit (55.79 -996.26 773.10 0))       ; \bigcap
    ("cmex" 92 "uni22C2.v1" 0 0 :fit (55.79 -1394.77 1050.06 0))
    ("cmex" 85 "uni2A04" 0 0 :fit (55.79 -996.26 773.10 0))       ; \biguplus
    ("cmex" 93 "uni2A04.v1" 0 0 :fit (55.79 -1394.77 1050.06 0))
    ("cmex" 86 "uni22C0" 0 0 :fit (55.79 -996.26 773.10 0))       ; \bigwedge
    ("cmex" 94 "uni22C0.v1" 0 0 :fit (55.79 -1394.77 1050.06 0))
    ("cmex" 87 "uni22C1" 0 0 :fit (55.79 -996.26 773.10 0))       ; \bigvee
    ("cmex" 95 "uni22C1.v1" 0 0 :fit (55.79 -1394.77 1050.06 0))
    ("cmex" 96 "uni2210" 0 0 :fit (55.79 -996.26 883.69 0))       ; \coprod
    ("cmex" 97 "uni2210.v1" 0 0 :fit (55.79 -1394.77 1216.44 0))
    ;; \sum and \prod have outlines of their own in the engine's table, but no
    ;; ink box either, so their display designs sat 2pt short in CM's 16pt
    ;; operator box. Same cmex10.pfb ink boxes as the operators above.
    ("cmex" 80 "summation" 0 0 :fit (55.79 -996.26 995.27 0))     ; \sum
    ("cmex" 88 "summation.v1" 0 0 :fit (55.79 -1394.77 1381.82 0))
    ("cmex" 81 "product" 0 0 :fit (55.79 -996.26 883.69 0))       ; \prod
    ("cmex" 89 "product.v1" 0 0 :fit (55.79 -1394.77 1216.44 0))
    ;; cmsy10's \not slash: zero advance, overlaid on the base, and the one
    ;; glyph shape \neq, \notin and every other \n<rel> share. Its ink box is
    ;; cmex10.pfb's slash as LaTeX draws it over "=", measured from a real
    ;; latex run -- Latin Modern has no such design (no U+29F8 at all), so it
    ;; used to preview whatever the browser fell back to, at the wrong slant.
    ("cmsy" 54 "slash" 0 0 :fit (138.50 -215.20 635.60 713.30))
    ;; The text slash, which \c@ncel (i.e. \notin) overlays instead: cmmi10's
    ;; "/", with its own cmex10-era ink box, measured the same way.
    ("cmmi" 61 "slash" 0 0 :fit (54.80 -249.10 442.30 747.20))
    ("cmmi" 54 "slash" 0 0 :fit (54.80 -249.10 442.30 747.20))
    ;; the wide accents draw at their own CM coordinates, hence shift (0 . 0)
    ("cmex" 98 "cmhatwide" 0 0)
    ("cmex" 99 "cmhatwider" 0 0)
    ("cmex" 100 "cmhatwidest" 0 0)
    ("cmex" 101 "cmtildewide" 0 0)
    ("cmex" 102 "cmtildewider" 0 0)
    ("cmex" 103 "cmtildewidest" 0 0))
  "Glyphs the renderer draws as outlines rather than as a Unicode preview; see
svg-tex::*EXTRA-GLYPH-OUTLINES*. These win over the preview tables: the cmmi
entry is \\vec, and a combining mark cannot be previewed as text -- its zero
advance leaves a renderer no base to attach the ink to, and its ink lies 654
units left of the origin -- so the outline is drawn, shifted onto CM's own ink
box (182..625 units wide, 516..714 above the baseline). The cmex entries are
the wide accents, CM designs with no spacing counterpart at all, whose
outlines already sit at CM's coordinates (hence the zero shift).")

(defun latex-install-outline-glyphs ()
  "Register the outlines above with the renderer. Runs at load time so that
the entry points work whatever font vector a caller passes."
  (pushnew *latex-vec-arrow-path* svg-tex::*math-glyph-paths* :test #'equal)
  (dolist (path *latex-wide-accent-paths*)
    (pushnew path svg-tex::*math-glyph-paths* :test #'equal))
  (dolist (path *latex-bar-piece-paths*)
    (pushnew path svg-tex::*math-glyph-paths* :test #'equal))
  (dolist (path *latex-extra-glyph-paths*)
    (pushnew path svg-tex::*math-glyph-paths* :test #'equal))
  (dolist (entry *latex-extra-cmex-glyph-names*)
    (let ((existing (assoc (car entry) svg-tex::*cmex-glyph-names*)))
      (if existing
          (setf (cdr existing) (cdr entry))
          (push (cons (car entry) (cdr entry)) svg-tex::*cmex-glyph-names*))))
  (setf svg-tex::*extra-glyph-outlines* *latex-extra-glyph-outlines*))

(eval-when (:load-toplevel :execute) (latex-install-outline-glyphs))

;;; ---------------------------------------------------------------------------
;;; Scanner
;;; ---------------------------------------------------------------------------

(defstruct (latex-scan (:conc-name ls-))
  (text "" :type string)
  (pos 0 :type fixnum)
  (len 0 :type fixnum))

(defun ls-eof-p (s) (>= (ls-pos s) (ls-len s)))

(defun ls-peek (s &optional (offset 0))
  (let ((i (+ (ls-pos s) offset)))
    (when (< i (ls-len s)) (char (ls-text s) i))))

(defun ls-next (s)
  (prog1 (ls-peek s) (incf (ls-pos s))))

(defun ls-at-p (s ch)
  "Whether S's next character is CH (NIL-safe)."
  (let ((c (ls-peek s))) (and c (char= c ch))))

(defun ls-alphabetic-p (ch)
  (and ch (or (char<= #\a ch #\z) (char<= #\A ch #\Z))))

(defun ls-skip-spaces (s)
  (loop while (member (ls-peek s) '(#\Space #\Tab #\Newline #\Return))
        do (ls-next s))
  s)

(defun ls-read-command (s)
  "If S is at a backslash, consume the command and return its name (no
backslash, including any trailing *). Otherwise return NIL. The single
character command \\| keeps its backslash: LaTeX makes it \\Vert (the double
bar), while a bare | is the single-bar character, and the scanner would
otherwise report one name for both."
  (when (ls-at-p s #\\)
    (ls-next s)
    (if (ls-alphabetic-p (ls-peek s))
        (with-output-to-string (out)
          (loop while (ls-alphabetic-p (ls-peek s)) do (write-char (ls-next s) out))
          (when (ls-at-p s #\*) (write-char (ls-next s) out)))
        (let ((ch (ls-next s)))
          (if (eql ch #\|) "\\|" (string (or ch #\Space)))))))

(defun ls-peek-string (s str)
  "Whether S starts with STR (used for \\\\ row separators)."
  (let ((n (length str)))
    (and (<= (+ (ls-pos s) n) (ls-len s))
         (string= str (subseq (ls-text s) (ls-pos s) (+ (ls-pos s) n))))))

(defun ls-peek-command (s)
  (let ((save (ls-pos s)))
    (prog1 (ls-read-command s) (setf (ls-pos s) save))))

;;; ---------------------------------------------------------------------------
;;; Parser: LaTeX math -> TeX mlist (noad chain)
;;; ---------------------------------------------------------------------------

(defun make-noad-of-class (class family code)
  "A noad of noad CLASS carrying a single font character."
  (let ((field (svg-tex:make-math-char-field
                (svg-tex:make-mchar :family family :code code))))
    (ecase class
      (:ord (svg-tex:ord-noad field))
      (:op (svg-tex:op-noad field :subtype :normal))
      (:bin (svg-tex:bin-noad field))
      (:rel (svg-tex:rel-noad field))
      (:open (svg-tex:open-noad field))
      (:close (svg-tex:close-noad field))
      (:punct (svg-tex:punct-noad field))
      (:inner (svg-tex:inner-noad field)))))

(defun make-text-char-noad (family code)
  "An ordinary noad whose nucleus is a math_text_char (tex.web's
math_text_char): a character taken from a text font. mlist_to_hlist drops the
italic correction of such a character when the font has a nonzero interword
space, which is exactly TeX's rule for text-mode characters -- and why
\\text{if and only if} must not be spaced with cmr10's italic corrections."
  (svg-tex:ord-noad
   (svg-tex:make-math-text-char-field
    (svg-tex:make-mchar :family family :code code))))

(defun symbol-entry (name)
  (assoc name *latex-symbols* :test #'string=))

(defun char-symbol-entry (ch)
  (assoc (char-code ch) *latex-char-symbols*))

(defun accent-entry (name)
  (assoc name *latex-accents* :test #'string=))

(defparameter *latex-char-atom-types*
  '(:ord :op :bin :rel :open :close :punct :inner)
  "Noad types that stand for a single symbol (tex.web's eight math classes).
The other types keep generated material -- a box, an mlist, a delimiter --
in their nucleus field.")

(defun latex-nucleus-field (mlist)
  "The nucleus field for an accent / radical / over / under atom.

TeX's scanner turns a lone character into a math_char field and anything else
into a sub_mlist field, and make_math_accent takes the base character's skew
only for the former (tex.web <Compute the amount of skew>). Passing a
sub_mlist for `\\hat{x}' therefore loses the skew and draws the accent a
skew-kern too far left, so reproduce the scanner's choice here.

Only the eight spacing classes count as characters: a radical, fraction,
accent, over/under or \\left...\\right noad also keeps something in its
nucleus field, and reusing that field would drop the construct itself."
  (let ((field (and mlist
                    (member (svg-tex:n-type mlist) *latex-char-atom-types*)
                    (null (svg-tex:n-link mlist))
                    (svg-tex:field-empty-p (svg-tex:n-supscr mlist))
                    (svg-tex:field-empty-p (svg-tex:n-subscr mlist))
                    (svg-tex:n-nucleus mlist))))
    (if (and field (svg-tex:field-math-char-p field))
        field
        (svg-tex:make-sub-mlist-field mlist))))

(defun delimiter-entry (name)
  (assoc name *latex-delimiters* :test #'string=))

(defun make-latex-delimiter (name)
  "Resolve delimiter NAME (a command name, or a single character) to a
svg-tex DELIMITER, or NIL for the null delimiter `.'."
  (cond
    ((null name) (svg-tex:null-delimiter))
    ((string= name ".") (svg-tex:null-delimiter))
    (t
     (let* ((key (cond ((string= name "{") "lbrace")
                       ((string= name "}") "rbrace")
                       ((string= name "|") "vert")
                       ((string= name "\\|") "Vert")
                       ((string= name "\\") "backslash")
                       (t name)))
            (entry (delimiter-entry key)))
       (when entry
         (destructuring-bind (cls small large) (cdr entry)
           (declare (ignore cls))
           (svg-tex:make-delimiter (car small) (cdr small)
                                       (car large) (cdr large))))))))

(defun latex-space-node (mu)
  (svg-tex:new-glue
   (svg-tex:make-glue-spec (* mu *latex-mu*) 0 0)))

(defun ls-skip-space-characters (s)
  "Skip spaces, except inside \\text{...} where a space is a real interword
space that has to reach the mlist (see *LATEX-TEXT-MODE*)."
  (unless *latex-text-mode* (ls-skip-spaces s)))

(defun roman-mlist (string)
  "STRING typeset upright in family 0 (what plain TeX's \\rm does)."
  (let ((nodes nil) (tail nil))
    (loop for ch across string
          for noad = (svg-tex:ord-noad
                      (svg-tex:make-math-char-field
                       (svg-tex:make-mchar :family 0 :code (char-code ch))))
          do (if tail
                 (progn (setf (svg-tex:n-link tail) noad) (setf tail noad))
                 (setf nodes noad tail noad)))
    nodes))

;;; Forward declarations for the mutually recursive parser.
(declaim (ftype (function (latex-scan &key (:stop-bracket t) (:stop-matrix t)
                                        (:stop-right t)) t)
                parse-math-list))
(declaim (ftype (function (latex-scan) t) parse-script-mlist))
(declaim (ftype (function (latex-scan) t) parse-atom))

(defun parse-required-mlist (s)
  "Read a `{...}' group (or, defensively, a single atom) as an mlist."
  (ls-skip-spaces s)
  (if (ls-at-p s #\{)
      (progn (ls-next s)
             (prog1 (parse-math-list s)
               (ls-skip-spaces s)
               (when (ls-at-p s #\}) (ls-next s))))
      (parse-script-mlist s)))

(defun parse-optional-mlist (s)
  "Read a `[...]' group, or NIL when the next token is not `['."
  (ls-skip-spaces s)
  (when (ls-at-p s #\[)
    (ls-next s)
    (prog1 (parse-math-list s :stop-bracket t)
      (ls-skip-spaces s)
      (when (ls-at-p s #\]) (ls-next s)))))

(defun parse-script-mlist (s)
  "The argument of ^ or _: a braced group or exactly one atom."
  (ls-skip-spaces s)
  (if (ls-at-p s #\{)
      (parse-required-mlist s)
      (let ((mlist (parse-atom s)))
        (or mlist (svg-tex:ord-noad (svg-tex:make-empty-field))))))

(defun attach-script (noad kind mlist)
  (when noad
    (when mlist
      (if (eq kind :sup)
          (setf (svg-tex:n-supscr noad) (svg-tex:make-sub-mlist-field mlist))
          (setf (svg-tex:n-subscr noad) (svg-tex:make-sub-mlist-field mlist)))))
  noad)

(defun parse-matrix-body (s)
  "Read cells/rows up to \\end{ENV-NAME}; return a list of row mlists."
  (let ((rows nil) (row nil))
    (loop
      (let ((cell (parse-math-list s :stop-matrix t)))
        (push cell row)
        (ls-skip-spaces s)
        (cond
          ((ls-at-p s #\&) (ls-next s))
          ((ls-peek-string s "\\\\")
           (ls-next s) (ls-next s)
           (push (nreverse row) rows) (setf row nil))
          ((string= (or (ls-peek-command s) "") "end")
           (ls-read-command s)
           (ls-skip-spaces s)
           (when (ls-at-p s #\{)
             (ls-next s)
             (loop while (and (ls-peek s) (not (ls-at-p s #\})))
                   do (ls-next s))
             (when (ls-at-p s #\}) (ls-next s)))
           (push (nreverse row) rows)
           (return (nreverse rows)))
          ((ls-eof-p s)
           (push (nreverse row) rows)
           (return (nreverse rows)))
          (t (return (nreverse (push (nreverse row) rows)))))))))

(defparameter *matrix-environments*
  ;; name -> (left small-fam small-code large-fam large-code) or NIL (no fence)
  '(("matrix" nil nil)
    ("pmatrix" (0 40 3 0) (0 41 3 1))
    ("bmatrix" (0 91 3 2) (0 93 3 3))
    ("Bmatrix" (2 102 3 8) (2 103 3 9))
    ("vmatrix" (2 106 3 12) (2 106 3 12))
    ("Vmatrix" (2 107 3 13) (2 107 3 13))
    ("smallmatrix" nil nil))
  "Environment name -> (left-spec right-spec). A spec is
(small-family small-code large-family large-code), matching TeX's \\delcode.")

(defun make-delimiter-from-spec (spec)
  (destructuring-bind (sf sc lf lc) spec
    (svg-tex:make-delimiter sf sc lf lc)))

(defun parse-environment (s)
  "Parse \\begin{env}...\\end{env}. Returns an mlist (possibly NIL)."
  (ls-skip-spaces s)
  (let ((env-name
          (if (ls-at-p s #\{)
              (progn
                (ls-next s)
                (prog1 (with-output-to-string (out)
                         (loop while (and (ls-peek s) (not (ls-at-p s #\})))
                               do (write-char (ls-next s) out)))
                  (when (ls-at-p s #\}) (ls-next s))))
              (or (ls-read-command s) ""))))
    (let ((entry (assoc env-name *matrix-environments* :test #'string=)))
      (when entry
        (destructuring-bind (name left right) entry
          (declare (ignore name))
          (let* ((rows (parse-matrix-body s))
                 (matrix (svg-tex:make-matrix-noad rows)))
            (if (and (null left) (null right))
                (list matrix)
                (list (svg-tex:left-noad (make-delimiter-from-spec left))
                      matrix
                      (svg-tex:right-noad (make-delimiter-from-spec right))))))))))

(defun parse-command-atom-nodes (s name)
  "Parse \\NAME; returns a list of top-level nodes (or NIL)."
  (cond
    ;; --- fractions / binomials ---
    ((member name '("frac" "cfrac") :test #'string=)
     (let ((num (parse-required-mlist s))
           (den (parse-required-mlist s)))
       (list (svg-tex:make-fraction-noad
              nil
              (svg-tex:make-sub-mlist-field num)
              (svg-tex:make-sub-mlist-field den)))))
    ((string= name "dfrac")
     (let ((num (parse-required-mlist s))
           (den (parse-required-mlist s)))
       (list (styled-fraction svg-tex:display-style num den))))
    ((string= name "tfrac")
     (let ((num (parse-required-mlist s))
           (den (parse-required-mlist s)))
       (list (styled-fraction svg-tex:text-style num den))))
    ((member name '("binom" "dbinom" "tbinom") :test #'string=)
     (let ((num (parse-required-mlist s))
           (den (parse-required-mlist s)))
       (list (svg-tex:make-fraction-noad
              0
              (svg-tex:make-sub-mlist-field num)
              (svg-tex:make-sub-mlist-field den)
              (svg-tex:make-delimiter 0 40 3 0)
              (svg-tex:make-delimiter 0 41 3 1)))))
    ;; --- radicals ---
    ((string= name "sqrt")
     (let* ((index (parse-optional-mlist s))
            (radicand (parse-required-mlist s))
            (noad (svg-tex:make-radical-noad
                   (latex-nucleus-field radicand)
                   (svg-tex:make-delimiter 2 112 3 112))))
       (when index
         ;; the index is not a superscript: the engine places it in the crook
         ;; of the radical sign (see svg-tex::RADICAL-INDEX-BOX)
         (setf (svg-tex:n-index noad)
               (svg-tex:make-sub-mlist-field index)))
       (list noad)))
    ;; --- \left ... \right ---
    ((string= name "left")
     (let* ((left (read-delimiter-token s))
            (content (parse-math-list s :stop-right t))
            (right (progn (ls-skip-spaces s)
                          (if (string= (or (ls-peek-command s) "") "right")
                              (progn (ls-read-command s) (read-delimiter-token s))
                              nil))))
       ;; TeX makes \left...\right a single Inner atom whose delimiters are
       ;; sized from the *local* group extents. Wrapping the left_noad ...
       ;; right_noad run in a sub-mlist reproduces both: mlist_to_hlist then
       ;; sees the local max height/depth and the outer atom gets class inner.
       ;; (NL-APPEND, not NL, so the linked CONTENT chain keeps its tail.)
       (list (svg-tex:inner-noad
              (svg-tex:make-sub-mlist-field
               (svg-tex:nl-append
                (svg-tex:left-noad (make-latex-delimiter left))
                content
                (svg-tex:right-noad (make-latex-delimiter right))))))))
    ;; --- accents ---
    ((accent-entry name)
     (destructuring-bind (nm family code) (accent-entry name)
       (declare (ignore nm))
       (let ((base (parse-required-mlist s)))
         (list (svg-tex:make-accent-noad
                (svg-tex:make-mchar :family family :code code)
                (latex-nucleus-field base))))))
    ((string= name "overline")
     (let ((base (parse-required-mlist s)))
       (list (svg-tex:make-over-noad (latex-nucleus-field base)))))
    ((string= name "underline")
     (let ((base (parse-required-mlist s)))
       (list (svg-tex:make-under-noad (latex-nucleus-field base)))))
    ;; --- named functions / big operators ---
    ((member name *latex-named-ops* :test #'string=)
     (let ((subtype (if (member name *latex-named-limits-ops* :test #'string=)
                        :normal :nolimits)))
       (list (svg-tex:op-noad
              (svg-tex:make-sub-mlist-field (roman-mlist name))
              :subtype subtype))))
    ;; \int/\oint are macros in plain TeX and LaTeX (\intop\nolimits); the
    ;; multiple-integral commands are amsmath shorthands for the same atom.
    ((member name '("int" "iint" "iiint" "iiiint" "idotsint") :test #'string=)
     (list (svg-tex:op-noad
            (svg-tex:make-math-char-field
             (svg-tex:make-mchar :family 3 :code 82))
            :subtype :nolimits)))
    ((string= name "oint")
     (list (svg-tex:op-noad
            (svg-tex:make-math-char-field
             (svg-tex:make-mchar :family 3 :code 72))
            :subtype :nolimits)))
    ;; \neq / \ne are \not= in LaTeX; \not is the zero-width cmsy slash.
    ((member name '("neq" "ne") :test #'string=)
     (list (not-overlay (make-noad-of-class :ord 0 61))))
    ;; \notin is the one symbol fontmath.ltx negates with \c@ncel rather than
    ;; \not, so its slash is centred over the base (see CANCEL-OVERLAY).
    ((string= name "notin")
     (list (cancel-overlay (make-noad-of-class :ord 2 50) 2 50)))
    ;; \mapsto, \hookrightarrow, ... are macro compositions of real glyphs.
    ((string= name "mapsto")
     (list (make-noad-of-class :rel 2 55)     ; \mapstochar
           (make-noad-of-class :rel 2 33)))   ; \rightarrow
    ((string= name "models")
     (list (compose-rel (list (make-noad-of-class :ord 2 106)
                              (make-noad-of-class :ord 0 61)))))
    ((string= name "cong")
     ;; \cong overlays \sim and =; width equals \sim's.
     (list (make-noad-of-class :rel 2 24)))
    ((string= name "doteq")
     ;; \doteq builds on =; width equals ='s.
     (list (make-noad-of-class :rel 0 61)))
    ((member name '("bowtie") :test #'string=)
     (list (compose-rel (list (make-noad-of-class :ord 1 46)
                              (make-noad-of-class :ord 1 47)))))
    ((string= name "hookrightarrow")
     (list (compose-rel (list (make-noad-of-class :ord 1 44)
                              (make-noad-of-class :ord 2 33)))))
    ((string= name "hookleftarrow")
     (list (compose-rel (list (make-noad-of-class :ord 2 32)
                              (make-noad-of-class :ord 1 45)))))
    ;; amsmath & friends define \n<rel> as \not<rel>. Only a multi-letter base
    ;; counts, so \nu / \ni are not mistaken for a negation of u / i.
    ((and (> (length name) 2)
          (char= (char name 0) #\n)
          (> (length (subseq name 1)) 1)
          (symbol-entry (subseq name 1)))
     (let ((base (symbol-entry (subseq name 1))))
       (list (not-overlay (make-noad-of-class (second base) (third base)
                                              (fourth base))))))
    ;; --- spacing (must precede the single-character symbol table, which
    ;;     also contains entries for , : ; ! as ordinary punctuation) ---
    ((string= name ",") (list (latex-space-node 3)))
    ((member name '(":" ">") :test #'string=) (list (latex-space-node 4)))
    ((string= name ";") (list (latex-space-node 5)))
    ((string= name "!") (list (svg-tex:new-kern (- (* 3 *latex-mu*)))))
    ((string= name " ") (list (svg-tex:new-kern (round *latex-quad* 3))))
    ((string= name "quad") (list (svg-tex:new-kern *latex-quad*)))
    ((string= name "qquad") (list (svg-tex:new-kern (* 2 *latex-quad*))))
    ((string= name "thinspace") (list (latex-space-node 3)))
    ((string= name "enspace") (list (svg-tex:new-kern (round *latex-quad* 2))))
    ((string= name "negthinspace") (list (svg-tex:new-kern (- (* 3 *latex-mu*)))))
    ((symbol-entry name)
     (destructuring-bind (symbol-name class family code) (symbol-entry name)
       (declare (ignore symbol-name))
       (if (eq class :op)
           (list (svg-tex:op-noad
                  (svg-tex:make-math-char-field
                   (svg-tex:make-mchar :family family :code code))
                  :subtype (cond ((member name *latex-big-op-limits* :test #'string=) :normal)
                                 ((member name *latex-big-op-nolimits* :test #'string=) :nolimits)
                                 (t :nolimits))))
           (list (make-noad-of-class class family code)))))
    ;; --- environments ---
    ((string= name "begin") (parse-environment s))
    ;; --- text/alfont style commands ---
    ;; \text (and \textrm) typesets its argument in text mode, where spaces
    ;; count; the math-alphabet commands leave the math scanner in charge.
    ((member name '("textrm" "text") :test #'string=)
     (ls-skip-spaces s)                 ; the brace may follow a space
     (let* ((*latex-text-mode* t)
            (*latex-upright* t)
            (mlist (parse-required-mlist s)))
       (list (or (single-math-char-noad mlist)
                 (svg-tex:ord-noad (svg-tex:make-sub-mlist-field mlist))))))
    ((member name '("mathrm" "mathbf" "mathsf" "mathtt") :test #'string=)
     (let* ((*latex-upright* t)
            (mlist (parse-required-mlist s)))
       (list (or (single-math-char-noad mlist)
                 (svg-tex:ord-noad (svg-tex:make-sub-mlist-field mlist))))))
    ((member name '("mathit" "mathnormal") :test #'string=)
     (let* ((*latex-upright* nil)
            (mlist (parse-required-mlist s)))
       (list (or (single-math-char-noad mlist)
                 (svg-tex:ord-noad (svg-tex:make-sub-mlist-field mlist))))))
    ((string= name "mathcal")
     (let* ((*latex-calligraphic* t)
            (mlist (parse-required-mlist s)))
       (list (or (single-math-char-noad mlist)
                 (svg-tex:ord-noad (svg-tex:make-sub-mlist-field mlist))))))
    ((string= name "operatorname")
     (let* ((*latex-upright* t)
            (mlist (parse-required-mlist s)))
       (list (svg-tex:op-noad (svg-tex:make-sub-mlist-field mlist)
                              :subtype :nolimits))))
    ;; \operatorname* is the limits form (amsmath): the scripts go above and
    ;; below in display style, as they do for \lim. The scanner keeps the
    ;; star in the command name (see LS-READ-COMMAND).
    ((string= name "operatorname*")
     (let* ((*latex-upright* t)
            (mlist (parse-required-mlist s)))
       (list (svg-tex:op-noad (svg-tex:make-sub-mlist-field mlist)
                              :subtype :normal))))
    ;; --- dots ---
    ((string= name "ldots")
     (list (make-noad-of-class :punct 1 58)
           (make-noad-of-class :punct 1 58)
           (make-noad-of-class :punct 1 58)))
    ((member name '("cdots" "dots") :test #'string=)
     (list (make-noad-of-class :punct 2 1)
           (make-noad-of-class :punct 2 1)
           (make-noad-of-class :punct 2 1)))
    ((member name '("vdots" "ddots") :test #'string=)
     (list (make-noad-of-class :punct 2 1)
           (make-noad-of-class :punct 2 1)
           (make-noad-of-class :punct 2 1)))
    ;; --- escaped characters and leftovers ---
    ((string= name "%") (list (make-noad-of-class :ord 0 (char-code #\%))))
    ((string= name "&") (list (make-noad-of-class :ord 0 (char-code #\&))))
    ((string= name "#") (list (make-noad-of-class :ord 0 (char-code #\#))))
    ((string= name "$") (list (make-noad-of-class :ord 0 (char-code #\$))))
    ((string= name "_") (list (make-noad-of-class :ord 0 95)))
    ((string= name "{") (list (make-noad-of-class :open 2 102)))
    ((string= name "}") (list (make-noad-of-class :close 2 103)))
    ((string= name "lbrace") (list (make-noad-of-class :open 2 102)))
    ((string= name "rbrace") (list (make-noad-of-class :close 2 103)))
    ((member name '("|" "Vert") :test #'string=) (list (make-noad-of-class :ord 2 107)))
    ((string= name "\\|") (list (make-noad-of-class :ord 2 107)))
    ((member name '("vert") :test #'string=) (list (make-noad-of-class :ord 2 106)))
    ((string= name "backslash") (list (make-noad-of-class :ord 2 110)))
    ((string= name "not")
     ;; \not<base>: the cmsy negation slash has zero advance width, so placing
     ;; it before the base reproduces TeX's overlay geometry.
     (list (not-overlay (parse-atom s))))
    ((member name '("displaystyle" "textstyle" "scriptstyle"
                    "scriptscriptstyle") :test #'string=)
     (list (svg-tex:new-style
            (ecase (intern (string-upcase name) :keyword)
              (:displaystyle svg-tex:display-style)
              (:textstyle svg-tex:text-style)
              (:scriptstyle svg-tex:script-style)
              (:scriptscriptstyle svg-tex:script-script-style)))))
    ((member name '("mathord" "mathop" "mathbin" "mathrel" "mathopen"
                    "mathclose" "mathpunct" "mathinner") :test #'string=)
     (let ((mlist (parse-required-mlist s)))
       (list (svg-tex:ord-noad (svg-tex:make-sub-mlist-field mlist)))))
    (t nil)))

(defun parse-command-atom (s name)
  "Parse the atom introduced by \\NAME and return it as a node chain."
  (let ((nodes (parse-command-atom-nodes s name)))
    (when nodes
      (apply #'svg-tex:nl-append (remove nil nodes)))))

(defun read-delimiter-token (s)
  "Read the delimiter after \\left / \\right: a command name or a character.
Returns the delimiter key understood by MAKE-LATEX-DELIMITER."
  (ls-skip-spaces s)
  (if (ls-at-p s #\\)
      (or (ls-read-command s) ".")
      (let ((ch (ls-next s)))
        (cond ((null ch) ".")
              ((char= ch #\.) ".")
              ((char= ch #\{) "{")
              ((char= ch #\}) "}")
              ((char= ch #\|) "|")
              (t (string ch))))))

(defun make-group-noad (mlist)
  (svg-tex:ord-noad (svg-tex:make-sub-mlist-field mlist)))

(defun compose-rel (noads)
  "Wrap the nodes in NOADS into a single relation atom, preserving their total
width and suppressing inter-piece spacing (used for \\mapsto, \\hookrightarrow,
... which TeX builds from several glyphs)."
  (svg-tex:rel-noad
   (svg-tex:make-sub-mlist-field (apply #'svg-tex:nl-append noads))))

(defun single-math-char-noad (mlist)
  "When MLIST is exactly one noad holding a plain math character, return it.
\\mathrm{d} and friends must stay a bare character so TeX's script placement
(which differs between a char node and a boxed group) is reproduced."
  (when (and mlist
             (null (svg-tex:n-link mlist))
             (svg-tex:noad-p mlist)
             (svg-tex:field-math-char-p (svg-tex:n-nucleus mlist)))
    mlist))

(defun styled-fraction (style numerator denominator)
  "A fraction forced to STYLE (TeX's \\dfrac / \\tfrac). The style node is
scoped inside the fraction's own sub-mlist, so it does not leak."
  (svg-tex:inner-noad
   (svg-tex:make-sub-mlist-field
    (svg-tex:nl
     (svg-tex:new-style style)
     (svg-tex:make-fraction-noad
      nil
      (svg-tex:make-sub-mlist-field numerator)
      (svg-tex:make-sub-mlist-field denominator))))))

(defun not-overlay (base)
  "Overlay the zero-width cmsy negation slash on BASE, yielding one rel atom.
TeX's \\not slot (cmsy10 code 54) has zero advance width, so prefixing it to
the base reproduces \\not=, \\not\\in, ... geometry without any kern."
  (when base
    (when (svg-tex:noad-p base) (setf (svg-tex:n-type base) :ord))
    (let ((slash (svg-tex:ord-noad
                  (svg-tex:make-math-char-field
                   (svg-tex:make-mchar :family 2 :code 54)))))
      (setf (svg-tex:n-link slash) base)
      (svg-tex:rel-noad (svg-tex:make-sub-mlist-field slash)))))

(defun cancel-overlay (base family code)
  "Build LaTeX's \\c@ncel, which fontmath.ltx gives to \\notin (and nothing
else): the *text* slash (cmmi10 61) overlaid on a single-glyph BASE. \\c@ncel
is \\ooalign{${}\\hfil\\mkern1mu/\\hfil$\\crcr$<base>$}, so the slash sits
centred over BASE's box, pushed 1mu right of that centre, and the overlay keeps
BASE's width. The slash's advance is cancelled by a kern (and the shift with
it), which is how a zero-advance overlay is built here.

Every other \\n<rel> is \\not<rel> -- \\neq included -- and \\not is the
zero-advance cmsy slash at the base's origin, which NOT-OVERLAY already does."
  (when base
    (when (svg-tex:noad-p base) (setf (svg-tex:n-type base) :ord))
    (let* ((fonts (latex-math-fonts))
           (base-font (svg-tex:math-font-for fonts family 0))
           (slash-font (svg-tex:math-font-for fonts 1 0))
           (slash-code *latex-cancel-slash-code*)
           (base-width (svg-tex:math-font-char-width base-font code))
           (slash-width (svg-tex:math-font-char-width slash-font slash-code))
           (shift (round (+ (- base-width slash-width) *latex-mu*) 2))
           (slash (svg-tex:ord-noad
                   (svg-tex:make-math-char-field
                    (svg-tex:make-mchar :family 1 :code slash-code)))))
      (svg-tex:rel-noad
       (svg-tex:make-sub-mlist-field
        (svg-tex:nl-append (svg-tex:new-kern shift) slash
                           (svg-tex:new-kern (- (+ shift slash-width))) base))))))

(defun script-attachable-p (node)
  "Whether scripts may be hung directly on NODE. TeX attaches ^/_ to the last
noad; a \\left...\\right pair (or a bare style/spacing node) has to be boxed
into a group first."
  (and node
       (svg-tex:noad-p node)
       (not (member (svg-tex:n-type node) '(:left :right :style)))))

(defun parse-atom (s)
  "Parse one atom; returns a node chain or NIL."
  (when (and *latex-text-mode* (ls-at-p s #\Space))
    (loop while (ls-at-p s #\Space) do (ls-next s))
    (return-from parse-atom (latex-space-node 6)))
  (ls-skip-space-characters s)
  (let ((ch (ls-peek s)))
    (cond
      ((null ch) nil)
      ((char= ch #\\) (parse-command-atom s (or (ls-read-command s) "")))
      ((char= ch #\{)
       (ls-next s)
       (let ((inner (parse-math-list s)))
         (ls-skip-spaces s)
         (when (ls-at-p s #\}) (ls-next s))
         (if inner (make-group-noad inner) nil)))
      ((member ch '(#\^ #\_)) nil)          ; handled by the script loop
      ((char= ch #\&) nil)
      (t
       (ls-next s)
       (cond
         ;; \text{...} is text mode: every character comes from the text font
         ;; (cmr at the current size), not from the math symbol tables, and
         ;; its italic correction is suppressed (see MAKE-TEXT-CHAR-NOAD).
         (*latex-text-mode* (make-text-char-noad 0 (char-code ch)))
         ;; \mathcal / \mathrm / \text change the alphabet for bare letters,
         ;; overriding the default math-italic mapping.
         ((and *latex-calligraphic* (ls-alphabetic-p ch))
          (make-noad-of-class :ord 2 (char-code ch)))
         ((and *latex-upright* (ls-alphabetic-p ch))
          (make-noad-of-class :ord 0 (char-code ch)))
         (t
          (let ((entry (char-symbol-entry ch)))
            (if entry
                (destructuring-bind (code class family font-code) entry
                  (declare (ignore code))
                  (make-noad-of-class class family font-code))
                (if (and (char>= ch #\0) (char<= ch #\9))
                    (make-noad-of-class :ord 0 (char-code ch))
                    (make-noad-of-class :ord 1 (char-code ch)))))))))))

(defun parse-math-list (s &key stop-bracket stop-matrix stop-right)
  "Parse a math list up to `}`, `&`, `\\\\`, `\\end`, `\\right` or EOF as
requested by the STOP-* flags. Returns an mlist (node chain)."
  (let ((head nil) (tail nil)
        (stop-p (lambda ()
                  (ls-skip-space-characters s)
                  (let ((ch (ls-peek s)))
                    (or (null ch)
                        (char= ch #\})
                        (char= ch #\&)
                        (and stop-bracket (char= ch #\]))
                        (and stop-matrix (ls-peek-string s "\\\\"))
                        (and stop-right
                             (string= (or (ls-peek-command s) "") "right"))
                        (and stop-matrix
                             (string= (or (ls-peek-command s) "") "end")))))))
    (loop
      (when (funcall stop-p) (return))
      (let* ((atom (parse-atom s))
             (base (and atom (svg-tex:last-node atom))))
        (when (null atom)
          ;; Skip an unknown/stray token to guarantee progress.
          (if (ls-peek s) (ls-next s) (return)))
        (loop
          (ls-skip-space-characters s)
          (let ((ch (ls-peek s)))
            (cond
              ((null ch) (return))
              ((char= ch #\^)
               (ls-next s)
               (unless (script-attachable-p base)
                 (setf atom (make-group-noad atom) base atom))
               (attach-script base :sup (parse-script-mlist s)))
              ((char= ch #\_)
               (ls-next s)
               (unless (script-attachable-p base)
                 (setf atom (make-group-noad atom) base atom))
               (attach-script base :sub (parse-script-mlist s)))
              (t (return)))))
        (when atom
          (if tail
              (progn (setf (svg-tex:n-link tail) atom)
                     (setf tail (svg-tex:last-node atom)))
              (setf head atom tail (svg-tex:last-node atom))))))
    head))

;;; ---------------------------------------------------------------------------
;;; Public front end
;;; ---------------------------------------------------------------------------

(defun latex-preprocess (formula)
  "Strip the math delimiters ($...$, \\(...\\), \\[...\\]) the caller may have
written, matching the external `latex' command's input style."
  (let ((text (str:trim formula)))
    (cond
      ((and (>= (length text) 4) (string= "$$" (subseq text 0 2))
            (string= "$$" (subseq text (- (length text) 2))))
       (subseq text 2 (- (length text) 2)))
      ((and (>= (length text) 2) (string= "$" (subseq text 0 1))
            (string= "$" (subseq text (1- (length text)))))
       (subseq text 1 (1- (length text))))
      ((and (>= (length text) 4) (string= "\\(" (subseq text 0 2))
            (string= "\\)" (subseq text (- (length text) 2))))
       (subseq text 2 (- (length text) 2)))
      ((and (>= (length text) 4) (string= "\\[" (subseq text 0 2))
            (string= "\\]" (subseq text (- (length text) 2))))
       (subseq text 2 (- (length text) 2)))
      (t text))))

(defun parse-latex-math (formula &key (style :display))
  "Compile a LaTeX math string to a TeX mlist. STYLE is :DISPLAY or :TEXT;
display style only affects operator limits and fraction placement."
  (declare (ignore style))
  (let* ((text (latex-preprocess formula))
         (scan (make-latex-scan :text text :pos 0 :len (length text))))
    (parse-math-list scan)))

(defun latex-typeset (formula &key (math-style :display) (fonts nil))
  "Typeset FORMULA to a TeX box (no external process)."
  (let* ((mlist (parse-latex-math formula :style math-style))
         (style (ecase math-style
                  (:display svg-tex:display-style)
                  (:text svg-tex:text-style)))
         (font-vector (or fonts (latex-math-fonts))))
    (svg-tex:mlist-to-box mlist style font-vector)))

(defparameter *latex-svg-inner-scanner*
  (ppcre:create-scanner "(?s)<svg[^>]*>(.*)</svg>"))

(defun latex*-svg (formula &key (math-style :display) (fonts nil))
  "Render FORMULA natively and return the standalone SVG string."
  (svg-tex:render-to-svg (latex-typeset formula :math-style math-style :fonts fonts)))

(defun latex*-inner-svg (formula &key (math-style :display) (fonts nil))
  "The rendered markup inside the <svg> wrapper (what `latex*' embeds)."
  (let ((svg (latex*-svg formula :math-style math-style :fonts fonts)))
    (multiple-value-bind (whole inner)
        (ppcre:scan-to-strings *latex-svg-inner-scanner* svg)
      (declare (ignore whole))
      (if inner (str:trim (aref inner 0)) svg))))

(defun latex* (position formula &rest attrs)
  "Render a LaTeX math formula and embed it natively (no external latex).

Placement matches the external `latex': the formula's baseline-left origin is
at POSITION and :SCALE scales it about that origin. :MATH-STYLE selects display
or text style (:display by default). Any other keyword is passed through as an
SVG attribute on the wrapping <g>, exactly like `latex'."
  (let* ((px (x position))
         (py (y position))
         (scale (getf attrs :scale))
         (math-style (getf attrs :math-style :display))
         (clean-attrs (alexandria:remove-from-plist attrs :scale :math-style))
         (content (latex*-inner-svg formula :math-style math-style))
         (final-attrs (append (list :translate (p px py))
                              (when (and scale (plusp scale)) (list :scale scale))
                              clean-attrs)))
    (write-raw-element "g" final-attrs content)))
