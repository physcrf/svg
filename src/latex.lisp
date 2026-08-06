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
                                                    (random 1000000))
                                            (uiop:temporary-directory))))))

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

(defun compile-latex-to-dvi (tex-file)
  "Compile a .tex file to .dvi. Returns T on success."
  (= 0 (nth-value 2 (uiop:run-program
                     (list "latex" "-interaction=nonstopmode" "-output-format=dvi"
                           (file-namestring tex-file))
                     :directory *latex-tmp-dir*
                     :ignore-error-status t))))

(defun convert-dvi-to-svg (dvi-file svg-file)
  "Convert a .dvi file to .svg using dvisvgm. Returns T on success."
  (= 0 (nth-value 2 (uiop:run-program
                     (list "dvisvgm" "--no-fonts" "--exact" "-o"
                           (namestring svg-file) (namestring dvi-file))
                     :directory *latex-tmp-dir*
                     :ignore-error-status t))))

(defun extract-svg-inner (svg-file)
  "Extract the inner content of an SVG file (between <svg> tags)."
  (alexandria:when-let ((content (uiop:read-file-string svg-file)))
    (ppcre:register-groups-bind (inner)
        ("(?s)<svg[^>]*>(.+)</svg>" content)
      (str:trim inner))))

(defun cleanup-latex-files (id)
  "Remove temporary LaTeX files for the given ID."
  (dolist (ext '("tex" "dvi" "svg" "aux" "log"))
    (let ((file (merge-pathnames (format nil "latex-~d.~a" id ext) *latex-tmp-dir*)))
      (ignore-errors (delete-file file)))))

(defun latex (position formula &rest attrs)
  "Render a LaTeX formula as SVG and embed it at POSITION.
   :SCALE keyword controls the scaling factor."
  (init-latex-env)
  (ensure-directories-exist *latex-tmp-dir*)

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
                ;; Write the <g> directly (not via write-element) because CONTENT
                ;; is pre-rendered SVG markup from dvisvgm that must not be
                ;; XML-escaped. We still go through merge-attributes /
                ;; process-transform-attributes so :translate/:scale and any
                ;; user transform keywords are folded consistently.
                (let* ((stream (current-stream))
                       (final-attrs (append (list :translate (p px py))
                                            (when scale (list :scale scale))
                                            clean-attrs))
                       (processed (process-transform-attributes
                                   (merge-attributes final-attrs))))
                  (format stream "  <g ")
                  (write-attributes stream processed)
                  (format stream ">~a</g>~%" content))))))
      (cleanup-latex-files id))))
