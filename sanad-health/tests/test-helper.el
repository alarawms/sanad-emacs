;;; tests/test-helper.el --- Test helper for sanad-health -*- lexical-binding: t; -*-

;;; Commentary:
;; Sets up the load path and common utilities for sanad-health tests.

;;; Code:

;; Add the parent directory (package root) to load path
(let ((pkg-dir (file-name-directory
                (directory-file-name
                 (file-name-directory
                  (or load-file-name buffer-file-name))))))
  (add-to-list 'load-path pkg-dir))

;; Common test utilities
(require 'ert)
(require 'org)

(defvar sanad-health-test-dir nil
  "Temporary directory for test data.")

(defun sanad-health-test-setup ()
  "Create a temporary health directory for testing."
  (setq sanad-health-test-dir (make-temp-file "sanad-health-test-" t))
  (setq sanad-health-directory sanad-health-test-dir))

(defun sanad-health-test-teardown ()
  "Clean up temporary test directory."
  (when (and sanad-health-test-dir
             (file-exists-p sanad-health-test-dir))
    (delete-directory sanad-health-test-dir t))
  (setq sanad-health-test-dir nil)
  (setq sanad-health-directory nil))

(provide 'test-helper)
;;; test-helper.el ends here
