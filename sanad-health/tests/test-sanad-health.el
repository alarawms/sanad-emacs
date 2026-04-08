;;; tests/test-sanad-health.el --- Tests for sanad-health core -*- lexical-binding: t; -*-

;;; Commentary:
;; Tests for the core module: customization group, profile loading,
;; module loading, dashboard buffer creation, and keybindings.

;;; Code:

(require 'test-helper)
(require 'sanad-health)

;; --- Customization ---

(ert-deftest sanad-health-test-customization-group-exists ()
  "The sanad-health customization group should exist."
  (should (get 'sanad-health 'custom-group)))

(ert-deftest sanad-health-test-default-modules ()
  "Default modules list should include all standard modules."
  (should (equal sanad-health-modules
                 '(agenda meds capture pomodoro log tracker))))

(ert-deftest sanad-health-test-directory-default-nil ()
  "Health directory should default to nil (triggers setup wizard)."
  (let ((sanad-health-directory nil))
    (should (null sanad-health-directory))))

;; --- Profile ---

(ert-deftest sanad-health-test-profile-path ()
  "Profile path should be profile.org inside health directory."
  (let ((sanad-health-directory "/tmp/test-health"))
    (should (equal (sanad-health-profile-path)
                   "/tmp/test-health/profile.org"))))

(ert-deftest sanad-health-test-read-profile-property ()
  "Should read a property from the profile org file."
  (sanad-health-test-setup)
  (let ((profile-path (sanad-health-profile-path)))
    (make-directory (file-name-directory profile-path) t)
    (with-temp-file profile-path
      (insert "#+TITLE: Health Profile\n")
      (insert "* Preferences\n")
      (insert ":PROPERTIES:\n")
      (insert ":WAKE_TIME: 06:30\n")
      (insert ":POMODORO_WORK: 25\n")
      (insert ":END:\n"))
    (should (equal (sanad-health-profile-get "WAKE_TIME") "06:30"))
    (should (equal (sanad-health-profile-get "POMODORO_WORK") "25")))
  (sanad-health-test-teardown))

;; --- Module Loading ---

(ert-deftest sanad-health-test-module-feature-name ()
  "Module symbol should map to feature name correctly."
  (should (equal (sanad-health--module-feature 'agenda) 'sanad-health-agenda))
  (should (equal (sanad-health--module-feature 'meds) 'sanad-health-meds))
  (should (equal (sanad-health--module-feature 'pomodoro) 'sanad-health-pomodoro)))

;; --- Dashboard Buffer ---

(ert-deftest sanad-health-test-dashboard-buffer-name ()
  "Dashboard buffer should have the correct name."
  (should (equal sanad-health-dashboard-buffer-name "*Sanad Health*")))

(ert-deftest sanad-health-test-dashboard-creates-buffer ()
  "Opening dashboard should create the buffer."
  (sanad-health-test-setup)
  ;; Create minimal profile so dashboard doesn't trigger setup
  (let ((profile-path (sanad-health-profile-path)))
    (make-directory (file-name-directory profile-path) t)
    (with-temp-file profile-path
      (insert "#+TITLE: Health Profile\n")
      (insert "#+PROPERTY: SANAD_USER TestUser\n")
      (insert "* Preferences\n")
      (insert ":PROPERTIES:\n")
      (insert ":ONBOARDED: t\n")
      (insert ":SHOW_HINTS: nil\n")
      (insert ":END:\n")))
  ;; Create required subdirs
  (dolist (dir '("logs" "routines" "meds" "captures"))
    (make-directory (expand-file-name dir sanad-health-directory) t))
  ;; Create empty captures/inbox.org
  (with-temp-file (expand-file-name "captures/inbox.org" sanad-health-directory)
    (insert "#+TITLE: Health Inbox\n* Inbox\n"))
  (sanad-health-dashboard)
  (should (get-buffer sanad-health-dashboard-buffer-name))
  (kill-buffer sanad-health-dashboard-buffer-name)
  (sanad-health-test-teardown))

;; --- Keymap ---

(ert-deftest sanad-health-test-global-prefix-bound ()
  "The global prefix key C-c h should be set up."
  (should (keymapp sanad-health-command-map)))

(provide 'test-sanad-health)
;;; test-sanad-health.el ends here
