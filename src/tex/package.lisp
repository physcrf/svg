;;;; package.lisp — the single :svg-tex package (vendored TeX engine)
;;;;
;;;; The public API follows tex.web's structure: a node/mem model (node.lisp),
;;;; box packing (pack.lisp), variable delimiters (delim.lisp), mlist_to_hlist
;;;; and its helpers (mlist.lisp), plus a thin front end (math-tree / math-mode)
;;;; and the SVG renderer (render.lisp).

(defpackage :svg-tex
  (:use :cl)
  (:export
   ;; === scaled fixed-point arithmetic ===
   #:+scaled-one+ #:+scaled-point+ #:+scaled-bp+ #:+scaled-zero+
   #:*scaled-base* #:*scaled-base-f*
   #:scaled #:scaledp
   #:scaled+ #:scaled- #:scaled* #:scaled/ #:scaled-abs
   #:scaled-= #:scaled-< #:scaled-> #:scaled-<= #:scaled->=
   #:scaled-max #:scaled-min #:scaled-half
   #:scaled-from-pt #:scaled-to-pt #:scaled-from-bp #:scaled-to-bp
   #:scaled-from-sp #:scaled-to-sp #:scaled-from-fix #:scaled-wrap

   ;; === named math font parameters (fontdimens) ===
   #:+param-num1+ #:+param-num2+ #:+param-num3+
   #:+param-denom1+ #:+param-denom2+
   #:+param-sup1+ #:+param-sup2+ #:+param-sup3+
   #:+param-sub1+ #:+param-sub2+
   #:+param-sup-drop+ #:+param-sub-drop+
   #:+param-delim1+ #:+param-delim2+
   #:+param-axis-height+ #:+param-default-rule-thickness+
   #:+param-big-op-spacing1+ #:+param-big-op-spacing2+
   #:+param-big-op-spacing3+ #:+param-big-op-spacing4+ #:+param-big-op-spacing5+
   #:+param-x-height+ #:+param-quad+
   #:+script-space+ #:+null-delimiter-space+
   #:+delimiter-factor+ #:+delimiter-shortfall+
   #:*font-param-count* #:*math-family-count* #:tex-half

   ;; === math style (tex.web display/text/script/scriptscript) ===
   #:display-style #:cramped-display-style #:text-style #:cramped-text-style
   #:script-style #:cramped-script-style
   #:script-script-style #:cramped-script-script-style
   #:text-size #:script-size #:script-script-size
   #:math-style-p #:math-style-cramped-p #:math-style-display-p
   #:math-style-script-p #:math-style-script-script-p
   #:math-style-size-code #:math-style-cramped #:math-style-uncramped
   #:math-style-sub-style #:math-style-sup-style
   #:math-style-num-style #:math-style-denom-style #:math-style-name
   #:math-style-nonscript-p

   ;; === math fonts ===
   #:math-font #:math-font-p #:make-math-font
   #:math-font-family #:math-font-name #:math-font-params
   #:math-font-param #:math-font-param-family #:math-font-param-at-size
   #:math-font-style-param #:math-font-x-height #:font-x-height #:set-math-font-param
   #:math-font-char-width #:math-font-char-height #:math-font-char-depth
   #:math-font-char-italic #:math-font-char-exists-p #:math-font-get-char
   #:math-font-char-extensible-p #:math-font-char-extensible-parts
   #:math-font-char-larger-variant #:math-font-char-smaller-variant
   #:math-font-skew-char #:math-font-default-rule-thickness
   #:math-font-axis-height #:math-font-x-height #:math-font-math-quad
   #:math-font-mu-width #:math-font-size #:math-font-design-size
   #:math-font-for #:math-font-get-next-larger
   #:make-cmr-font #:make-cmmi-font #:make-cmsy-font #:make-cmex-font
   #:copy-math-pars #:make-default-fonts

   ;; === nodes (tex.web memory_word) ===
   #:node #:node-p #:make-glue-spec
   #:n-type #:n-subtype #:n-link #:n-info
   #:n-width #:n-height #:n-depth #:n-shift #:n-list
   #:n-glue #:n-glue-sign #:n-glue-order #:n-glue-set
   #:n-font #:n-character #:n-penalty
   #:n-nucleus #:n-supscr #:n-subscr #:n-index
   #:n-thickness #:n-numerator #:n-denominator
   #:n-left-delimiter #:n-right-delimiter #:n-accent-chr #:n-new-hlist
   #:+null-flag+ #:is-running
   #:+normal+ #:+fil+ #:+fill+ #:+filll+
   #:+glue-normal+ #:+stretching+ #:+shrinking+
   #:+exactly+ #:+additional+ #:+max-dimen+ #:+ss-glue+
   #:glue-spec #:glue-width #:glue-stretch #:glue-shrink
   #:glue-stretch-order #:glue-shrink-order #:copy-glue-spec
   #:new-hlist #:new-vlist #:new-rule #:new-glue #:new-kern #:new-char
   #:new-penalty #:new-style #:new-noad
   #:char-node-p #:box-node-p #:glue-node-p #:kern-node-p #:rule-node-p
   #:style-node-p #:penalty-node-p #:noad-p #:scripts-allowed-p
   #:noad-type-index #:noad-type-name #:last-node #:append-node-list
   #:nl-reverse #:nl-append #:nl

   ;; === math fields / chars / delimiters ===
   #:field #:field-type #:field-value
   #:make-empty-field #:make-math-char-field #:make-math-text-char-field
   #:make-sub-box-field #:make-sub-mlist-field
   #:field-empty-p #:field-math-char-p #:field-math-char #:field-box #:field-mlist
   #:mchar #:make-mchar #:mc-family #:mc-code
   #:delimiter #:delim-small-family #:delim-small-char
   #:delim-large-family #:delim-large-char
   #:make-delimiter #:null-delimiter #:null-delimiter-p

   ;; === noad constructors ===
   #:ord-noad #:op-noad #:bin-noad #:rel-noad #:open-noad #:close-noad
   #:punct-noad #:inner-noad
   #:make-fraction-noad #:make-radical-noad #:make-accent-noad
   #:left-noad #:right-noad
   #:make-over-noad #:make-under-noad #:make-vcenter-noad #:make-matrix-noad

   ;; === packing (tex.web hpack / vpackage) ===
   #:hpack #:vpack #:vpackage #:rebox #:char-box #:overbar #:fraction-rule
   #:glue-width-in-box #:free-node
   #:char-width-of #:char-height-of #:char-depth-of #:char-italic-of
   #:char-exists-of #:font-char-tag #:font-rem-byte #:height-plus-depth

   ;; === variable delimiters ===
   #:var-delimiter #:make-null-delimiter-box

   ;; === math spacing table ===
   #:*math-spacing-classes* #:*math-spacing-codes*
   #:math-spacing-code #:spacing-class-index #:spacing-code->glue-mu
   #:compute-math-spacing #:compute-math-spacing-mu #:mu-glue

   ;; === mlist_to_hlist ===
   #:mlist-to-hlist #:mlist-to-box #:clean-box #:fetch
   #:make-fraction #:make-radical #:make-math-accent #:make-op #:make-ord
   #:make-scripts #:make-over #:make-under #:make-vcenter #:make-left-right
   #:make-matrix
   #:*cur-style* #:*cur-size* #:*cur-mu* #:*fonts*
   #:+inf-penalty+ #:+bin-op-penalty+ #:+rel-penalty+

   ;; === environment ===
   #:typesetting-env #:make-env
   #:env-font #:env-math-style #:env-math-fonts #:env-math-font
   #:env-with-style #:env-with-font #:env-set-param #:env-get-param
   #:env-mu-width #:env-current-cramped-style

   ;; === math tree front end ===
   #:math-tree #:math-tree-label #:math-tree-children
   #:make-math-tree #:make-math-char-tree
   #:make-subscript-tree #:make-superscript-tree
   #:make-fraction-tree #:make-radical-tree #:make-operator-tree
   #:make-accent-tree #:make-over-tree #:make-under-tree
   #:make-delimited-tree #:make-matrix-tree #:make-binomial-tree
   #:math-tree-single-math-char #:math-tree-to-delimiter
   #:math-tree-to-mlist #:typeset-math-tree

   ;; === math builder ===
   #:math-builder #:make-math-builder #:with-math-builder
   #:builder-add-noad #:builder-add-char #:builder-add-fraction
   #:builder-add-radical #:builder-add-subscript #:builder-add-superscript
   #:builder-add-left-delimiter #:builder-add-right-delimiter
   #:builder-add-accent #:builder-add-matrix
   #:builder-mlist #:builder-env #:typeset-math

   ;; === rendering ===
   #:render-to-svg #:render-to-string))
