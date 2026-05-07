(in-package #:svg)

(defun text (position content &rest attrs &key &allow-other-keys)
  (write-element "text"
                (append (list 'x (x position) 'y (y position)) attrs)
                content))

(defun tspan (content &rest attrs &key &allow-other-keys)
  (let ((position (getf attrs :position))
        (dx (getf attrs :dx))
        (dy (getf attrs :dy))
        (rotate (getf attrs :rotate)))
    (write-element "tspan"
                  (append (when position (list 'x (x position) 'y (y position)))
                          (when dx (list 'dx dx))
                          (when dy (list 'dy dy))
                          (when rotate (list 'rotate rotate))
                          (alexandria:remove-from-plist attrs :position :dx :dy :rotate))
                  content)))
