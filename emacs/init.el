;;; init.el --- BIRDMACS (clean + lint-safe) -*- lexical-binding: t; -*-

(defvar birdmacs-jangling-keys t
  "enable cosmetic extras like dashboard/modeline.")

;; ---------------------------------- ;;
;;         CORE CONFIGURATION         ;;
;; ---------------------------------- ;;

(setq image-dired-external-viewer "imv")

(setq inhibit-startup-screen t
      inhibit-startup-message t
      ring-bell-function 'ignore
      use-short-answers t
      scroll-step 1
      scroll-conservatively 101
      display-line-numbers-type 'relative
      create-lockfiles nil
      read-process-output-max (* 1024 1024)
      gc-cons-threshold (* 100 1024 1024)
      byte-compile-warnings '(not free-vars unresolved))

;; backups
(let ((backup-dir (expand-file-name "backups/" user-emacs-directory)))
  (unless (file-directory-p backup-dir)
    (make-directory backup-dir t))
  (setq backup-directory-alist `((".*" . ,backup-dir))))

;; UI cleanup
(tool-bar-mode -1)
(menu-bar-mode -1)
(scroll-bar-mode -1)

;; appearance
(load-theme 'modus-vivendi t)
(set-frame-parameter nil 'alpha-background 75)
(add-to-list 'default-frame-alist '(alpha-background . 75))

;; ---------------------------------- ;;
;;             BEHAVIOR               ;;
;; ---------------------------------- ;;

(electric-pair-mode 1)
(global-display-line-numbers-mode 1)
(global-hl-line-mode 1)
(show-paren-mode 1)
(global-eldoc-mode 1)
(global-auto-revert-mode 1)

(recentf-mode 1)
(savehist-mode 1)
(save-place-mode 1)
(delete-selection-mode 1)

(setq-default indent-line-function #'indent-for-tab-command)
(setq tab-always-indent 'complete)

;; keybinds
(global-set-key (kbd "<escape>") #'keyboard-escape-quit)
(global-set-key (kbd "M-/") #'completion-at-point)

;; hook
(add-hook 'prog-mode-hook
          (lambda ()
            (add-hook 'before-save-hook #'eglot-format-buffer nil t)))

(add-hook 'before-save-hook #'delete-trailing-whitespace)

(dolist (mode '(vterm-mode-hook
                term-mode-hook
                eshell-mode-hook
                shell-mode-hook))
  (add-hook mode (lambda () (display-line-numbers-mode -1))))

;; ---------------------------------- ;;
;;        PACKAGE MANAGEMENT          ;;
;; ---------------------------------- ;;

(require 'package)
(setq package-archives
      '(("melpa" . "https://melpa.org/packages/")
        ("org"   . "https://orgmode.org/elpa/")
        ("elpa"  . "https://elpa.gnu.org/packages/")))

(package-initialize)

(unless (package-installed-p 'use-package)
  (unless package-archive-contents
    (package-refresh-contents))
  (package-install 'use-package))

(require 'use-package)
(setq use-package-always-ensure t)

;; ---------------------------------- ;;
;;            PACKAGES                ;;
;; ---------------------------------- ;;

;; which-key
(use-package which-key
  :config
  (which-key-mode))

;; discord presence
(use-package elcord
  :init
  (setq elcord-quiet t
        elcord-editor-icon "emacs_pen_icon"
        elcord-idle-message "editing *real-life*")
  :config
  (elcord-mode 1)

  ;; prevent crash
  (advice-add 'elcord--start-idle :around
              (lambda (fn &rest args)
                (condition-case nil
                    (apply fn args)
                  (error nil))))

  ;; don't spam idle updates
  (setq elcord-idle-message nil))

;; ---------------------------------- ;;
;;         COMPLETION STUFF           ;;
;; ---------------------------------- ;;

;; vertico - minibuffer UI
(use-package vertico
  :init
  (vertico-mode)
  :custom
  (vertico-cycle t))

;; orderless - fuzzy matching
(use-package orderless
  :custom
  (completion-styles '(orderless basic))
  (completion-category-defaults nil)
  (completion-category-overrides
   '((file (styles partial-completion))
     (eglot (styles orderless)))))

;; marginalia - annotations
(use-package marginalia
  :init
  (marginalia-mode)
  :custom
  (marginalia-align 'right))

;; consult - search/navigation
(use-package consult
  :bind (("C-s" . consult-line)
         ("C-c b" . consult-buffer)
         ("C-c k" . consult-ripgrep)
	 ("C-x b" . consult-buffer))
  :custom
  (consult-preview-key '(:debounce 0.2 any)))

;; corfu - in-buffer completion
(use-package corfu
  :init
  (global-corfu-mode)

  :custom
  (corfu-auto t)
  (corfu-auto-delay 0.08)        ;; snappier
  (corfu-auto-prefix 1)
  (corfu-cycle t)
  (corfu-separator ?\s)

  ;; popup docs
  (corfu-popupinfo-delay 0.2)

  ;; nicer behavior
  (corfu-preselect 'prompt)      ;; don't auto-select first candidate

  :config
  ;; disable in minibuffer
  (add-hook 'minibuffer-setup-hook
            (lambda () (corfu-mode -1)))

  ;; enable docs
  (corfu-popupinfo-mode)

  (define-key corfu-map (kbd "M-SPC") #'corfu-insert-separator))

;; cape - extra completion sources
(use-package cape
  :init
(add-hook 'prog-mode-hook
          (lambda ()
            (add-hook 'completion-at-point-functions #'cape-file -10 t)))
(add-hook 'text-mode-hook
            (lambda ()
              (add-hook 'completion-at-point-functions #'cape-dabbrev nil t))))

;; powershell
(use-package powershell
  :mode ("\\.ps1\\'" . powershell-mode))

(use-package python
  :ensure nil
  :hook (python-mode . (lambda ()
                         (setq-local tab-width 4)
                         (setq-local indent-tabs-mode nil))))

(use-package eglot
  :hook ((python-mode
          powershell-mode
          scheme-mode
          c-mode
          c++-mode) . eglot-ensure)
  :custom
  (eglot-autoshutdown t)
  (eglot-events-buffer-size 0)
  :config
  (add-to-list 'eglot-server-programs
               '(python-mode . ("pyright-langserver" "--stdio"))))

;; inline diagnostics
(use-package flymake
  :ensure nil
  :hook (prog-mode . flymake-mode))

(with-eval-after-load 'flymake
  (global-set-key (kbd "C-c n") #'flymake-goto-next-error)
  (global-set-key (kbd "C-c p") #'flymake-goto-prev-error))

;; shiny icons
(use-package kind-icon
  :after corfu
  :custom
  (kind-icon-blend-background t)
  (kind-icon-default-face 'corfu-default)
  :config
  (add-to-list 'corfu-margin-formatters #'kind-icon-margin-formatter))

;; better word navigation (camelCase, etc.)
(use-package subword
  :ensure nil
  :hook (prog-mode . subword-mode))

(use-package magit
  :bind ("C-x g" . magit-status))

(use-package vterm
  :commands vterm
  :config
  ;; better scrolling
  (setq vterm-scrollback 5000)

  ;; don't ask on exit
  (setq vterm-kill-buffer-on-exit t)

  ;; fix common key annoyances
  (define-key vterm-mode-map (kbd "C-c C-j") #'vterm-copy-mode)
  (define-key vterm-copy-mode-map (kbd "C-c C-k") #'vterm-copy-mode))

;; quick open
(global-set-key (kbd "C-c t") #'vterm)

;; toggle like a dropdown terminal
(defun birdmacs/toggle-vterm ()
  (interactive)
  (if (get-buffer "*vterm*")
      (if (eq (current-buffer) (get-buffer "*vterm*"))
          (bury-buffer)
        (switch-to-buffer "*vterm*"))
    (vterm)))

(global-set-key (kbd "C-`") #'birdmacs/toggle-vterm)

(defun birdmacs/project-root ()
  (when-let ((proj (project-current)))
    (project-root proj)))

(defun birdmacs/vterm-project ()
  (interactive)
  (let ((default-directory
          (or (birdmacs/project-root)
              default-directory)))
    (vterm)))

(global-set-key (kbd "C-c T") #'birdmacs/vterm-project)

(defun birdmacs/vterm-run (cmd)
  (let ((buffer (get-buffer "*vterm*")))
    (unless buffer
      (setq buffer (vterm)))
    (with-current-buffer buffer
      (goto-char (point-max))
      (vterm-send-string cmd)
      (vterm-send-return))))

(defun birdmacs/run-python-file ()
  (interactive)
  (birdmacs/vterm-run
   (format "python %s"
           (shell-quote-argument (buffer-file-name)))))

(defun birdmacs/compile-project ()
  (interactive)
  (birdmacs/vterm-run "make"))

(global-set-key (kbd "C-c r") #'birdmacs/run-python-file)
(global-set-key (kbd "C-c m") #'birdmacs/compile-project)


;; ---------------------------------- ;;
;;           OOOH SHINY               ;;
;; ---------------------------------- ;;

(when birdmacs-jangling-keys
  (use-package mood-line
    :config (mood-line-mode))

  (use-package dashboard
    :init
    (setq dashboard-startup-banner 'official
          dashboard-center-content t
          dashboard-vertically-center-content t
          dashboard-items '((recents . 5)))
    :config
    (dashboard-setup-startup-hook))

  (with-eval-after-load 'dashboard
    (setq initial-buffer-choice
          (lambda ()
            (get-buffer "*dashboard*")))))

(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(package-selected-packages
   '(cape consult corfu dashboard elcord kind-icon magit marginalia
	  mood-line orderless powershell vertico vterm)))
(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 )
