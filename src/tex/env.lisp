(in-package :svg-tex)

(defstruct typesetting-env
  (font nil :type (or null math-font))
  (math-style display-style :type math-style)
  (math-fonts nil :type (or null (simple-array t (*))))
  (parameters (make-hash-table :test 'eq)))

(defun make-env (&key (font nil) (style display-style) (fonts nil))
  (make-typesetting-env :font font
                        :math-style style
                        :math-fonts (or fonts (make-default-fonts))))

(defun env-font (env)
  "Return the env's current (text) math-font, or nil."
  (typesetting-env-font env))

(defun env-math-style (env)
  "Return the env's current math style (one of display-style / text-style /
script-style / ... — see math-style.lisp)."
  (typesetting-env-math-style env))

(defun env-math-fonts (env)
  "Return the env's math-font vector (the 16-element array produced by
make-default-fonts)."
  (typesetting-env-math-fonts env))

(defun env-math-font (env family)
  (let ((fonts (typesetting-env-math-fonts env)))
    (when fonts
      (aref fonts (min family 15)))))

(defun env-with-style (env style)
  (make-typesetting-env :font (typesetting-env-font env)
                        :math-style style
                        :math-fonts (typesetting-env-math-fonts env)
                        :parameters (typesetting-env-parameters env)))

(defun env-with-font (env font)
  (make-typesetting-env :font font
                        :math-style (typesetting-env-math-style env)
                        :math-fonts (typesetting-env-math-fonts env)
                        :parameters (typesetting-env-parameters env)))

(defun env-set-param (env key value)
  (setf (gethash key (typesetting-env-parameters env)) value))

(defun env-get-param (env key &optional default)
  (gethash key (typesetting-env-parameters env) default))

(defun env-mu-width (env)
  (let ((font (env-math-font env 0)))
    (if font (math-font-mu-width font) 65536)))

(defun env-current-cramped-style (env)
  (math-style-cramped (typesetting-env-math-style env)))

(defun env-with-display-style (env)
  (env-with-style env display-style))

(defun env-with-text-style (env)
  (env-with-style env text-style))

(defun env-with-script-style (env)
  (env-with-style env script-style))

(defun env-with-script-script-style (env)
  (env-with-style env script-script-style))