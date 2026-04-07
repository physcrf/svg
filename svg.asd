(asdf:defsystem #:svg
  :description "SVG generation library for Common Lisp with LaTeX support"
  :version "0.3.0"
  :depends-on (:alexandria :cl-ppcre :str :trivia)
  :serial t
  :components ((:file "package")
               (:file "utils")
               (:file "core")
               (:file "attributes")
               (:file "shapes")
               (:file "text")
               (:file "path")
               (:file "latex")
               (:file "marker")))
