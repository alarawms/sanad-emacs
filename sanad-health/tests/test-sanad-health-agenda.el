;;; tests/test-sanad-health-agenda.el --- Tests for agenda integration -*- lexical-binding: t; -*-

;;; Commentary:
;; Tests for org-agenda integration: reading routine blocks, grouping by
;; time-of-day block, custom agenda views, nightly reset, and focus block assignment.

;;; Code:

(require 'test-helper)
(require 'sanad-health)
(require 'sanad-health-agenda)

(ert-deftest sanad-health-agenda-test-read-routine-blocks ()
  "Should read routine entries from daily.org grouped by block."
  (sanad-health-test-setup)
  (make-directory (expand-file-name "routines" sanad-health-directory) t)
  (with-temp-file (expand-file-name "routines/daily.org" sanad-health-directory)
    (insert "#+CATEGORY: Health\n#+FILETAGS: :sanad:\n\n")
    (insert "* Routines\n")
    (insert "** TODO Wake + hydrate\n")
    (insert "   :PROPERTIES:\n   :BLOCK: morning\n   :ORDER: 1\n   :END:\n")
    (insert "** TODO Focus Block 1\n")
    (insert "   :PROPERTIES:\n   :BLOCK: morning\n   :ORDER: 2\n   :POMODORO: t\n   :END:\n")
    (insert "** TODO Exercise\n")
    (insert "   :PROPERTIES:\n   :BLOCK: midday\n   :ORDER: 1\n   :END:\n"))
  (let ((blocks (sanad-health-agenda--read-routine-blocks)))
    (should (= (length blocks) 3))
    ;; First item should be morning, order 1
    (should (equal (plist-get (car blocks) :title) "Wake + hydrate"))
    (should (equal (plist-get (car blocks) :block) "morning")))
  (sanad-health-test-teardown))

(ert-deftest sanad-health-agenda-test-today-items-returns-plist ()
  "sanad-health-agenda-today-items should return a list of plists."
  (sanad-health-test-setup)
  (make-directory (expand-file-name "routines" sanad-health-directory) t)
  (with-temp-file (expand-file-name "routines/daily.org" sanad-health-directory)
    (insert "#+CATEGORY: Health\n#+FILETAGS: :sanad:\n\n")
    (insert "* Routines\n")
    (insert "** TODO Test item\n")
    (insert "   :PROPERTIES:\n   :BLOCK: morning\n   :ORDER: 1\n   :END:\n"))
  (let ((items (sanad-health-agenda-today-items)))
    (should (listp items))
    (should (plist-get (car items) :title)))
  (sanad-health-test-teardown))

(ert-deftest sanad-health-agenda-test-reset-routine-items ()
  "Nightly reset should change DONE items back to TODO."
  (sanad-health-test-setup)
  (make-directory (expand-file-name "routines" sanad-health-directory) t)
  (with-temp-file (expand-file-name "routines/daily.org" sanad-health-directory)
    (insert "#+CATEGORY: Health\n#+FILETAGS: :sanad:\n\n")
    (insert "* Routines\n")
    (insert "** DONE Wake + hydrate\n")
    (insert "   :PROPERTIES:\n   :BLOCK: morning\n   :ORDER: 1\n   :END:\n")
    (insert "** TODO Focus Block 1\n")
    (insert "   :PROPERTIES:\n   :BLOCK: morning\n   :ORDER: 2\n   :END:\n"))
  (sanad-health-agenda--reset-routines)
  (with-temp-buffer
    (insert-file-contents (expand-file-name "routines/daily.org" sanad-health-directory))
    (goto-char (point-min))
    (let ((todo-count 0) (done-count 0))
      (while (re-search-forward "^\\*\\* \\(TODO\\|DONE\\)" nil t)
        (if (equal (match-string 1) "TODO")
            (setq todo-count (1+ todo-count))
          (setq done-count (1+ done-count))))
      (should (= todo-count 2))
      (should (= done-count 0))))
  (sanad-health-test-teardown))

(ert-deftest sanad-health-agenda-test-assign-block-sets-property ()
  "Assigning work to a focus block should set ASSIGNED property."
  (sanad-health-test-setup)
  (make-directory (expand-file-name "routines" sanad-health-directory) t)
  (with-temp-file (expand-file-name "routines/daily.org" sanad-health-directory)
    (insert "#+CATEGORY: Health\n\n* Routines\n")
    (insert "** TODO Focus Block 1\n")
    (insert "   :PROPERTIES:\n   :BLOCK: morning\n   :ASSIGNED:\n   :GOAL:\n   :END:\n"))
  (sanad-health-agenda--set-assignment "Focus Block 1" "phd/chapter3" "Write 500 words")
  (with-temp-buffer
    (insert-file-contents (expand-file-name "routines/daily.org" sanad-health-directory))
    (should (string-match-p "phd/chapter3" (buffer-string)))
    (should (string-match-p "Write 500 words" (buffer-string))))
  (sanad-health-test-teardown))

(provide 'test-sanad-health-agenda)
;;; test-sanad-health-agenda.el ends here
