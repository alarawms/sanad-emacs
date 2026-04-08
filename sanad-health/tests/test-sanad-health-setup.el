;;; tests/test-sanad-health-setup.el --- Tests for setup wizard -*- lexical-binding: t; -*-

;;; Commentary:
;; Tests for the onboarding setup wizard: directory creation, profile
;; generation, medication entry, and routine scaffolding.

;;; Code:

(require 'test-helper)
(require 'sanad-health)
(require 'sanad-health-setup)

(ert-deftest sanad-health-setup-test-create-directory-structure ()
  "Setup should create all required subdirectories."
  (let ((dir (make-temp-file "sanad-setup-test-" t)))
    (sanad-health-setup--create-directories dir)
    (should (file-directory-p (expand-file-name "logs" dir)))
    (should (file-directory-p (expand-file-name "routines" dir)))
    (should (file-directory-p (expand-file-name "meds" dir)))
    (should (file-directory-p (expand-file-name "captures" dir)))
    (delete-directory dir t)))

(ert-deftest sanad-health-setup-test-create-profile ()
  "Setup should create a valid profile.org with user properties."
  (let ((dir (make-temp-file "sanad-setup-test-" t)))
    (sanad-health-setup--create-directories dir)
    (sanad-health-setup--create-profile dir "TestUser" "ADHD")
    (let ((profile (expand-file-name "profile.org" dir)))
      (should (file-exists-p profile))
      (with-temp-buffer
        (insert-file-contents profile)
        (should (string-match-p "SANAD_USER" (buffer-string)))
        (should (string-match-p "TestUser" (buffer-string)))
        (should (string-match-p "WAKE_TIME" (buffer-string)))))
    (delete-directory dir t)))

(ert-deftest sanad-health-setup-test-create-inbox ()
  "Setup should create captures/inbox.org."
  (let ((dir (make-temp-file "sanad-setup-test-" t)))
    (sanad-health-setup--create-directories dir)
    (sanad-health-setup--create-inbox dir)
    (should (file-exists-p (expand-file-name "captures/inbox.org" dir)))
    (delete-directory dir t)))

(ert-deftest sanad-health-setup-test-install-routine-template ()
  "Setup should copy the default routine to routines/daily.org."
  (let ((dir (make-temp-file "sanad-setup-test-" t)))
    (sanad-health-setup--create-directories dir)
    (sanad-health-setup--install-routine-template dir)
    (should (file-exists-p (expand-file-name "routines/daily.org" dir)))
    (delete-directory dir t)))

(ert-deftest sanad-health-setup-test-install-meds-template ()
  "Setup should copy the supplements template to meds/medications.org."
  (let ((dir (make-temp-file "sanad-setup-test-" t)))
    (sanad-health-setup--create-directories dir)
    (sanad-health-setup--install-meds-template dir)
    (should (file-exists-p (expand-file-name "meds/medications.org" dir)))
    (delete-directory dir t)))

(ert-deftest sanad-health-setup-test-add-medication-entry ()
  "Should insert a medication entry into medications.org."
  (let ((dir (make-temp-file "sanad-setup-test-" t)))
    (sanad-health-setup--create-directories dir)
    (sanad-health-setup--install-meds-template dir)
    (sanad-health-setup--add-medication
     dir "Vyvanse" "40mg" "daily" "07:00" t "Dr. Smith")
    (let ((meds-file (expand-file-name "meds/medications.org" dir)))
      (with-temp-buffer
        (insert-file-contents meds-file)
        (should (string-match-p "Vyvanse" (buffer-string)))
        (should (string-match-p "40mg" (buffer-string)))
        (should (string-match-p "07:00" (buffer-string)))))
    (delete-directory dir t)))

(provide 'test-sanad-health-setup)
;;; test-sanad-health-setup.el ends here
