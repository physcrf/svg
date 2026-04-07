(ql:quickload :svg :silent t)

(in-package #:svg)

(defun test-latex ()
  (format t "~%=== Test LaTeX ===~%")
  
  (with-svg ("test/test-latex.svg" 500 300)
    
    (format t "--- Test 1: Simple formula ---~%")
    (rect (p 0 0) 500 300 :fill "white" :stroke "none")
    (text (p 50 30) "Simple formula:" :font-size 14 :fill "black")
    (latex (p 50 50) "$E = mc^2$")
    
    (format t "--- Test 2: Integral ---~%")
    (text (p 50 90) "Integral:" :font-size 14 :fill "black")
    (latex (p 50 110) "$\\int_0^\\infty e^{-x^2} dx = \\frac{\\sqrt{\\pi}}{2}$" :scale 0.8)
    
    (format t "--- Test 3: Sum ---~%")
    (text (p 50 150) "Sum:" :font-size 14 :fill "black")
    (latex (p 50 170) "$\\sum_{i=1}^{n} x_i^2$" :scale 0.9)
    
    (format t "--- Test 4: Matrix ---~%")
    (text (p 50 210) "Matrix:" :font-size 14 :fill "black")
    (latex (p 50 230) "$\\begin{pmatrix} a & b \\\\ c & d \\end{pmatrix}$" :scale 0.8)
    
    (format t "--- Test 5: Greek letters ---~%")
    (text (p 250 30) "Greek letters:" :font-size 14 :fill "black")
    (latex (p 250 50) "$\\alpha, \\beta, \\gamma, \\delta, \\epsilon$" :scale 0.8)
    
    (format t "--- Test 6: Maxwell equations ---~%")
    (text (p 250 90) "Maxwell equations:" :font-size 14 :fill "black")
    (latex (p 250 110) "$\\nabla \\times \\vec{E} = -\\frac{\\partial \\vec{B}}{\\partial t}$" :scale 0.7)
    
    (format t "--- Test 7: Fraction ---~%")
    (text (p 250 150) "Fraction:" :font-size 14 :fill "black")
    (latex (p 250 170) "$\\frac{1}{1+\\frac{1}{x}}$" :scale 0.9)
    
    (format t "--- Test 8: Square root ---~%")
    (text (p 250 210) "Square root:" :font-size 14 :fill "black")
    (latex (p 250 230) "$\\sqrt{x^2 + y^2} = r$" :scale 0.9))
  
  (format t "~%=== Test Completed ===~%")
  (format t "Output: test/test-latex.svg~%"))

(test-latex)
