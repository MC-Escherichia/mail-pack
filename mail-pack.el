;;; mail-pack.el --- A `pack` to setup your email accounts through a ~/.authinfo(.gpg) credentials file

;; Copyright (C) 2014 Antoine R. Dumont <eniotna.t AT gmail.com>

;; Author: Antoine R. Dumont <eniotna.t AT gmail.com>
;; Maintainer: Antoine R. Dumont <eniotna.t AT gmail.com>
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
(require 'smtpmail)

;; External libs - installed from marmalade/melpa
(require 'creds)
(require 'dash)
(require 's)
(require 'offlineimap)
(require 'smtpmail-async)

;; ===================== Add completion on emails

(install-packages-pack/install-packs '(google-contacts))

(require 'google-contacts)
(require 'google-contacts-message)

;; ===================== User setup (user can touch this, the preferred approach it to define a hook to override those values)



(provide 'mail-pack)
;;; mail-pack.el ends here
