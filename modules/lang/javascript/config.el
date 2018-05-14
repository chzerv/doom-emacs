;;; lang/javascript/config.el -*- lexical-binding: t; -*-

;;
;; Major modes
;;

(def-package! js2-mode
  :mode "\\.js\\'"
  :interpreter "node"
  :config
  (setq js2-skip-preprocessor-directives t
        js2-highlight-external-variables nil
        js-chain-indent t
        ;; let flycheck handle this
        js2-mode-show-parse-errors nil
        js2-mode-show-strict-warnings nil
        ;; Flycheck provides these features, so disable them: conflicting with
        ;; the eslint settings.
        js2-strict-trailing-comma-warning nil
        js2-strict-missing-semi-warning nil)

  (add-hook! 'js2-mode-hook #'(flycheck-mode rainbow-delimiters-mode))

  (set! :electric 'js2-mode :chars '(?\} ?\) ?. ?:))

  ;; Conform switch-case indentation to js2 normal indent
  (defvaralias 'js-switch-indent-offset 'js2-basic-offset)

  (sp-with-modes '(js2-mode rjsx-mode)
    (sp-local-pair "/*" "*/" :post-handlers '(("| " "SPC"))))

  (map! :map js2-mode-map
        :localleader
        :n  "S" #'+javascript/skewer-this-buffer))


(def-package! typescript-mode
  :commands typescript-mode
  :config
  (add-hook! 'typescript-mode-hook #'(flycheck-mode rainbow-delimiters-mode))
  (set! :electric 'typescript-mode
    :chars '(?\} ?\)) :words '("||" "&&")))


(def-package! rjsx-mode
  :commands rjsx-mode
  :mode "components/.+\\.js$"
  :init
  (defun +javascript-jsx-file-p ()
    "Detect React or preact imports early in the file."
    (and buffer-file-name
         (string= (file-name-extension buffer-file-name) "js")
         (re-search-forward "\\(^\\s-*import +React\\|\\( from \\|require(\\)[\"']p?react\\)"
                            magic-mode-regexp-match-limit t)
         (progn (goto-char (match-beginning 1))
                (not (sp-point-in-string-or-comment)))))

  (push '(+javascript-jsx-file-p . rjsx-mode) magic-mode-alist)
  :config
  (set! :electric 'rjsx-mode :chars '(?\} ?\) ?. ?>))
  (add-hook! 'rjsx-mode-hook
    ;; jshint doesn't know how to deal with jsx
    (push 'javascript-jshint flycheck-disabled-checkers))

  ;; `rjsx-electric-gt' relies on js2's parser to tell it when the cursor is in
  ;; a self-closing tag, so that it can insert a matching ending tag at point.
  ;; However, the parser doesn't run immediately, so a fast typist can outrun
  ;; it, causing issues, so force it to parse.
  (defun +javascript|reparse (n)
    ;; if n != 0, then rjsx-maybe-reparse will be run elsewhere
    (if (= n 0) (rjsx-maybe-reparse)))
  (advice-add #'rjsx-electric-gt :before #'+javascript|reparse))


(def-package! coffee-mode
  :defer t  ; file extensions registered by autoloads file
  :init (setq coffee-indent-like-python-mode t))


;;
;; Tools
;;

(def-package! tide
  :hook (js2-mode . tide-setup)
  :hook (typescript-mode . tide-setup)
  :init
  (defun +javascript|init-tide-in-web-mode ()
    (when (string= (file-name-extension (or buffer-file-name "")) "tsx")
      (tide-setup)))
  (add-hook 'web-mode-hook #'+javascript|init-tide-in-web-mode)
  :config
  (setq tide-completion-detailed t
        tide-always-show-documentation t)
  ;; code completion
  (after! company
    ;; tide affects the global `company-backends', undo this so doom can handle
    ;; it buffer-locally
    (setq-default company-backends (delq 'company-tide (default-value 'company-backends))))
  (set! :company-backend 'tide-mode 'company-tide)

  ;; navigation
  (set! :lookup 'tide-mode
    :definition #'tide-jump-to-definition
    :references #'tide-references
    :documentation #'tide-documentation-at-point)

  ;; resolve to `doom-project-root' if `tide-project-root' fails
  (advice-add #'tide-project-root :override #'+javascript*tide-project-root)

  ;; cleanup tsserver when no tide buffers are left
  (add-hook! 'tide-mode-hook
    (add-hook 'kill-buffer-hook #'+javascript|cleanup-tide-processes nil t))

  (def-menu! +javascript/refactor-menu
    "Refactoring commands for `js2-mode' buffers."
    '(("Restart tsserver"                :exec tide-restart-server   :when (bound-and-true-p tide-mode))
      ("Reformat buffer/region (tide)"   :exec tide-reformat         :when (bound-and-true-p tide-mode))
      ("Organize imports"                :exec tide-organize-imports :when (bound-and-true-p tide-mode))
      ("Rename symbol"                   :exec tide-rename-symbol    :when (bound-and-true-p tide-mode) :region nil)
      ("Reformat buffer (eslint_d)"      :exec eslintd-fix           :when (bound-and-true-p eslintd-fix-mode) :region nil)
      ("Extract into function"           :exec js2r-extract-function          :region t)
      ("Extract into method"             :exec js2r-extract-method            :region t)
      ("Introduce parameter to function" :exec js2r-introduce-parameter       :region t)
      ("Localize parameter"              :exec js2r-localize-parameter        :region nil)
      ("Expand object"                   :exec js2r-expand-object             :region nil)
      ("Expand function"                 :exec js2r-expand-function           :region nil)
      ("Expand array"                    :exec js2r-expand-array              :region nil)
      ("Contract object"                 :exec js2r-contract-object           :region nil)
      ("Contract function"               :exec js2r-contract-function         :region nil)
      ("Contract array"                  :exec js2r-contract-array            :region nil)
      ("Wrap buffer in IIFE"             :exec js2r-wrap-buffer-in-iife       :region nil)
      ("Inject global into IIFE"         :exec js2r-inject-global-in-iife     :region t)
      ("Add to globals annotation"       :exec js2r-add-to-globals-annotation :region nil)
      ("Extract variable"                :exec js2r-extract-var               :region t)
      ("Inline variable"                 :exec js2r-inline-var                :region t)
      ("Rename variable"                 :exec js2r-rename-var                :region nil)
      ("Replace var with this"           :exec js2r-var-to-this               :region nil)
      ("Arguments to object"             :exec js2r-arguments-to-object       :region nil)
      ("Ternary to if"                   :exec js2r-ternary-to-if             :region nil)
      ("Split var declaration"           :exec js2r-split-var-declaration     :region nil)
      ("Split string"                    :exec js2r-split-string              :region nil)
      ("Unwrap"                          :exec js2r-unwrap                    :region t)
      ("Log this"                        :exec js2r-log-this)
      ("Debug this"                      :exec js2r-debug-this))
    :prompt "Refactor: ")

  (map! :map tide-mode-map
        :localleader
        :n "r" #'+javascript/refactor-menu))


(def-package! xref-js2
  :when (featurep! :feature lookup)
  :commands xref-js2-xref-backend
  :init (set! :lookup 'js2-mode :xref-backend #'xref-js2-xref-backend))


(def-package! nodejs-repl
  :commands nodejs-repl
  :init
  (set! :repl 'js2-mode #'+javascript/repl))


(def-package! js2-refactor
  :commands
  (js2r-extract-function js2r-extract-method js2r-introduce-parameter
   js2r-localize-parameter js2r-expand-object js2r-contract-object
   js2r-expand-function js2r-contract-function js2r-expand-array
   js2r-contract-array js2r-wrap-buffer-in-iife js2r-inject-global-in-iife
   js2r-add-to-globals-annotation js2r-extract-var js2r-inline-var
   js2r-rename-var js2r-var-to-this js2r-arguments-to-object js2r-ternary-to-if
   js2r-split-var-declaration js2r-split-string js2r-unwrap js2r-log-this
   js2r-debug-this js2r-forward-slurp js2r-forward-barf))


(def-package! web-beautify
  :commands web-beautify-js
  :init
  (map! :map* (json-mode js2-mode-map) :n "gQ" #'web-beautify-js))


(def-package! eslintd-fix
  :commands (eslintd-fix-mode eslintd-fix)
  :config
  (defun +javascript|set-flycheck-executable-to-eslint ()
    (setq flycheck-javascript-eslint-executable eslintd-fix-executable))
  (add-hook 'eslintd-fix-mode-hook #'+javascript|set-flycheck-executable-to-eslint))


(def-package! skewer-mode
  :commands (skewer-mode run-skewer)
  :config
  (map! :map skewer-mode-map
        :localleader
        :n "sE" #'skewer-eval-last-expression
        :n "se" #'skewer-eval-defun
        :n "sf" #'skewer-load-buffer))


(def-package! skewer-css ; in skewer-mode
  :commands skewer-css-mode
  :config
  (map! :map skewer-css-mode-map
        :localleader
        :n "se" #'skewer-css-eval-current-declaration
        :n "sr" #'skewer-css-eval-current-rule
        :n "sb" #'skewer-css-eval-buffer
        :n "sc" #'skewer-css-clear-all))


(def-package! skewer-html ; in skewer-mode
  :commands skewer-html-mode
  :config
  (map! :map skewer-html-mode-map
        :localleader
        :n "se" #'skewer-html-eval-tag))


(def-package! skewer-repl
  :commands skewer-repl)


;;
;; Projects
;;

(def-project-mode! +javascript-screeps-mode
  :match "/screeps\\(-ai\\)?/.+$"
  :modes (+javascript-npm-mode)
  :add-hooks (+javascript|init-screeps-mode)
  :on-load (load! +screeps))

(def-project-mode! +javascript-gulp-mode
  :files "gulpfile.js")

(def-project-mode! +javascript-npm-mode
  :modes (html-mode css-mode web-mode js2-mode markdown-mode)
  :files "package.json"
  :add-hooks (+javascript|add-node-modules-path))

