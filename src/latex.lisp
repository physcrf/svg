(in-package #:svg)

(defvar *latex-tmp-dir* nil)
(defvar *latex-counter* 0)
(defvar *latex-packages* '("amsmath,amssymb" "physics"))

(defun init-latex-env ()
  "Initialize the LaTeX temporary directory if not already set."
  (unless *latex-tmp-dir*
    (setf *latex-tmp-dir* (uiop:ensure-directory-pathname
                           (merge-pathnames (format nil "svg-latex-~a-~a/"
                                                    (get-universal-time)
                                                    (random 1000000 (make-random-state t)))
                                            (uiop:temporary-directory))))
    (ensure-directories-exist *latex-tmp-dir*)))

(defun next-latex-id ()
  (incf *latex-counter*))

(defun set-latex-packages (&rest packages)
  (setf *latex-packages* packages))

(defun get-latex-packages ()
  *latex-packages*)

(defun write-latex-file (filename content)
  (with-open-file (stream filename :direction :output :if-exists :supersede)
    (format stream "\\documentclass[preview]{standalone}~%")
    (dolist (pkg *latex-packages*)
      (format stream "\\usepackage{~a}~%" pkg))
    (format stream "\\begin{document}~%~a~%\\end{document}~%" content)))

(defun run-latex-program (program &rest args)
  "Run PROGRAM with ARGS in the LaTeX temp directory. Returns T on success
   (exit code 0) and NIL on failure. If the executable cannot be started at
   all (e.g. the TeX toolchain is not installed), a warning is emitted instead
   of signalling, so a missing dependency never aborts SVG generation."
  (handler-case
      (= 0 (nth-value 2 (uiop:run-program (cons program args)
                                          :directory *latex-tmp-dir*
                                          :ignore-error-status t)))
    (error (e)
      (warn "Failed to run ~a: ~a" program e)
      nil)))

(defun compile-latex-to-dvi (tex-file)
  "Compile a .tex file to .dvi. Returns T on success."
  (run-latex-program "latex" "-interaction=nonstopmode" "-output-format=dvi"
                     (namestring tex-file)))

(defun convert-dvi-to-svg (dvi-file svg-file)
  "Convert a .dvi file to .svg using dvisvgm. Returns T on success."
  (run-latex-program "dvisvgm" "--no-fonts" "--exact" "-o"
                     (namestring svg-file) (namestring dvi-file)))

(defun extract-svg-inner (svg-file)
  "Extract the inner content of an SVG file (between <svg> tags)."
  (alexandria:when-let ((content (uiop:read-file-string svg-file)))
    (ppcre:register-groups-bind (inner)
        ("(?s)<svg[^>]*>(.*)</svg>" content)
      (str:trim inner))))

(defun cleanup-latex-files (id)
  "Remove temporary LaTeX files for the given ID."
  (when *latex-tmp-dir*
    (dolist (ext '("tex" "dvi" "svg" "aux" "log"))
      (let ((file (merge-pathnames (format nil "latex-~d.~a" id ext) *latex-tmp-dir*)))
        (ignore-errors (delete-file file))))))

(defun latex (position formula &rest attrs)
  "Render a LaTeX formula as SVG and embed it at POSITION.
   :SCALE keyword controls the scaling factor."
  (init-latex-env)

  (let* ((px (x position))
         (py (y position))
         (scale (getf attrs :scale))
         (clean-attrs (alexandria:remove-from-plist attrs :scale))
         (id (next-latex-id))
         (base-name (format nil "latex-~d" id))
         (tex-file (merge-pathnames (format nil "~a.tex" base-name) *latex-tmp-dir*))
         (dvi-file (merge-pathnames (format nil "~a.dvi" base-name) *latex-tmp-dir*))
         (svg-file (merge-pathnames (format nil "~a.svg" base-name) *latex-tmp-dir*)))

    (unwind-protect
         (progn
           (write-latex-file tex-file formula)
           (cond
             ((not (compile-latex-to-dvi tex-file))
              (warn "LaTeX compilation failed for formula: ~a" formula))
             ((not (convert-dvi-to-svg dvi-file svg-file))
              (warn "DVI to SVG conversion (dvisvgm) failed for formula: ~a" formula))
             (t
              (alexandria:when-let ((content (extract-svg-inner svg-file)))
                ;; Write the <g> with WRITE-RAW-ELEMENT because CONTENT is
                ;; pre-rendered SVG markup from dvisvgm that must not be
                ;; XML-escaped. We still go through merge-attributes /
                ;; process-transform-attributes so :translate/:scale and any
                ;; user transform keywords are folded consistently.
                (let ((final-attrs (append (list :translate (p px py))
                                           (when (and scale (plusp scale)) (list :scale scale))
                                           clean-attrs)))
                  (write-raw-element "g" final-attrs content))))))
      (cleanup-latex-files id))))
