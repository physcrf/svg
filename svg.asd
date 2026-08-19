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
               (:file "src/plot")))
