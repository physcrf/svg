(asdf:defsystem #:svg
  :description "SVG generation library for Common Lisp with LaTeX support"
  :version "0.3.0"
  :depends-on (:alexandria :cl-ppcre :str :trivia)
  :serial t
  :components ((:file "src/package")
               (:file "src/utils")
               (:file "src/attributes")
               (:file "src/marker")
               (:file "src/core")
               (:file "src/shapes")
               (:file "src/path")
               (:file "src/latex")
               ;; Vendored TeX math-typesetting engine (see src/tex/README).
               ;; This is a local port of the sibling `typesetting' system;
               ;; the svg system deliberately does not depend on it at run
               ;; time, so `latex*' works on its own.
               (:file "src/tex/package")
               (:file "src/tex/scaled")
               (:file "src/tex/params")
               (:file "src/tex/math-style")
               (:file "src/tex/math-font")
               (:file "src/tex/mock-font")
               (:file "src/tex/env")
               (:file "src/tex/node")
               (:file "src/tex/pack")
               (:file "src/tex/delim")
               (:file "src/tex/math-spacing")
               (:file "src/tex/skew-kerns")
               (:file "src/tex/mlist")
               (:file "src/tex/glyph-paths")
               (:file "src/tex/render")
               (:file "src/tex/math-tree")
               (:file "src/tex/math-mode")
               (:file "src/latex-tables")
               (:file "src/latex-extra-glyph-paths")
               (:file "src/latex-star")
               (:file "src/plot")))
