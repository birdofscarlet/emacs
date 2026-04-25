;;; BIRDMACS ;;;

;; disables startupscreen
(setq inhibit-startup-screen t
      ring-bell-function 'ignore ;; ohhh my goooddd SHUT THE FUCK UUUUUPPPP
      use-short-answers t ;; y or n instead of yes or no
      ;; smooth scrolling
      scroll-step 1 ;; steppin on the beach do do do dooo
      scroll-conservatively 101
      display-line-numbers-type 'relative
      ;; prevents file system clutter
      create-lockfiles nil ;; GEEEEET OUT OF MY HOOOOOOUUUUSE
      backup-directory-alist `(("." . ,(concat user-emacs-directory "backups")))) ;; gay baby jail

;; use spaces for indentation and clean whitespace
(setq-default indent-tabs-mode nil
              tab-width 4
              indent-line-function 'insert-tab
              show-trailing-whitespace t)
(add-hook 'before-save-hook 'delete-trailing-whitespace)

;; theming
(load-theme 'modus-vivendi t)
(set-frame-parameter nil 'alpha-background 75)
(add-to-list 'default-frame-alist '(alpha-background . 75))


;; options to enable for better behavior
(electric-pair-mode 1) ;; auto pair parenthesis
(global-display-line-numbers-mode 1) ;; needed for relative line numbers
(recentf-mode 1) ;; recent files
(savehist-mode 1)
(save-place-mode 1)
(delete-selection-mode 1)
;; minibuffer behavior
(which-key-mode 1)
(fido-vertical-mode 1)
;; file navigation help
(global-auto-revert-mode 1)
(global-hl-line-mode 1)
(show-paren-mode 1)
(global-eldoc-mode 1)
;; clean the UI
(tool-bar-mode -1)
(menu-bar-mode -1)
(scroll-bar-mode -1)


; ---------------------------------- ;
;;             KEYBINDS             ;;
; ---------------------------------- ;

(global-set-key (kbd "<escape>") 'keyboard-escape-quit)

; ---------------------------------- ;
;;        PACKAGE MANAGEMENT        ;;
; ---------------------------------- ;

;; trying not to use too many packages but some stuff
;; i really would rather have and base emacs doesn't have it

(require 'package)
(setq package-archives
      '(("melpa" . "https://melpa.org/packages/")
        ("org"   . "https://orgmode.org/elpa/")
        ("elpa"  . "https://elpa.gnu.org/packages/")))

(package-initialize)
(unless package-archive-contents
  (package-refresh-contents))

;; for non linux
(unless (package-installed-p 'use-package)
  (package-install 'use-package))

(require 'use-package)
(setq use-package-always-ensure t)

;; discord
(use-package elcord)
(require 'elcord)
(elcord-mode)
(setq elcord-quiet t)

;; company
(use-package company)
(require 'company)
(company-mode)

(use-package company-box
  :hook (company-mode . company-box-mode))


;; powershell
(use-package powershell)
(require 'powershell)

;; TODO: can we get rid of this somehow

(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(elcord-editor-icon "emacs_pen_icon")
 '(elcord-idle-message "editing *real-life*")
 '(package-selected-packages '(company company-box elcord lsp-pwsh powershell)))
(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 )
