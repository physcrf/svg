# src/tex — vendored TeX math-typesetting engine

These files are a **local port** of the sibling `typesetting` project's tex.web
port (node model, `hpack`/`vpackage`, `var_delimiter`, `mlist_to_hlist`, the CM
font metrics and the SVG renderer). They are compiled into this system's own
package, `svg-tex`, so `svg` has **no run-time dependency** on `typesetting`
and `latex*` works on its own.

Sources are kept as close to upstream as they can be, so they can be re-synced
by copying `typesetting/src/*.lisp` here and applying the package rename
`(in-package :typesetting)` → `(in-package :svg-tex)` (see
`tools/gen-latex-tables.py` for the metric data it consumes). Two places in
`render.lisp` go past the rename, both marked with a comment:

- `SVG-FONT-NAME` appends a fallback family (`LM Roman Seven, Latin Modern
  Roman`) to the script sizes, so a renderer that cannot see the OpenType
  files still gets Latin Modern rather than its default serif;
- `*EXTRA-GLYPH-OUTLINES*` lets `../latex-star.lisp` register glyphs to draw
  from outlines that the CM-code tables above do not reach -- the `\vec` arrow
  (cmmi10 126, which Latin Modern keeps as the combining mark U+20D7) and the
  cmex10 wide accents. `../latex-star.lisp` holds the paths and registers them
  at load time.

`make-matrix` in `mlist.lisp` is the engine's own grid extension (tex.web has no
matrix construct: LaTeX builds one with `\halign` inside a `\vcenter`). It
emulates that layout -- a `\strut` per row, a 1em column gap and centering on
the math axis -- so `\begin{matrix}` and its delimited variants agree with a
real LaTeX run. `smallmatrix` is the one exception: it is laid out like
`matrix`, not with LaTeX's tighter script-size spacing.

`*CMEX-GLYPH-NAMES*` in `render.lisp` was upstream's mapping of the cmex
delimiter codes to Latin Modern outlines, and it only covered the parenthesis
chains; `../latex-star.lisp` extends it with the bracket, brace, floor, ceiling
and angle chains plus their extensible pieces, and with the vertical-bar
extenders (drawn through the `:fit` mode of `*EXTRA-GLYPH-OUTLINES*`, which
maps Latin Modern's 12pt repeater onto the ink box of CM's 6.42pt piece --
Latin Modern's bars are a different weight and inset as well as a different
size, so nothing short of that lands the stacked pieces where cmex10 draws
them).

`make-radical` also places a `\sqrt[n]` index. tex.web keeps that index out of
the noad -- in the global `\rootbox` -- so the port had no slot for it at all;
we added the node's `index` field and reproduce LaTeX's placement (see
`RADICAL-INDEX-BOX` in `mlist.lisp`): typeset in `\scriptscriptstyle`, raised to
3/5 of the radicand's height-above-depth plus .135em, and tucked .2778em into
the sign's crook, contributing no height or depth.

`latex*` itself lives one level up in `../latex-star.lisp`; the LaTeX front end
and the additive Computer Modern metric layer are in `../latex-tables.lisp`
(generated) and `../latex-star.lisp`.

## Provenance

Upstream: `../typesetting/src/*.lisp` (mirroring D. E. Knuth's `tex.web`,
§649–§736). The unit system is sp fixed point (1pt = 65536sp); box coordinates
grow upward and the renderer converts to SVG's downward pt.

## Notes

- The engine ships only the CM glyphs its own tests exercise. `latex-star.lisp`
  adds the remaining slots the LaTeX symbol tables need (verified against the
  real TFMs) and extends the cmex delimiter chains (e.g. the `(` chain
  `0 → 16 → 18 → 32 → 48`, with 48 extensible).
- The engine deliberately carries no ligature/kern programs, so cmmi kerns
  (e.g. `,` followed by `\epsilon`) are not applied.
