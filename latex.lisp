(in-package #:svg)

(defvar *latex-tmp-dir* nil)
(defvar *latex-counter* 0)
(defvar *latex-packages* '("amsmath,amssymb" "physics"))

(defun init-latex-env ()
  (unless *latex-tmp-dir*
    (let ((pid (str:trim (uiop:run-program "echo $$" :output :string))))
      (setf *latex-tmp-dir* (uiop:ensure-directory-pathname
                             (format nil "/tmp/svg-latex-~a/" pid))))))

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
  (let ((cmd (format nil "cd ~a && latex -interaction=nonstopmode -output-format=dvi ~a > /dev/null 2>&1"
                     (namestring *latex-tmp-dir*)
                     (file-namestring tex-file))))
    (nth-value 2 (uiop:run-program cmd :shell t :ignore-error-status t))))

(defun convert-dvi-to-svg (dvi-file svg-file)
  (let ((cmd (format nil "dvisvgm --no-fonts --exact -o ~a ~a"
                     (namestring svg-file)
                     (namestring dvi-file))))
    (nth-value 2 (uiop:run-program cmd :shell t :ignore-error-status t))))

(defun extract-svg-inner (svg-file)
  (alexandria:when-let ((content (uiop:read-file-string svg-file)))
    (ppcre:register-groups-bind (inner)
        ("(?s)<svg[^>]*>(.+)</svg>" content)
      (str:trim inner))))

(defun cleanup-latex-files (id)
  (dolist (ext '("tex" "dvi" "svg" "aux" "log"))
    (let ((file (merge-pathnames (format nil "latex-~d.~a" id ext) *latex-tmp-dir*)))
      (ignore-errors (delete-file file)))))

(defun latex (position formula &rest attrs)
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
           (when (and (compile-latex-to-dvi tex-file)
                      (convert-dvi-to-svg dvi-file svg-file))
             (alexandria:when-let ((content (extract-svg-inner svg-file)))
               (let* ((transform (if scale
                                     (format nil "translate(~a,~a) scale(~a)" (fmt px) (fmt py) scale)
                                     (format nil "translate(~a,~a)" (fmt px) (fmt py))))
                      (final-attrs (append (list :transform transform) clean-attrs))
                      (attrs-str (serialize-attributes final-attrs)))
                 (format (if *svg* (svg-stream *svg*) *standard-output*)
                         "  <g ~a>~a</g>~%"
                         attrs-str content)))))
      (cleanup-latex-files id))))
