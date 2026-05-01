;;; init.el --- BIRDMACS (refactored) -----------------------------

(defvar birdmacs-jangling-keys t
  "enable cosmetic extras like dashboard/modeline.")

;; ---------------------------------- ;;
;;         CORE CONFIGURATION         ;;
;; ---------------------------------- ;;

(setq inhibit-startup-screen t
      inhibit-startup-message t
      ring-bell-function 'ignore
      use-short-answers t
      scroll-step 1
      scroll-conservatively 101
      display-line-numbers-type 'relative
      create-lockfiles nil)

;; backups
(let ((backup-dir (expand-file-name "backups/" user-emacs-directory)))
  (unless (file-directory-p backup-dir)
    (make-directory backup-dir t))
  (setq backup-directory-alist `(("." . ,backup-dir))))

(add-hook 'before-save-hook #'delete-trailing-whitespace)

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

;; keybinds
(global-set-key (kbd "<escape>") #'keyboard-escape-quit)
(setq-default indent-line-function #'indent-for-tab-command)
(setq tab-always-indent 'complete)

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
  (corfu-auto-delay 0.12)
  (corfu-auto-prefix 1)
  (corfu-cycle t)
  (corfu-separator ?\s)
  :config
  (add-hook 'minibuffer-setup-hook
            (lambda () (corfu-mode -1)))
  (corfu-popupinfo-mode))

;; cape - extra completion sources
(use-package cape
  :init
  (add-hook 'completion-at-point-functions #'cape-file t)
  (add-hook 'text-mode-hook
            (lambda ()
              (add-hook 'completion-at-point-functions #'cape-dabbrev nil t))))

;; powershell
(use-package powershell
  :mode ("\\.ps1\\'" . powershell-mode))

;; eglot
(use-package eglot
  :hook ((python-mode
          powershell-mode
          scheme-mode
          c-mode
          c++-mode) . eglot-ensure)
  :custom
  (eglot-autoshutdown t)
  (eglot-events-buffer-size 0))

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

;; ---------------------------------- ;;
;;           OOOH SHINY               ;;
;; ---------------------------------- ;;

(when birdmacs-jangling-keys
  ;; modeline
  (use-package mood-line
    :config
    (mood-line-mode)))
