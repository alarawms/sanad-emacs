;;; tests/test-sanad-health-capture.el --- Tests for capture module -*- lexical-binding: t; -*-

;;; Commentary:
;; Tests for org-capture template registration and inbox reading.

;;; Code:

(require 'test-helper)
(require 'sanad-health)
(require 'sanad-health-capture)

(ert-deftest sanad-health-capture-test-templates-registered ()
  "Capture templates should be added to org-capture-templates."
  (let ((org-capture-templates nil))
    (sanad-health-capture--register-templates)
    (should (assoc "h" org-capture-templates))
    (should (assoc "ht" org-capture-templates))
    (should (assoc "hb" org-capture-templates))
    (should (assoc "hn" org-capture-templates))
    (should (assoc "hs" org-capture-templates))))

(ert-deftest sanad-health-capture-test-read-inbox-items ()
  "Should read inbox items from captures/inbox.org."
  (sanad-health-test-setup)
  (make-directory (expand-file-name "captures" sanad-health-directory) t)
  (with-temp-file (expand-file-name "captures/inbox.org" sanad-health-directory)
    (insert "#+TITLE: Inbox\n\n* Inbox\n")
    (insert "** TODO Buy vitamins\n")
    (insert "** Research magnesium\n"))
  (let ((items (sanad-health-capture--read-inbox)))
    (should (= (length items) 2))
    (should (equal (car items) "TODO Buy vitamins")))
  (sanad-health-test-teardown))

(provide 'test-sanad-health-capture)
;;; test-sanad-health-capture.el ends here
