;;; mail-pack.el --- mail-pack

;;; Commentary:

;;; Code:

(install-packs '(creds))

(require 'gnus)
(require 'creds)
(require 'dash)

;; ===================== setup file

;; create your .authinfo file and and encrypt it in ~/.authinfo.gpg with M-x epa-encrypt-file
(defvar *MAIL-PACK-CREDENTIALS-FILE* "~/.authinfo.gpg")

;; ===================== setup function

(defun mail-pack/log (str) "A log function for the pack."
  (message "Mail Pack - %s" str))

(defun mail-pack/setup-possible-p (creds-file) "Check if the setup is possible by checking the existence of the file creds-file and that the entries 'imap.gmail.com', 'smtp.gmail.com', and 'description' are provided."
  (if (file-exists-p creds-file)
      (let ((parsed-lines (creds/read-lines creds-file)))
        (when (and (creds/get parsed-lines "imap.gmail.com")
                   (creds/get parsed-lines "smtp.gmail.com")
                   (creds/get parsed-lines "description"))
          parsed-lines))))

(defun mail-pack/setup (creds-file creds-file-content)
  "My default gnus setup."
  ;; got this line from one of the tutorials. Seemed interesting enough
  (setq gnus-invalid-group-regexp "[:`'\"]\\|^$")

  ;; IMAP setup
  ;; standard way of getting imap going
  (setq gnus-select-method '(nnimap "gmail"
                                    (nnimap-address "imap.gmail.com")
                                    (nnimap-server-port 993)
                                    (nnimap-stream ssl)))

  ;; SMTP setup
  ;; set up smtp so we can send from gmail too:
  (setq message-send-mail-function    'smtpmail-send-it
        smtpmail-starttls-credentials '(("smtp.gmail.com" 587 nil nil))
        smtpmail-auth-credentials     (expand-file-name creds-file)
        smtpmail-default-smtp-server  "smtp.gmail.com"
        smtpmail-smtp-server          "smtp.gmail.com"
        smtpmail-smtp-service         587)

  ;;http://www.emacswiki.org/cgi-bin/wiki/GnusGmail
  ;;http://linil.wordpress.com/2008/01/18/gnus-gmail/

  (add-hook 'gnus-group-mode-hook 'gnus-topic-mode)

  ;; Threads are nice!
  (setq gnus-summary-thread-gathering-function 'gnus-gather-threads-by-subject)

  (setq description (creds/get creds-file-content "description"))

  (setq full-name (format "%s %s %s" (creds/get-entry description "firstname") (creds/get-entry description "surname") (creds/get-entry description "name")))

  (setq x-url        (creds/get-entry description "x-url"))
  (setq mail-address (creds/get-entry description "mail"))
  (setq mail-host    (creds/get-entry description "mail-host"))

  (setq user-mail-address mail-address)
  (setq user-full-name    full-name)

  (setq gnus-posting-styles `((".*"
                               (name ,full-name)
                               ("X-URL" ,x-url)
                               (mail-host-address ,mail-host))))

  (setq send-mail-function 'smtpmail-send-it))

;; ===================== setup routine

(-if-let (creds-file-content (mail-pack/setup-possible-p *MAIL-PACK-CREDENTIALS-FILE*))
    (progn
      (mail-pack/log (concat *MAIL-PACK-CREDENTIALS-FILE* " found! Running Setup..."))
      (mail-pack/setup *MAIL-PACK-CREDENTIALS-FILE* creds-file-content)
      (mail-pack/log "Setup done!"))
  (mail-pack/log (concat "You need to setup the credentials file " *MAIL-PACK-CREDENTIALS-FILE* " for this to work.\n"
                   "Here is a sample content to setup to your need into '" *MAIL-PACK-CREDENTIALS-FILE* "':\n"
                   "machine imap.gmail.com login <your-email> password <your-mail-password-or-dedicated-passwd> port 993\n"
                   "machine smtp.gmail.com login <login> port 587 password <your-mail-password-or-dedicated-passwd>\n"
                   "machine description firstname <firstname> surname <surname> name <name> x-url <some-url> mail <your-email> mail-host <your-mail-host>\n"
                   "Then `M-x encrypt-epa-file` to generate the required ~/.authinfo.gpg and remove ~/.authinfo")))

;;; mail-pack.el ends here
