;;; mail-pack.el --- mail-pack

;;; Commentary:

;;; Code:

(require 'install-packages-pack)
(install-packs '(s
                 dash
                 creds
                 google-contacts
                 offlineimap))

;; Internal libs
(require 'gnus)
(require 'epa-file)
(require 'smtpmail)

;; External libs - installed from marmalade/melpa
(require 'creds)
(require 'dash)
(require 's)
(require 'google-contacts)
(require 'google-contacts-message)
(require 'offlineimap)

;; ===================== User setup (user can touch this, the preferred approach it to define a hook to override those values)

;; activate option to keep the passphrase (it's preferable to use gpg-agent)
(setq epa-file-cache-passphrase-for-symmetric-encryption t)

;; Install mu in your system `sudo aptitude install -y mu` (for example in debian-based system) and update the path on your machine to mu4e
(defvar *MAIL-PACK-MU4E-INSTALL-FOLDER* "/usr/share/emacs/site-lisp/mu4e"
  "The mu4e installation folder.")

;; create your .authinfo file and and encrypt it in ~/.authinfo.gpg with M-x epa-encrypt-file
(defvar *MAIL-PACK-MAIL-ROOT-FOLDER* (expand-file-name "~/.mails")
  "The root folder where you store your maildirs folder.")

(defvar *MAIL-PACK-CREDENTIALS-FILE* (expand-file-name "~/.authinfo.gpg")
  "The credentials file where you store your email information.
This can be plain text too.")

(defvar *MAIL-PACK-PERIOD-FETCH-MAIL* 600
  "Number of seconds between fetch + indexing.
Default to 600 seconds.")

(defvar *MAIL-PACK-INTERACTIVE-CHOOSE-ACCOUNT* t
  "Let the user decide which account to use for composing a message.
If set to nil (automatic), the main account will be automatically chosen.
To change the main account, use `M-x mail-pack/set-main-account!`.
Otherwise (interactive), the user will be asked to choose the account to use.
If only 1 account, this is the chosen account.
By default t (so interactive).")

;; ===================== Static setup (user must not touch this)

(defvar *MAIL-PACK-ACCOUNTS* nil "User's email accounts.")

(defvar mail-pack/setup-hooks nil "Use hooks for user to set their setup override.")
(setq mail-pack/setup-hooks) ;; reset hooks

;; ===================== functions

(defun mail-pack/log (str)
  "Log STR with specific pack prefix."
  (message "Mail Pack - %s" str))

(defun mail-pack/pre-requisites-ok-p! ()
  "Ensure that the needed installation pre-requisites are met.
Returns nil if problem."
  (when (file-exists-p *MAIL-PACK-MU4E-INSTALL-FOLDER*)
    (progn
      (add-to-list 'load-path *MAIL-PACK-MU4E-INSTALL-FOLDER*)
      (require 'mu4e))))

(defun mail-pack/setup-possible-p (creds-file)
  "Check if CREDS-FILE exists and contain at least one account.
If all is ok, return the creds-file's content, nil otherwise."
  (when (file-exists-p creds-file)
    (let* ((creds-file-content (creds/read-lines creds-file))
           (email-description  (creds/get creds-file-content "email-description"))
           (account-server     (creds/get-entry email-description "smtp-server"))
           (account-email      (creds/get-entry email-description "mail")))
      (when (creds/get-with creds-file-content `(("machine" . ,account-server) ("login" . ,account-email)))
        creds-file-content))))

(defun mail-pack/--nb-accounts (creds-file-content)
  "In CREDS-FILE-CONTENT, compute how many accounts exist?"
  (--reduce-from (let ((machine (creds/get-entry it "machine")))
                   (if (string-match-p "email-description" machine)
                       (+ 1 acc)
                     acc))
                 0
                 creds-file-content))

(defun mail-pack/--find-account (emails-sent-to possible-account)
  "Determine the account to use in EMAILS-SENT-TO.
EMAILS-SENT-TO is the addresses in to, cc, bcc from the message received.
POSSIBLE-ACCOUNT is the actual accounts setup-ed."
  (--filter (string= possible-account (mail-pack/--maildir-from-email it)) emails-sent-to))

(defun mail-pack/--compute-composed-message! ()
  "Compute the composed message (Delegate this to mu4e)."
  mu4e-compose-parent-message)

(defun mail-pack/--retrieve-account (composed-parent-message possible-accounts)
  "Retrieve the mail account to which the COMPOSED-PARENT-MESSAGE was sent to.
This will look into the :to, :cc, :bcc fields to find the right account.
POSSIBLE-ACCOUNTS is the actual lists of accounts setup-ed.
If all accounts are found, return the first encountered." ;; TODO look at mu4e-message-contact-field-matches -> (mu4e-message-contact-field-matches msg :to "me@work.com"))
  ;; build all the emails recipients (to, cc, bcc)
  (let ((emails-sent-to (mapcar #'cdr (concatenate #'list
                                                   (plist-get composed-parent-message :to)
                                                   (plist-get composed-parent-message :cc)
                                                   (plist-get composed-parent-message :bcc)))))
    ;; try to find the accounts the mail was sent to
    (-when-let (found-accounts (--mapcat (mail-pack/--find-account emails-sent-to it) possible-accounts))
      ;; return the account found
      (mail-pack/--maildir-from-email (car found-accounts)))))

(defun mail-pack/--maildir-accounts (accounts)
  "Given the ACCOUNTS list, return only the list of possible maildirs."
  (mapcar #'car accounts))

(defun mail-pack/choose-main-account! (possible-accounts)
  "Permit the user to choose an account from the optional ACCOUNT-LIST as main account. Return the chosen account."
  (if (< 1 (length possible-accounts))
      (completing-read (format "Compose with account: (%s) " (s-join "/" possible-accounts))
                       possible-accounts nil t nil nil (car possible-accounts))
    (car possible-accounts)))

(defun mail-pack/set-main-account! ()
  (interactive)
  (let* ((accounts          *MAIL-PACK-ACCOUNTS*)
         (possible-accounts (mail-pack/--maildir-accounts accounts))
         (account           (mail-pack/choose-main-account! possible-accounts)))
    (-> account
      (assoc accounts)
      mail-pack/--setup-as-main-account!)))

(defun mail-pack/set-account (accounts)
  "Set the main account amongst ACCOUNTS.
When composing a message, in interactive mode, the user chooses the account.
When composing a message, in automatic mode, the main account is chosen.
When replying/forwarding, determine automatically the account to use.
If no account is found, revert to the composing message behavior."
  (let* ((possible-accounts       (mail-pack/--maildir-accounts accounts))
         (composed-parent-message (mail-pack/--compute-composed-message!))
         ;; when replying/forwarding a message
         (retrieved-account (when composed-parent-message
                              (mail-pack/--retrieve-account composed-parent-message possible-accounts)))
         (account           (if retrieved-account
                                retrieved-account
                              ;; otherwise we need to choose (interactively or automatically) which account to choose
                              (if *MAIL-PACK-INTERACTIVE-CHOOSE-ACCOUNT*
                                  ;; or let the user choose which account he want to compose its mail
                                  (mail-pack/choose-main-account! possible-accounts)
                                (mail-pack/--maildir-from-email user-mail-address)))))
    (if account
        (-> account
          (assoc accounts)
          mail-pack/--setup-as-main-account!)
      (error "No email account found!"))))

(defun mail-pack/--setup-keybindings-and-hooks! ()
  "Install defaults hooks and key bindings."
  (add-hook 'mu4e-headers-mode-hook
            (lambda ()
              (define-key 'mu4e-headers-mode-map (kbd "o") 'mu4e-headers-view-message)))

  (add-hook 'mu4e-main-mode-hook
            (lambda ()
              (define-key 'mu4e-main-mode-map (kbd "c") 'mu4e-compose-new)
              (define-key 'mu4e-main-mode-map (kbd "e") 'mu4e-compose-edit)
              (define-key 'mu4e-main-mode-map (kbd "f") 'mu4e-compose-forward)
              (define-key 'mu4e-main-mode-map (kbd "r") 'mu4e-compose-reply)

              (define-key 'mu4e-headers-mode-map (kbd "a") 'mu4e-headers-mark-for-refile)
              (define-key 'mu4e-headers-mode-map (kbd "c") 'mu4e-compose-new)
              (define-key 'mu4e-headers-mode-map (kbd "e") 'mu4e-compose-edit)
              (define-key 'mu4e-headers-mode-map (kbd "f") 'mu4e-compose-forward)
              (define-key 'mu4e-headers-mode-map (kbd "r") 'mu4e-compose-reply)))

  (global-set-key (kbd "C-c e m") 'mu4e)

  ;; Hook to determine which account to use before composing
  (add-hook 'mu4e-compose-pre-hook
            (lambda () (mail-pack/set-account *MAIL-PACK-ACCOUNTS*))))

(defun mail-pack/--label (entry-number label)
  "Given an ENTRY-NUMBER, and a LABEL, compute the full label."
  (if (or (null entry-number) (string= "" entry-number))
      label
    (format "%s-%s" entry-number label)))

(defun mail-pack/--common-configuration! ()
  "Install the common configuration between all accounts."
  (setq gnus-invalid-group-regexp "[:`'\"]\\|^$"
        mu4e-drafts-folder "/[Gmail].Drafts"
        mu4e-sent-folder   "/[Gmail].Sent Mail"
        mu4e-trash-folder  "/[Gmail].Trash"
        mu4e-refile-folder "/[Gmail].All Mail"
        ;; setup some handy shortcuts
        mu4e-maildir-shortcuts `(("/INBOX"             . ?i)
                                 (,mu4e-sent-folder    . ?s)
                                 (,mu4e-trash-folder   . ?t)
                                 (,mu4e-drafts-folder  . ?d)
                                 (,mu4e-refile-folder  . ?a))
        ;; skip duplicates by default
        mu4e-headers-skip-duplicates t
        ;; default page size
        mu4e-headers-results-limit 500
        mu4e~headers-sort-direction 'descending
        mu4e~headers-sort-field :date
        ;; don't save message to Sent Messages, GMail/IMAP will take care of this
        mu4e-sent-messages-behavior 'delete
        ;; allow for updating mail using 'U' in the main view
        mu4e-get-mail-command "offlineimap"
        ;; update every 5 min
        mu4e-update-interval *MAIL-PACK-PERIOD-FETCH-MAIL*
        mu4e-attachment-dir "~/Downloads"
        mu4e-view-show-images t
        ;; prefer plain text message
        mu4e-view-prefer-html nil
        ;; to convert html to plain text - prerequisite: aptitude install -y html2text
        mu4e-html2text-command "html2text -utf8 -width 120"
        ;; to convert html to plain text - prerequisite: aptitude install -y html2mardown
        ;; mu4e-html2text-command "html2markdown | grep -v '&nbsp_place_holder;'"
        ;; to convert html to org - prerequisite: aptitude install -y pandoc
        ;; mu4e-html2text-command "pandoc -f html -t org"
        ;; see mu4e-header-info for the full list of keywords
        mu4e-headers-fields '((:human-date    . 16)
                              (:flags         . 6)
                              (:from          . 25)
                              (:to            . 25)
                              ;; (:mailing-list  . 10)
                              (:size          . 10)
                              ;; (:tags          . 10)
                              (:subject))
        ;; see format-time-string for the format - here french readable
        mu4e-headers-date-format "%Y-%m-%d %H:%M"
        ;; universal date
        ;; mu4e-headers-date-format "%FT%T%z"
        ;; only consider email addresses that were seen in personal messages
        mu4e-compose-complete-only-personal t
        ;; auto complete addresses
        mu4e-compose-complete-addresses t
        message-kill-buffer-on-exit t
        ;; SMTP setup ; pre-requisite: gnutls-bin package installed
        message-send-mail-function    'smtpmail-send-it
        smtpmail-stream-type          'starttls
        starttls-use-gnutls           t
        smtpmail-debug-info t
        smtpmail-debug-verb t
        ;; empty the hooks
        mu4e-headers-mode-hook nil
        mu4e-main-mode-hook nil
        mu4e-compose-pre-hook nil)
  ;; Add bookmarks query
  (add-to-list 'mu4e-bookmarks '("size:5M..500M" "Big messages" ?b) t)
  (add-to-list 'mu4e-bookmarks '("date:today..now AND flag:unread AND NOT flag:trashed" "Unread messages from today" ?U)))

(defun mail-pack/--compute-fullname (firstname surname name)
  "Given the user's FIRSTNAME, SURNAME and NAME, compute the user's fullname."
  (cl-flet ((if-null-then-empty (v) (if v v "")))
    (s-trim (format "%s %s %s" (if-null-then-empty firstname) (if-null-then-empty surname) (if-null-then-empty name)))))

(defun mail-pack/--maildir-from-email (mail-address)
  "Compute the maildir (without its root folder) from the MAIL-ADDRESS."
  (car (s-split "@" mail-address)))

(defun mail-pack/--setup-as-main-account! (account-setup-vars)
  "Given the entry ACCOUNT-SETUP-VARS, set the main account vars up."
  (mapc #'(lambda (var) (set (car var) (cadr var))) (cdr account-setup-vars)))

(defun mail-pack/--setup-account (creds-file creds-file-content &optional entry-number)
  "Setup an account and return the key values structure.
CREDS-FILE represents the credentials file.
CREDS-FILE-CONTENT is the content of that same file.
ENTRY-NUMBER is the optional account number (multiple accounts setup possible).
When ENTRY-NUMBER is nil, the account to set up is considered the main account."
  (let* ((description-entry        (creds/get creds-file-content (mail-pack/--label entry-number "email-description")))
         (full-name                (mail-pack/--compute-fullname (creds/get-entry description-entry "firstname")
                                                                 (creds/get-entry description-entry "surname")
                                                                 (creds/get-entry description-entry "name")))
         (x-url                    (creds/get-entry description-entry "x-url"))
         (mail-host                (creds/get-entry description-entry "mail-host"))
         (signature                (creds/get-entry description-entry "signature-file"))
         (smtp-server              (creds/get-entry description-entry "smtp-server"))
         (mail-address             (creds/get-entry description-entry "mail"))
         (smtp-server-entry        (creds/get-with creds-file-content `(("machine" . ,smtp-server) ("login" . ,mail-address))))
         (smtp-port                (creds/get-entry smtp-server-entry "port"))
         (folder-mail-address      (mail-pack/--maildir-from-email mail-address))
         (folder-root-mail-address (format "%s/%s" *MAIL-PACK-MAIL-ROOT-FOLDER* folder-mail-address))
         ;; setup the account
         (account-setup-vars       `(,folder-mail-address
                                     ;; Global setup
                                     (user-mail-address      ,mail-address)
                                     (user-full-name         ,full-name)
                                     (message-signature-file ,signature)
                                     ;; GNUs setup
                                     (gnus-posting-styles ((".*"
                                                            (name ,full-name)
                                                            ("X-URL" ,x-url)
                                                            (mail-host-address ,mail-host))))
                                     (smtpmail-smtp-user ,mail-address)
                                     (smtpmail-starttls-credentials ((,smtp-server ,smtp-port nil nil)))
                                     (smtpmail-smtp-service         ,smtp-port)
                                     (smtpmail-default-smtp-server  ,smtp-server)
                                     (smtpmail-smtp-server          ,smtp-server)
                                     (smtpmail-auth-credentials     ,creds-file)
                                     ;; mu4e setup
                                     (mu4e-maildir ,(expand-file-name folder-root-mail-address)))))
    ;; Sets the main account if it is the one!
    (unless entry-number
      (mail-pack/--setup-as-main-account! account-setup-vars))
    ;; In any case, return the account setup vars
    account-setup-vars))

(defun mail-pack/setup (creds-file creds-file-content)
  "Mail pack setup with the CREDS-FILE path and the CREDS-FILE-CONTENT."
  ;; common setup
  (mail-pack/--common-configuration!)

  ;; reinit the accounts list
  (setq *MAIL-PACK-ACCOUNTS*)

  ;; secondary accounts setup
  (-when-let (nb-accounts (mail-pack/--nb-accounts creds-file-content))
    (when (< 1 nb-accounts)
      (->> (number-sequence 2 nb-accounts)
        (mapc (lambda (account-entry-number)
                (->> account-entry-number
                  (format "%s")
                  (mail-pack/--setup-account creds-file creds-file-content)
                  (add-to-list '*MAIL-PACK-ACCOUNTS*)))))))

  ;; main account setup
  (add-to-list '*MAIL-PACK-ACCOUNTS* (mail-pack/--setup-account creds-file creds-file-content))

  ;; install bindings and hooks
  (mail-pack/--setup-keybindings-and-hooks!))

;; ===================== Starting the mode

(defun mail-pack/load-pack! ()
  "Mail pack loading routine.
This will check if the pre-requisite are met.
If ok, then checks if an account file exists the minimum required (1 account).
If ok then do the actual loading.
Otherwise, will log an error message with what's wrong to help the user fix it."
  (interactive)
  ;; run user defined hooks
  (run-hooks 'mail-pack/setup-hooks)
  ;; at last the checks and load pack routine
  (if (mail-pack/pre-requisites-ok-p!)
    (-if-let (creds-file-content (mail-pack/setup-possible-p *MAIL-PACK-CREDENTIALS-FILE*))
        (progn
          (mail-pack/log (concat *MAIL-PACK-CREDENTIALS-FILE* " found! Running Setup..."))
          (mail-pack/setup *MAIL-PACK-CREDENTIALS-FILE* creds-file-content)
          (mail-pack/log "Setup done!"))
      (mail-pack/log
       (concat
        "You need to setup your credentials file " *MAIL-PACK-CREDENTIALS-FILE* " for this to work. (The credentials file can be secured with gpg or not).\n"
        "\n"
        "A single account configuration file '" *MAIL-PACK-CREDENTIALS-FILE* "' would look like this:\n"
        "machine email-description firstname <firstname> surname <surname> name <name> x-url <url> mail-host <mail-host> signature <signature> smtp-server <smtp-server>\n"
        "machine smtp.gmail.com login <your-email> port 587 password <your-mail-password-or-dedicated-passwd>\n"
        "\n"
        "A multiple account configuration file '" *MAIL-PACK-CREDENTIALS-FILE* "' would look like this:\n"
        "machine email-description firstname <firstname> surname <surname> name <name> x-url <url> mail-host <mail-host> signature <signature> smtp-server <smtp-server>\n\n"
        "machine smtp.gmail.com login <login> port 587 password <your-mail-password-or-dedicated-passwd>\n"
        "machine 2-email-description firstname <firstname> surname <surname> name <name> x-url <url> mail-host <mail-host> signature <signature> smtp-server <smtp-server>\n\n"
        "machine smtp.gmail.com login <2nd-email> port 587 password <your-mail-password-or-dedicated-passwd>\n"
        "machine 3-email-description firstname <firstname> surname <surname> name <name> x-url <url> mail-host <mail-host> signature <signature> smtp-server <smtp-server>\n\n"
        "...\n"
        "\n"
        "Optional: Then `M-x encrypt-epa-file` to generate the required ~/.authinfo.gpg and remove ~/.authinfo.\n"
        "Whatever you choose, reference the file you use in your emacs configuration:\n"
        "(setq *MAIL-PACK-CREDENTIALS-FILE* (expand-file-name \"~/.authinfo\"))")))
    (mail-pack/log "As a pre-requisite, you need to install the offlineimap and mu packages.
For example, on debian-based system, `sudo aptitude install -y offlineimap mu`...
When mu is installed, you also need to reference the mu4e (installed with mu) installation folder for this pack to work.")))

(provide 'mail-pack)
;;; mail-pack.el ends here
