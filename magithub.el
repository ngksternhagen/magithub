;;; magithub.el --- Magit interfaces for GitHub  -*- lexical-binding: t; -*-

;; Copyright (C) 2016  Sean Allred

;; Author: Sean Allred <code@seanallred.com>
;; Keywords: git, tools, vc
;; Homepage: https://github.com/vermiculus/magithub
;; Package-Requires: ((emacs "24.3") (magit "2.8.0") (git-commit "20160821.1338") (with-editor "20160828.1025"))

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; Magithub is an interface to GitHub using the `hub' utility [1].
;;
;; Integrated into Magit workflows, Magithub allows very easy, very
;; basic GitHub repository management.  Supported actions include:
;;
;;  - pushing brand-new local repositories up to GitHub
;;  - creating forks of existing repositories
;;  - submitting pull requests upstream
;;  - creating issues
;;
;; Press `h' in the status buffer to get started -- happy hacking!
;;
;; [1]: https://hub.github.com

;; Requires hub 2.2.8

;;; Code:

(require 'magit)
(require 'magit-process)
(require 'magit-popup)
(require 'git-commit)
(require 'with-editor)

(defmacro magithub-with-hub (&rest body)
  `(let  ((magit-git-executable magithub-hub-executable)
          (magit-pre-call-git-hook nil)
          (magit-git-global-arguments nil))
     ,@body))

(defun magithub--hub-command (magit-function command args)
  (unless (executable-find magithub-hub-executable)
    (user-error "Hub (hub.github.com) not installed; aborting"))
  (unless (file-exists-p "~/.config/hub")
    (user-error "Hub hasn't been initialized yet; aborting"))
  (magithub-with-hub (funcall magit-function command args)))

(defun magithub--command (command &optional args)
  "Run COMMAND synchronously using `magithub-hub-executable'."
  (magithub--hub-command #'magit-run-git command args))

(defun magithub--command-with-editor (command &optional args)
  "Run COMMAND asynchronously using `magithub-hub-executable'.
Ensure GIT_EDITOR is set up appropriately."
  (magithub--hub-command #'magit-run-git-with-editor command args))

(defun magithub--command-output (command &optional args)
  "Run COMMAND synchronously using `magithub-hub-executable'
and returns its output as a list of lines."
  (magithub-with-hub (magit-git-lines command args)))

(defun magithub--command-quick (command &optional args)
  "Quickly execute COMMAND with ARGS."
  (ignore (magithub--command-output command args)))

(defvar magithub-after-create-messages
  '("Don't be shy!"
    "Don't let your dreams be dreams!"))

(magit-define-popup magithub-dispatch-popup
  "Popup console for dispatching other Magithub popups."
  'magithub-commands
  :man-page "hub"
  :actions '("Actions"
             (?h "Browse on GitHub" magithub-browse)
             (?c "Create" magithub-create-popup)
             (?f "Fork" magithub-fork-popup)
             (?i "Issues" magithub-issues-popup)
             (?p "Submit a pull request" magithub-pull-request-popup)
             "Meta"
             (?& "Request a feature or report a bug" magithub--meta-new-issue)
             (?H "Ask for help on Gitter" magithub--meta-help)))

(magit-define-popup magithub-create-popup
  "Popup console for creating GitHub repositories."
  'magithub-commands
  :man-page "hub"
  :switches '((?p "Mark as private" "-p"))
  :actions '((?c "Create this repository" magithub-create))
  :options '((?d "Description" "--description=")
             (?h "Homepage" "--homepage=")))

(magit-define-popup magithub-fork-popup
  "Popup console for forking GitHub repositories."
  'magithub-commands
  :man-page "hub"
  :switches '((?r "Don't add my fork as a remote in this repository" "--no-remote"))
  :actions '((?f "Fork the project at origin" magithub-fork)))

(magit-define-popup magithub-pull-request-popup
  "Popup console for creating pull requests on GitHub repositories."
  'magithub-commands
  :man-page "hub"
  :switches '((?f "Ignore unpushed commits" "-f")
              (?o "Open in my browser" "-o"))
  :options '((?b "Base branch" "--base=" magit-read-branch)
             (?h "Head branch" "--head=" magit-read-branch))
  :actions '((?P "Submit a pull request" magithub-pull-request))
  :default-arguments '("-o"))

(magit-define-popup magithub-issues-popup
  "Popup console for creating GitHub issues."
  'magithub-commands
  :man-page "hub"
  :options '((?l "Add labels" "--label=" magithub-issue-read-labels))
  :actions '((?c "Create new issue" magithub-issue-new)))

(defun magithub--meta-new-issue ()
  "Open a new Magithub issue.
See /.github/ISSUE_TEMPLATE.md in this repository."
  (interactive)
  (browse-url "https://github.com/vermiculus/magithub/issues/new"))

(defun magithub--meta-help ()
  "Opens Magithub help."
  (interactive)
  (browse-url "https://gitter.im/vermiculus/magithub"))

(defun magithub-github-repository-p ()
  "Non-nil if \"origin\" points to GitHub."
  (let ((url (magit-get "remote" "origin" "url")))
    (or (string-prefix-p "git@github.com:" url)
        (string-prefix-p "https://github.com/" url)
        (string-prefix-p "git://github.com/" url))))

(defun magithub-issue-new ()
  "Create a new issue on GitHub."
  (interactive)
  (unless (magithub-github-repository-p)
    (user-error "Not a GitHub repository"))
  (magithub--command-with-editor
   "issue" (cons "create" (magithub-issues-arguments))))

(defun magithub-issue-label-list ()
  "Return a list of issue labels.
This is a hard-coded list right now."
  (list "bug" "duplicate" "enhancement"
        "help wanted" "invalid" "question" "wontfix"))

(defun magithub-issue-read-labels (prompt &optional default)
  "Read some issue labels."
  (string-join
   (magithub--completing-read-multiple
    (format "%s... %s" prompt "Issue labels (or \"\" to quit): ")
    (let* ((default-labels (when default (split-string default ","))))
      (remove-if (lambda (l) (member l default-labels))
                 (magithub-issue-label-list))))
   ","))

(defun magithub--completing-read-multiple (prompt collection)
  "Using PROMPT, get a list of elements in COLLECTION.
This function continues until all candidates have been entered or
until the user enters a value of \"\".  Duplicate entries are not
allowed."
  (let (label-list this-label done)
    (while (not done)
      (setq collection (remove this-label collection)
            this-label "")
      (when collection
        ;; @todo it would be nice to detect whether or not we are
        ;; allowed to create labels -- if not, we can require-match
        (setq this-label (completing-read prompt collection)))
      (unless (setq done (string-empty-p this-label))
        (add-to-list 'label-list this-label t)))
    label-list))

(defface magithub-issue-warning-face
  '((((class color)) :foreground "red"))
  "Face used to call out warnings in the issue-create buffer."
  :group 'magithub)

(defun magithub-check-buffer ()
  (when (and buffer-file-name
             (member (file-name-base buffer-file-name)
                     '("ISSUE_EDITMSG")))
    (with-editor-mode 1)
    (git-commit-setup-font-lock)
    (font-lock-add-keywords
     nil
     `(("^# \\(Creating issue for .*\\)"
        (1 'magithub-issue-warning-face t))
       (,(rx (= 40 (| digit (any (?A . ?F) (?a . ?f)))))
        (0 'magit-hash t)))
     t)
    (set (make-local-variable 'with-editor-pre-finish-hook)
         with-editor-pre-finish-hook)
    (add-hook
     'with-editor-pre-finish-hook
     (lambda () (unfill-region (point-min) (point-max))))))
(add-hook 'find-file-hook #'magithub-check-buffer)

(defun magithub-browse ()
  "Open the repository in your browser."
  (interactive)
  (unless (magithub-github-repository-p)
    (user-error "Not a GitHub repository"))
  (magithub--command-quick "browse"))

(defun magithub-create ()
  "Create the current repository on GitHub."
  (interactive)
  (message "Creating repository on GitHub...")
  (magithub--command "create" (magithub-create-arguments))
  (message "Creating repository on GitHub...done!  %s"
           (nth (random (length magithub-after-create-messages))
                magithub-after-create-messages))
  (magit-push-popup))

(defun magithub-fork ()
  "Fork 'origin' on GitHub."
  (interactive)
  (unless (magithub-github-repository-p)
    (user-error "Not a GitHub repository"))
  (when (and (string-equal "master" (magit-get-current-branch))
             (y-or-n-p "Looks like master is checked out.  Create a new branch? "))
    (call-interactively #'magit-branch-spinoff))
  (message "Forking repository on GitHub...")
  (magithub--command "fork" (magithub-fork-arguments))
  (message "Forking repository on GitHub...done"))

(defun magithub-pull-request ()
  "Open a pull request to 'origin' on GitHub."
  (interactive)
  (unless (magithub-github-repository-p)
    (user-error "Not a GitHub repository"))
  (let (just-pushed)
    (unless (magit-get-push-remote)
      (when (y-or-n-p "No push remote defined; push now? ")
        (call-interactively #'magit-push-current-to-pushremote)
        (setq just-pushed t)))
    (unless (magit-get-push-remote)
      (user-error "No push remote defined; aborting pull request"))
    (unless just-pushed
      (when (y-or-n-p "Do you want to push any more commits? ")
        (magit-push-popup)))
    (magithub--command-with-editor "pull-request" (magithub-pull-request-arguments))))

(defun magithub-use-key (key)
  (magit-define-popup-action 'magit-dispatch-popup key
    "Magithub" 'magithub-dispatch-popup ?!)
  (define-key magit-status-mode-map (char-to-string key)
    #'magithub-dispatch-popup)
  (setq magithub-dispatch-key key))

(defcustom magithub-hub-executable "hub"
  "The hub executable used by Magithub."
  :group 'magithub
  :package-version '(magithub . "0.1")
  :type 'string)

(defcustom magithub-dispatch-key ?H
  "The key used in `magit-dispatch-popup' to activate `magithub-dispatch-popup'."
  :group 'magithub
  :package-version '(magithub . "0.2")
  :type 'character
  :set (lambda (_ n)
         (eval-after-load 'magit
           (magithub-use-key ?H))))

(provide 'magithub)
;;; magithub.el ends here
