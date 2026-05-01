(in-package #:svg)

(defvar *latex-tmp-dir* nil)
(defvar *latex-counter* 0)
(defvar *latex-packages* '("amsmath,amssymb" "physics"))

(defun init-latex-env ()
  (unless *latex-tmp-dir*
    (setf *latex-tmp-dir* (pathname (format nil "/tmp/svg-latex-~a/"
                                            (parse-integer
                                             (uiop:run-program "echo $$" :output :string)))))))

(defun reset-latex-counter ()
  (setf *latex-counter* 0))

(defun next-latex-id ()
  (incf *latex-counter*)
  *latex-counter*)

(defun set-latex-packages (&rest packages)
  (setf *latex-packages* packages))

(defun get-latex-packages ()
  *latex-packages*)

(defun write-latex-file (filename content)
  (with-open-file (stream filename :direction :output :if-exists :supersede)
    (format stream "\\documentclass[preview]{standalone}~%")
    (dolist (pkg *latex-packages*)
      (format stream "\\usepackage{~a}~%" pkg))
    (format stream "\\begin{document}~%")
    (format stream "~a~%" content)
    (format stream "\\end{document}~%")))

(defun compile-latex-to-dvi (tex-file dvi-file)
  (declare (ignore dvi-file))
  (let ((cmd (format nil "cd ~a && latex -interaction=nonstopmode -output-format=dvi ~a > /dev/null 2>&1"
                     (namestring *latex-tmp-dir*)
                     (file-namestring tex-file))))
    (nth-value 2 (uiop:run-program cmd :shell t :ignore-error-status t))))

(defun convert-dvi-to-svg (dvi-file svg-file)
  (let ((cmd (format nil "dvisvgm --no-fonts --exact -o ~a ~a"
                     (namestring svg-file)
                     (namestring dvi-file))))
    (nth-value 2 (uiop:run-program cmd :shell t :ignore-error-status t))))

(defun extract-svg-content (svg-file)
  (str:trim (uiop:read-file-string svg-file)))

(defun parse-svg-element (svg-content)
  (ppcre:register-groups-bind (content)
      ("(?s)<svg[^>]*>(.+?)</svg>" svg-content)
    content))

(defun remove-svg-wrapper (svg-content)
  (when svg-content
    (ppcre:register-groups-bind (inner)
        ("(?s)<svg[^>]*>(.+)</svg>" svg-content)
      (str:trim inner))))

(defun adjust-position (svg-content x y)
  (declare (ignore x y))
  svg-content)

(defun latex (position formula &rest attrs)
  (init-latex-env)

  (ensure-directories-exist *latex-tmp-dir*)

  (let* ((px (x position))
         (py (y position))
         (scale (getf attrs :scale))
         (clean-attrs (remove-from-plist attrs :scale))
         (id (next-latex-id))
         (base-name (format nil "latex-~d" id))
         (tex-file (merge-pathnames (format nil "~a.tex" base-name) *latex-tmp-dir*))
         (dvi-file (merge-pathnames (format nil "~a.dvi" base-name) *latex-tmp-dir*))
         (svg-file (merge-pathnames (format nil "~a.svg" base-name) *latex-tmp-dir*)))

    (unwind-protect
         (progn
           (write-latex-file tex-file formula)

           (if (and (compile-latex-to-dvi tex-file dvi-file)
                    (convert-dvi-to-svg dvi-file svg-file))
               (let* ((raw-svg (extract-svg-content svg-file))
                      (inner-content (remove-svg-wrapper raw-svg))
                      (adjusted-content (adjust-position inner-content px py)))
                 (if adjusted-content
                     (let* ((scale-str (if scale
                                           (format nil "scale(~a)" scale)
                                           nil))
                            (transform-attr (if scale
                                                (format nil "translate(~a,~a) ~a" (fmt px) (fmt py) scale-str)
                                                (format nil "translate(~a,~a)" (fmt px) (fmt py))))
                            (final-attrs (append (list :transform transform-attr) clean-attrs))
                            (attrs-str (serialize-attributes final-attrs)))
                       (format (if *svg* (svg-stream *svg*) *standard-output*)
                               "  <g ~a>~a</g>~%"
                               attrs-str adjusted-content))
                     (warn "Failed to process LaTeX: ~a" formula)))
               (warn "LaTeX compilation failed for: ~a" formula)))

      (cleanup-latex-files id))))

(defun cleanup-latex-files (&optional id)
  (when id
    (let ((pattern (format nil "latex-~d.*" id)))
      (dolist (file (directory (merge-pathnames pattern *latex-tmp-dir*)))
        (ignore-errors (delete-file file))))))

(defun cleanup-all-latex ()
  (when (and *latex-tmp-dir* (probe-file *latex-tmp-dir*))
    (ignore-errors (uiop:delete-directory-tree *latex-tmp-dir* :validate t)))
  (setf *latex-tmp-dir* nil)
  (reset-latex-counter))

(defmacro with-latex-env (&body body)
  `(unwind-protect
       (progn
         (init-latex-env)
         ,@body)
     (cleanup-all-latex)))
