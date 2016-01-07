;;; mail-pack.el --- A `pack` to setup your email accounts through a ~/.authinfo(.gpg) credentials file

;; Copyright (C) 2014 Antoine R. Dumont <eniotna.t AT gmail.com>

;; Maintainer: Antoine R. Dumont <eniotna.t AT gmail.com>
;; Configuration
;; URL: https://github.com/ardumont/mail-pack
;; Version: 0.0.1
;; Keywords: emails offlineimap mu4e configuration
;; URL: https://github.com/ardumont/mail-pack

;; This file is NOT part of GNU Emacs.

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 3, or (at your option)
;; any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING. If not, write to the
;; Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
;; Boston, MA 02110-1301, USA.

;;; Commentary:

;; A `pack` to setup your email accounts through a ~/.authinfo(.gpg) credentials file
;;
;; Enjoy!
;;
;; More informations on https://github.com/ardumont/mail-pack

;;; Code:


(require 'install-packages-pack)
(install-packages-pack/install-packs '(s
                                       dash
                                       creds
                                       offlineimap
                                       async))

;; Internal libs
(require 'gnus)
(require 'epa-file)


;; External libs - installed from marmalade/melpa
(require 'creds)
(require 'dash)
(require 's)


(setq epa-file-cache-passphrase-for-symmetric-encryption t)



;; spell check
(add-hook 'mu4e-compose-mode-hook
          (defun my-do-compose-stuff ()
            "My settings for message composition."
            (set-fill-column 72)
            (flyspell-mode)
            (bbdb-mail-aliases)))


(require 'mu4e)
(require 'mu4e-actions)
(require 'mu4e-headers)

(autoload 'bbdb-insinuate-mu4e "bbdb-mu4e")
(bbdb-initialize 'message 'mu4e)
(setq bbdb-mail-user-agent (quote message-user-agent))
(setq mu4e-view-mode-hook (quote (bbdb-mua-auto-update visual-line-mode)))
(setq mu4e-compose-complete-addresses t)
(setq bbdb-mua-pop-up t)
(setq bbdb-mua-pop-up-window-size 5)

(setq mu4e-maildir (expand-file-name "~/Mail"))

(setq mu4e-drafts-folder "/Gmail/[Gmail]/.Drafts"
      mu4e-sent-folder   "/Gmail/[Gmail]/.Sent Mail"
      mu4e-trash-folder  "/Gmail/[Gmail]/.Trash"
      mu4e-reply-to-address "matthew.f.conway@gmail.com"
      user-mail-address "matthew.f.conway@gmail.com")

(defvar my-mu4e-account-alist
  '(("Gmail"
     (mu4e-drafts-folder "/Gmail/[Gmail]/.Drafts")
     (mu4e-sent-folder "/Gmail/[Gmail]/.Sent Mail")
     (mu4e-trash-folder "/Gmail/[Gmail]/.Trash")
     (mu4e-reply-to-address "matthew.f.conway@gmail.com")
     (user-mail-address "matthew.f.conway@gmail.com"))
    ("Gandalf"
     (mu4e-drafts-folder "/Gandalf/[Gmail]/.Drafts")
     (mu4e-sent-folder "/Gandalf/[Gmail]/.Sent Mail")
     (mu4e-trash-folder "/Gandalf/[Gmail]/.Trash")
     (user-mail-address "gandalfthegrey2@gmail.com")
     (mu4e-reply-to-address "gandalfthegrey2@gmail.com"))
    ("Arthena"
     (mu4e-drafts-folder "/Arthena/Drafts")
     (mu4e-sent-folder "/Arthena/Sent Mail")
     (mu4e-trash-folder "/Arthena/Trash")
     (user-mail-address "matthew@arthena.com")
     (mu4e-reply-to-address "matthew@arthena.com"))))

(setq message-signature-file "~/Mail/Gmail/.signature") ; put your signature in this file

(defun my-mu4e-set-account ()
  "Set the account for composing a message."
  (let* ((account
          (if mu4e-compose-parent-message
              (let ((maildir (mu4e-message-field mu4e-compose-parent-message :maildir)))
                (string-match "/\\(.*?\\)/" maildir)
                (match-string 1 maildir))
            (completing-read (format "Compose with account: (%s) "
                                     (mapconcat #'(lambda (var) (car var))
                                                my-mu4e-account-alist "/"))
                             (mapcar #'(lambda (var) (car var)) my-mu4e-account-alist)
                             nil t nil nil (caar my-mu4e-account-alist))))
         (account-vars (cdr (assoc account my-mu4e-account-alist))))
    (if account-vars
        (mapc #'(lambda (var)
                  (set (car var) (cadr var)))
              account-vars)
      (error "No email account found"))))

(add-hook 'mu4e-compose-pre-hook 'my-mu4e-set-account)


(require 'mu4e-contrib)
(setq mu4e-get-mail-command "mbsync -q gmail gandalf"
      mu4e-html2text-command 'mu4e-shr2text
      mu4e-update-interval 1200
      mu4e-headers-auto-update t
      mu4e-compose-signature-auto-include nil
      )

(setq mu4e-headers-fields '((:human-date . 12)
                            (:flags . 6)
                            (:mailing-list . 10)
                            (:from . 22)
                            (:subject)))

(setf (caar (last mu4e-headers-fields))
      :thread-subject)

(setq mu4e-maildir-shortcuts
      `(("/Gmail/Inbox" . ?i)
        (,mu4e-drafts-folder . ?s)
        (,mu4e-sent-folder . ?t)
        (,mu4e-trash-folder . ?d)))

;; show images
(setq mu4e-show-images t)

;; use imagemagick, if available
(when (fboundp 'imagemagick-register-types)
  (imagemagick-register-types))

(add-to-list 'mu4e-headers-actions
             '("in browser" . mu4e-action-view-in-browser) t)
(add-to-list 'mu4e-view-actions
             '("in browser" . mu4e-action-view-in-browser) t)

;; general emacs mail settings; used when composing e-mail
;; the non-mu4e-* stuff is inherited from emacs/message-mode
(setq user-full-name  "Matthew Conway")

;; don't save message to Sent Messages, IMAP takes care of this
(setq mu4e-sent-messages-behavior 'delete)

;; use 'fancy' non-ascii characters in various places in mu4e
(setq mu4e-use-fancy-chars t)

;; save attachment to my desktop (this can also be a function)
(setq mu4e-attachment-dir "~/Downloads")

;; attempt to show images when viewing messages
(setq mu4e-view-show-images t)

(defun mu4e-in-new-frame ()
  "Start mu4e in new frame."
  (interactive)
  (select-frame (make-frame))
  (mu4e))

(provide 'mail-pack)
;;; mail-pack.el ends here
