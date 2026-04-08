# Sanad Health Mode Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a modular Emacs major mode for health and ADHD management on top of org-mode, with dashboard, agenda integration, medication tracking, brain dump capture, pomodoro timer, daily logging, and start-my-day tracker.

**Architecture:** Modular package with a core (`sanad-health.el`) providing profiles, customization, dashboard shell, and module loading. Each feature is a separate `.el` file that registers itself with the core. All user data stored as `.org` files. Integrates with `org-agenda`, `org-capture`, and `org-clock`.

**Tech Stack:** Emacs Lisp, org-mode, ERT (testing), package.el headers (distribution)

**Spec:** `docs/superpowers/specs/2026-04-08-sanad-health-mode-design.md`

---

## File Structure

```
sanad-health/
├── sanad-health.el              ;; Core: defgroup, user profile, module loader, dashboard buffer
├── sanad-health-setup.el        ;; Onboarding wizard: directory creation, profile, meds, routines
├── sanad-health-agenda.el       ;; org-agenda custom commands, routine blocks, goals, nightly reset
├── sanad-health-meds.el         ;; Medication/supplement CRUD, reminders, stack review buffer
├── sanad-health-capture.el      ;; org-capture templates for brain dump, tasks, side effects
├── sanad-health-pomodoro.el     ;; Pomodoro timer, mode-line display, org-clock, distraction counter
├── sanad-health-log.el          ;; Daily log creation, metrics prompts, weekly aggregation
├── sanad-health-tracker.el      ;; Start My Day interactive checklist buffer
├── templates/
│   ├── daily-log.org            ;; Template for daily logs
│   ├── routine.org              ;; Default ADHD routine blocks
│   └── supplements.org          ;; Default supplement reference
├── tests/
│   ├── test-sanad-health.el     ;; Core tests
│   ├── test-sanad-health-setup.el
│   ├── test-sanad-health-agenda.el
│   ├── test-sanad-health-meds.el
│   ├── test-sanad-health-capture.el
│   ├── test-sanad-health-pomodoro.el
│   ├── test-sanad-health-log.el
│   └── test-sanad-health-tracker.el
├── README.org                   ;; User documentation
├── CHANGELOG.org                ;; Version history
└── .github/
    └── workflows/
        └── test.yml             ;; CI: run ERT tests on push
```

---

## Task 1: Project Scaffolding & CI

**Files:**
- Create: `sanad-health/.github/workflows/test.yml`
- Create: `sanad-health/Makefile`
- Create: `sanad-health/tests/test-helper.el`

- [ ] **Step 1: Create the package directory structure**

```bash
cd /home/alarawms/sanad/health
mkdir -p sanad-health/tests sanad-health/templates sanad-health/.github/workflows
```

- [ ] **Step 2: Create the test helper**

This file sets up load paths so ERT can find the package files during batch testing.

```elisp
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
```

- [ ] **Step 3: Create the Makefile**

```makefile
.PHONY: test clean

EMACS ?= emacs
BATCH = $(EMACS) -Q -batch -L . -L tests -l tests/test-helper.el

test:
	$(BATCH) \
		-l tests/test-sanad-health.el \
		-l tests/test-sanad-health-setup.el \
		-l tests/test-sanad-health-agenda.el \
		-l tests/test-sanad-health-meds.el \
		-l tests/test-sanad-health-capture.el \
		-l tests/test-sanad-health-pomodoro.el \
		-l tests/test-sanad-health-log.el \
		-l tests/test-sanad-health-tracker.el \
		-f ert-run-tests-batch-and-exit

test-%:
	$(BATCH) -l tests/test-sanad-health-$*.el -f ert-run-tests-batch-and-exit

clean:
	rm -f *.elc tests/*.elc
```

- [ ] **Step 4: Create the GitHub Actions workflow**

```yaml
name: Tests

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        emacs-version: ['28.2', '29.4']
    steps:
      - uses: actions/checkout@v4
      - uses: purcell/setup-emacs@master
        with:
          version: ${{ matrix.emacs-version }}
      - name: Run tests
        run: cd sanad-health && make test
```

- [ ] **Step 5: Commit**

```bash
git add sanad-health/tests/test-helper.el sanad-health/Makefile sanad-health/.github/workflows/test.yml
git commit -m "chore: scaffold project structure, test helper, Makefile, and CI"
```

---

## Task 2: Core Module (`sanad-health.el`)

**Files:**
- Create: `sanad-health/sanad-health.el`
- Create: `sanad-health/tests/test-sanad-health.el`

- [ ] **Step 1: Write the failing tests for core**

```elisp
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
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd sanad-health && make test-sanad-health
```

Expected: FAIL — `sanad-health` feature not found.

- [ ] **Step 3: Implement the core module**

```elisp
;;; sanad-health.el --- Health and ADHD management for Emacs -*- lexical-binding: t; -*-

;; Author: alarawms
;; Version: 0.1.0
;; Package-Requires: ((emacs "28.1") (org "9.6"))
;; URL: https://github.com/alarawms/sanad-emacs
;; Keywords: health, org, adhd, productivity

;;; Commentary:

;; Sanad Health Mode is a modular Emacs major mode for health and ADHD
;; management.  It provides a unified command center built on org-mode
;; with daily routines, medication tracking, brain dumps, pomodoro timers,
;; metric logging, and goal tracking.
;;
;; Entry point: M-x sanad-health-dashboard
;;
;; Global prefix: C-c h
;;
;; Modules (configure via `sanad-health-modules'):
;;   agenda   - org-agenda integration and routine blocks
;;   meds     - medication/supplement tracking and reminders
;;   capture  - brain dump and quick capture via org-capture
;;   pomodoro - pomodoro timer with org-clock integration
;;   log      - daily metrics logging and weekly aggregation
;;   tracker  - "Start My Day" interactive checklist
;;
;; On first launch, a setup wizard guides you through directory creation,
;; medication entry, and routine configuration.

;;; Code:

(require 'org)
(require 'org-element)

;;; --- Customization Group ---

(defgroup sanad-health nil
  "Health and ADHD management for Emacs."
  :group 'org
  :prefix "sanad-health-")

(defcustom sanad-health-directory nil
  "Path to the user's health data directory.
When nil, the setup wizard runs on first dashboard open."
  :type '(choice (const :tag "Not configured" nil)
                 (directory :tag "Health directory"))
  :group 'sanad-health)

(defcustom sanad-health-modules '(agenda meds capture pomodoro log tracker)
  "List of sanad-health modules to load.
Each symbol corresponds to a feature `sanad-health-SYMBOL'."
  :type '(repeat (choice (const :tag "Agenda & Routines" agenda)
                         (const :tag "Medications" meds)
                         (const :tag "Brain Dump / Capture" capture)
                         (const :tag "Pomodoro Timer" pomodoro)
                         (const :tag "Daily Log" log)
                         (const :tag "Start My Day Tracker" tracker)))
  :group 'sanad-health)

(defcustom sanad-health-show-hints t
  "When non-nil, show inline keybinding hints in buffers."
  :type 'boolean
  :group 'sanad-health)

(defcustom sanad-health-user-name nil
  "User's display name for the dashboard header."
  :type '(choice (const :tag "Not set" nil)
                 (string :tag "Name"))
  :group 'sanad-health)

;;; --- Constants ---

(defconst sanad-health-dashboard-buffer-name "*Sanad Health*"
  "Name of the dashboard buffer.")

(defconst sanad-health-version "0.1.0"
  "Current version of sanad-health.")

;;; --- Internal State ---

(defvar sanad-health--modules-loaded nil
  "List of modules that have been loaded.")

(defvar sanad-health--refresh-timer nil
  "Timer for periodic dashboard refresh.")

;;; --- Path Helpers ---

(defun sanad-health-profile-path ()
  "Return the path to the user's profile.org file."
  (expand-file-name "profile.org" sanad-health-directory))

(defun sanad-health-subdirectory (name)
  "Return the path to subdirectory NAME inside the health directory."
  (expand-file-name name sanad-health-directory))

(defun sanad-health-logs-dir ()
  "Return the path to the logs directory."
  (sanad-health-subdirectory "logs"))

(defun sanad-health-routines-dir ()
  "Return the path to the routines directory."
  (sanad-health-subdirectory "routines"))

(defun sanad-health-meds-dir ()
  "Return the path to the meds directory."
  (sanad-health-subdirectory "meds"))

(defun sanad-health-captures-dir ()
  "Return the path to the captures directory."
  (sanad-health-subdirectory "captures"))

(defun sanad-health-captures-file ()
  "Return the path to captures/inbox.org."
  (expand-file-name "inbox.org" (sanad-health-captures-dir)))

(defun sanad-health-meds-file ()
  "Return the path to meds/medications.org."
  (expand-file-name "medications.org" (sanad-health-meds-dir)))

(defun sanad-health-routines-file ()
  "Return the path to routines/daily.org."
  (expand-file-name "daily.org" (sanad-health-routines-dir)))

(defun sanad-health-goals-file ()
  "Return the path to routines/goals.org."
  (expand-file-name "goals.org" (sanad-health-routines-dir)))

;;; --- Profile ---

(defun sanad-health-profile-get (property)
  "Read PROPERTY from the Preferences heading in profile.org.
Returns the property value as a string, or nil if not found."
  (let ((profile-path (sanad-health-profile-path)))
    (when (file-exists-p profile-path)
      (with-temp-buffer
        (insert-file-contents profile-path)
        (org-mode)
        (goto-char (point-min))
        (when (re-search-forward "^\\* Preferences" nil t)
          (org-entry-get (point) property))))))

(defun sanad-health-profile-set (property value)
  "Set PROPERTY to VALUE in the Preferences heading of profile.org."
  (let ((profile-path (sanad-health-profile-path)))
    (when (file-exists-p profile-path)
      (with-current-buffer (find-file-noselect profile-path)
        (goto-char (point-min))
        (when (re-search-forward "^\\* Preferences" nil t)
          (org-entry-put (point) property value))
        (save-buffer)))))

;;; --- Module Loading ---

(defun sanad-health--module-feature (module)
  "Return the feature symbol for MODULE.
MODULE is a symbol like `agenda', returns `sanad-health-agenda'."
  (intern (format "sanad-health-%s" module)))

(defun sanad-health-load-modules ()
  "Load all modules listed in `sanad-health-modules'."
  (dolist (mod sanad-health-modules)
    (let ((feature (sanad-health--module-feature mod)))
      (unless (memq feature sanad-health--modules-loaded)
        (condition-case err
            (progn
              (require feature)
              (push feature sanad-health--modules-loaded))
          (error
           (message "sanad-health: failed to load module %s: %s"
                    mod (error-message-string err))))))))

;;; --- Dashboard ---

(defvar sanad-health-dashboard-mode-map
  (let ((map (make-sparse-keymap)))
    (set-keymap-parent map special-mode-map)
    (define-key map "c" #'sanad-health-capture)
    (define-key map "t" #'sanad-health-tracker)
    (define-key map "l" #'sanad-health-open-log)
    (define-key map "p" #'sanad-health-pomodoro-start)
    (define-key map "m" #'sanad-health-meds-take)
    (define-key map "a" #'sanad-health-assign-block)
    (define-key map "r" #'sanad-health-refile)
    (define-key map "s" #'sanad-health-settings)
    (define-key map "g" #'sanad-health-dashboard-refresh)
    (define-key map "?" #'sanad-health-help)
    map)
  "Keymap for `sanad-health-dashboard-mode'.")

(define-derived-mode sanad-health-dashboard-mode special-mode "Sanad Health"
  "Major mode for the Sanad Health dashboard.
\\{sanad-health-dashboard-mode-map}"
  (setq-local revert-buffer-function #'sanad-health-dashboard-refresh)
  (setq buffer-read-only t))

(defun sanad-health-dashboard ()
  "Open the Sanad Health dashboard.
On first run (when `sanad-health-directory' is nil), launches the
setup wizard instead."
  (interactive)
  (if (or (null sanad-health-directory)
          (not (file-directory-p sanad-health-directory)))
      (if (fboundp 'sanad-health-setup-wizard)
          (sanad-health-setup-wizard)
        (user-error "sanad-health-setup not loaded. Add 'setup' to sanad-health-modules or run (require 'sanad-health-setup)"))
    ;; Load modules if not yet loaded
    (sanad-health-load-modules)
    ;; Create or switch to dashboard buffer
    (let ((buf (get-buffer-create sanad-health-dashboard-buffer-name)))
      (switch-to-buffer buf)
      (unless (eq major-mode 'sanad-health-dashboard-mode)
        (sanad-health-dashboard-mode))
      (sanad-health-dashboard--render))))

(defun sanad-health-dashboard-refresh (&optional _ignore-auto _noconfirm)
  "Refresh the dashboard buffer contents."
  (interactive)
  (when (get-buffer sanad-health-dashboard-buffer-name)
    (with-current-buffer sanad-health-dashboard-buffer-name
      (sanad-health-dashboard--render))))

(defun sanad-health-dashboard--render ()
  "Render the dashboard buffer contents."
  (let ((inhibit-read-only t)
        (user-name (or sanad-health-user-name
                       (sanad-health-profile-get "SANAD_USER")
                       "User"))
        (today (format-time-string "%A %b %d, %Y")))
    (erase-buffer)
    ;; Header
    (insert (propertize (format " Sanad Health \u2014 %s \u2014 %s\n" user-name today)
                        'face '(:weight bold :height 1.2)))
    (insert (make-string 50 ?\u2500) "\n\n")
    ;; Metrics section
    (sanad-health-dashboard--insert-metrics)
    (insert "\n" (make-string 50 ?\u2500) "\n\n")
    ;; Agenda section
    (sanad-health-dashboard--insert-agenda)
    (insert "\n" (make-string 50 ?\u2500) "\n\n")
    ;; Brain dump section
    (sanad-health-dashboard--insert-brain-dump)
    ;; Welcome overlay for first-time users
    (sanad-health-dashboard--maybe-show-welcome)
    (goto-char (point-min))))

(defun sanad-health-dashboard--insert-metrics ()
  "Insert the metrics summary section into the dashboard."
  (insert (propertize "Dashboard\n" 'face '(:weight bold)))
  ;; Try to read today's log metrics
  (let ((focus (or (sanad-health-dashboard--today-metric "FOCUS") "\u2014"))
        (sleep (or (sanad-health-dashboard--today-metric "SLEEP") "\u2014"))
        (energy (or (sanad-health-dashboard--today-metric "ENERGY") "\u2014"))
        (mood (or (sanad-health-dashboard--today-metric "MOOD") "\u2014")))
    (insert (format "  Focus: %s/10  Sleep: %s/10  Energy: %s/10  Mood: %s/10\n"
                    focus sleep energy mood))))

(defun sanad-health-dashboard--today-metric (metric)
  "Read METRIC from today's daily log, or nil if not available."
  (when (fboundp 'sanad-health-log-today-path)
    (let ((log-path (sanad-health-log-today-path)))
      (when (and log-path (file-exists-p log-path))
        (with-temp-buffer
          (insert-file-contents log-path)
          (org-mode)
          (goto-char (point-min))
          (when (re-search-forward "^\\* Metrics" nil t)
            (let ((val (org-entry-get (point) metric)))
              (when (and val (not (string-empty-p val)))
                val))))))))

(defun sanad-health-dashboard--insert-agenda ()
  "Insert today's agenda items into the dashboard."
  (insert (propertize "Agenda (today)\n" 'face '(:weight bold)))
  (if (and (fboundp 'sanad-health-agenda-today-items)
           (sanad-health-agenda-today-items))
      (dolist (item (sanad-health-agenda-today-items))
        (let* ((time (plist-get item :time))
               (title (plist-get item :title))
               (assigned (plist-get item :assigned))
               (is-pomodoro (plist-get item :pomodoro))
               (hint-str (if sanad-health-show-hints
                             (cond
                              (is-pomodoro "    [p] start pomodoro")
                              ((and (not assigned) (string-empty-p (or assigned "")))
                               "    [a] assign")
                              (t ""))
                           "")))
          (insert (format "  %s  %s%s%s\n"
                          (or time "     ")
                          title
                          (if (and assigned (not (string-empty-p assigned)))
                              (format " \u2192 %s" assigned)
                            "")
                          hint-str))))
    (insert "  No routine items configured yet. Run setup or add to routines/daily.org\n")))

(defun sanad-health-dashboard--insert-brain-dump ()
  "Insert the brain dump / inbox section into the dashboard."
  (insert (propertize "Brain Dump\n" 'face '(:weight bold)))
  (let ((inbox-file (sanad-health-captures-file)))
    (if (file-exists-p inbox-file)
        (let ((items (sanad-health-dashboard--read-inbox inbox-file)))
          (if items
              (progn
                (dolist (item items)
                  (insert (format "  - [ ] %s\n" item)))
                (when sanad-health-show-hints
                  (insert "  [c] quick capture   [r] refile\n")))
            (insert "  Inbox empty. Press [c] to capture a thought.\n")))
      (insert "  No inbox file found. Press [c] to create one.\n"))))

(defun sanad-health-dashboard--read-inbox (file)
  "Read top-level TODO/entry headlines from inbox FILE under the Inbox heading."
  (when (file-exists-p file)
    (with-temp-buffer
      (insert-file-contents file)
      (org-mode)
      (goto-char (point-min))
      (let (items)
        (when (re-search-forward "^\\* Inbox" nil t)
          (let ((bound (save-excursion
                         (or (re-search-forward "^\\* " nil t)
                             (point-max)))))
            (while (re-search-forward "^\\*\\* \\(.*\\)$" bound t)
              (push (match-string 1) items))))
        (nreverse items)))))

(defun sanad-health-dashboard--maybe-show-welcome ()
  "Show welcome overlay on first use after onboarding."
  (let ((onboarded (sanad-health-profile-get "ONBOARDED"))
        (welcomed (sanad-health-profile-get "WELCOMED")))
    (when (and (equal onboarded "t")
               (not (equal welcomed "t")))
      (goto-char (point-min))
      (let ((inhibit-read-only t))
        (insert
         (propertize
          (concat
           "\u250C\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2510\n"
           "\u2502  Welcome to Sanad Health!                       \u2502\n"
           "\u2502                                                 \u2502\n"
           "\u2502  1. [t] Start My Day \u2014 check off your routine    \u2502\n"
           "\u2502  2. [m] Mark medication taken                    \u2502\n"
           "\u2502  3. [p] Start a pomodoro on a focus block        \u2502\n"
           "\u2502  4. [c] Brain dump a thought                     \u2502\n"
           "\u2502  5. [l] Log your daily metrics                   \u2502\n"
           "\u2502                                                 \u2502\n"
           "\u2502  Press [?] anytime for help                      \u2502\n"
           "\u2514\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2518\n\n")
          'face '(:foreground "cyan")))
      (sanad-health-profile-set "WELCOMED" "t"))))

;;; --- Stub Commands ---
;;
;; These are defined here so the dashboard keymap works even before
;; modules are loaded.  Each module replaces these with real implementations
;; via `defalias' or `advice-add'.

(defun sanad-health-capture ()
  "Quick capture a thought or task to the health inbox."
  (interactive)
  (if (fboundp 'sanad-health-capture--do)
      (sanad-health-capture--do)
    (user-error "Load the capture module: add 'capture to sanad-health-modules")))

(defun sanad-health-tracker ()
  "Open the Start My Day tracker."
  (interactive)
  (if (fboundp 'sanad-health-tracker--open)
      (sanad-health-tracker--open)
    (user-error "Load the tracker module: add 'tracker to sanad-health-modules")))

(defun sanad-health-open-log ()
  "Open today's daily log."
  (interactive)
  (if (fboundp 'sanad-health-log--open-today)
      (sanad-health-log--open-today)
    (user-error "Load the log module: add 'log to sanad-health-modules")))

(defun sanad-health-pomodoro-start ()
  "Start a pomodoro timer."
  (interactive)
  (if (fboundp 'sanad-health-pomodoro--start)
      (sanad-health-pomodoro--start)
    (user-error "Load the pomodoro module: add 'pomodoro to sanad-health-modules")))

(defun sanad-health-meds-take ()
  "Mark a medication as taken."
  (interactive)
  (if (fboundp 'sanad-health-meds--take)
      (sanad-health-meds--take)
    (user-error "Load the meds module: add 'meds to sanad-health-modules")))

(defun sanad-health-assign-block ()
  "Assign work to a focus block."
  (interactive)
  (if (fboundp 'sanad-health-agenda--assign-block)
      (sanad-health-agenda--assign-block)
    (user-error "Load the agenda module: add 'agenda to sanad-health-modules")))

(defun sanad-health-refile ()
  "Refile a brain dump item."
  (interactive)
  (if (fboundp 'sanad-health-capture--refile)
      (sanad-health-capture--refile)
    (user-error "Load the capture module: add 'capture to sanad-health-modules")))

(defun sanad-health-settings ()
  "Open the health profile settings."
  (interactive)
  (if sanad-health-directory
      (find-file (sanad-health-profile-path))
    (user-error "No health directory configured. Run M-x sanad-health-dashboard")))

(defun sanad-health-help ()
  "Show context-aware help for the current sanad-health buffer."
  (interactive)
  (let ((buf (get-buffer-create "*Sanad Health Help*"))
        (context (cond
                  ((eq major-mode 'sanad-health-dashboard-mode) 'dashboard)
                  ((eq major-mode 'sanad-health-tracker-mode) 'tracker)
                  (t 'general))))
    (with-current-buffer buf
      (let ((inhibit-read-only t))
        (erase-buffer)
        (insert (propertize "Sanad Health \u2014 Keybindings\n" 'face '(:weight bold :height 1.2)))
        (insert (make-string 40 ?\u2500) "\n\n")
        (pcase context
          ('dashboard
           (insert "Navigation\n")
           (insert "  t   Start My Day tracker\n")
           (insert "  l   Today's log\n")
           (insert "  s   Settings / profile\n\n")
           (insert "Actions\n")
           (insert "  c   Quick capture (brain dump)\n")
           (insert "  m   Mark medication taken\n")
           (insert "  p   Start pomodoro\n")
           (insert "  a   Assign focus block\n")
           (insert "  r   Refile item\n")
           (insert "  g   Refresh\n\n")
           (insert "Global (C-c h)\n")
           (insert "  C-c h d   Dashboard\n")
           (insert "  C-c h a   Health agenda\n")
           (insert "  C-c h m   Medications prefix\n")
           (insert "  C-c h p   Pomodoro prefix\n")
           (insert "  C-c h l   Log prefix\n"))
          ('tracker
           (insert "Tracker\n")
           (insert "  RET  Toggle item done/undone\n")
           (insert "  a    Assign work to focus block\n")
           (insert "  p    Start pomodoro\n")
           (insert "  n    Add note to item\n")
           (insert "  e    End-of-day review\n")
           (insert "  g    Refresh\n")
           (insert "  q    Back to dashboard\n"))
          (_
           (insert "Global Bindings (C-c h)\n")
           (insert "  C-c h d   Dashboard\n")
           (insert "  C-c h a   Health agenda\n")
           (insert "  C-c h c   Quick capture\n")
           (insert "  C-c h t   Start My Day tracker\n")
           (insert "  C-c h l   Log prefix\n")
           (insert "  C-c h p   Pomodoro prefix\n")
           (insert "  C-c h m   Medications prefix\n")
           (insert "  C-c h s   Settings\n")
           (insert "  C-c h ?   This help\n")))
        (insert "\n\nPress q to close.")
        (special-mode)))
    (pop-to-buffer buf)))

(defun sanad-health-toggle-hints ()
  "Toggle inline keybinding hints in sanad-health buffers."
  (interactive)
  (setq sanad-health-show-hints (not sanad-health-show-hints))
  (sanad-health-profile-set "SHOW_HINTS" (if sanad-health-show-hints "t" "nil"))
  (message "Sanad Health hints %s" (if sanad-health-show-hints "enabled" "disabled"))
  (when (get-buffer sanad-health-dashboard-buffer-name)
    (sanad-health-dashboard-refresh)))

;;; --- Global Keymap ---

(defvar sanad-health-command-map
  (let ((map (make-sparse-keymap)))
    (define-key map "d" #'sanad-health-dashboard)
    (define-key map "c" #'sanad-health-capture)
    (define-key map "t" #'sanad-health-tracker)
    (define-key map "s" #'sanad-health-settings)
    (define-key map "?" #'sanad-health-help)
    (define-key map "h" #'sanad-health-toggle-hints)
    map)
  "Command map for sanad-health global bindings.
Bound to the prefix `C-c h'.")

(global-set-key (kbd "C-c h") sanad-health-command-map)

(provide 'sanad-health)
;;; sanad-health.el ends here
```

- [ ] **Step 4: Run the tests**

```bash
cd sanad-health && make test-sanad-health
```

Expected: All tests PASS.

- [ ] **Step 5: Commit**

```bash
git add sanad-health/sanad-health.el sanad-health/tests/test-sanad-health.el
git commit -m "feat: add core module with dashboard, profiles, module loader, and keybindings"
```

---

## Task 3: Templates

**Files:**
- Create: `sanad-health/templates/daily-log.org`
- Create: `sanad-health/templates/routine.org`
- Create: `sanad-health/templates/supplements.org`

- [ ] **Step 1: Create the daily log template**

```org
#+TITLE: Daily Log — %DATE%
#+FILETAGS: :sanad:log:

* Metrics
:PROPERTIES:
:FOCUS:
:SLEEP:
:ENERGY:
:MOOD:
:PRODUCTIVITY:
:DOPAMINE_CTRL:
:BEST_FOCUS_TIME:
:WORST_FOCUS_TIME:
:END:

* Medications
%MEDICATIONS%

* Routine Completion
%ROUTINES%

* Pomodoros
| # | Task | Project | Start | End | Completed |
|---+------+---------+-------+-----+-----------|

* Side Effects / Adjustments

* Notes
```

- [ ] **Step 2: Create the default routine template**

```org
#+TITLE: Daily Routine
#+CATEGORY: Health
#+FILETAGS: :sanad:

* Routines
** TODO Wake + hydrate
   SCHEDULED: <%%(diary-daily)>
   :PROPERTIES:
   :EFFORT:   5min
   :BLOCK:    morning
   :ORDER:    1
   :END:

** TODO Morning meds
   SCHEDULED: <%%(diary-daily)>
   :PROPERTIES:
   :EFFORT:   2min
   :BLOCK:    morning
   :ORDER:    2
   :MEDS:     t
   :END:

** TODO Protein breakfast
   SCHEDULED: <%%(diary-daily)>
   :PROPERTIES:
   :EFFORT:   20min
   :BLOCK:    morning
   :ORDER:    3
   :END:

** TODO Focus Block 1
   SCHEDULED: <%%(diary-daily)>
   :PROPERTIES:
   :EFFORT:   90min
   :BLOCK:    morning
   :ORDER:    4
   :POMODORO: t
   :ASSIGNED:
   :GOAL:
   :END:

** TODO Exercise break
   SCHEDULED: <%%(diary-daily)>
   :PROPERTIES:
   :EFFORT:   30min
   :BLOCK:    midday
   :ORDER:    1
   :END:

** TODO Focus Block 2
   SCHEDULED: <%%(diary-daily)>
   :PROPERTIES:
   :EFFORT:   90min
   :BLOCK:    midday
   :ORDER:    2
   :POMODORO: t
   :ASSIGNED:
   :GOAL:
   :END:

** TODO Lunch + supplements
   SCHEDULED: <%%(diary-daily)>
   :PROPERTIES:
   :EFFORT:   30min
   :BLOCK:    midday
   :ORDER:    3
   :END:

** TODO Focus Block 3
   SCHEDULED: <%%(diary-daily)>
   :PROPERTIES:
   :EFFORT:   90min
   :BLOCK:    afternoon
   :ORDER:    1
   :POMODORO: t
   :ASSIGNED:
   :GOAL:
   :END:

** TODO Prep for tomorrow
   SCHEDULED: <%%(diary-daily)>
   :PROPERTIES:
   :EFFORT:   15min
   :BLOCK:    afternoon
   :ORDER:    2
   :END:

** TODO Digital sunset
   SCHEDULED: <%%(diary-daily)>
   :PROPERTIES:
   :EFFORT:   5min
   :BLOCK:    evening
   :ORDER:    1
   :END:

** TODO Sleep on time
   SCHEDULED: <%%(diary-daily)>
   :PROPERTIES:
   :EFFORT:   5min
   :BLOCK:    evening
   :ORDER:    2
   :END:
```

- [ ] **Step 3: Create the supplements reference template**

```org
#+TITLE: Supplement Reference
#+CATEGORY: Meds
#+FILETAGS: :sanad:meds:

* Medications

* Supplements

* Inactive

* Side Effects Log
```

- [ ] **Step 4: Commit**

```bash
git add sanad-health/templates/
git commit -m "feat: add org templates for daily log, routines, and supplements"
```

---

## Task 4: Setup Wizard (`sanad-health-setup.el`)

**Files:**
- Create: `sanad-health/sanad-health-setup.el`
- Create: `sanad-health/tests/test-sanad-health-setup.el`

- [ ] **Step 1: Write failing tests**

```elisp
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
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd sanad-health && make test-setup
```

Expected: FAIL — `sanad-health-setup` feature not found.

- [ ] **Step 3: Implement the setup wizard**

```elisp
;;; sanad-health-setup.el --- Onboarding wizard for sanad-health -*- lexical-binding: t; -*-

;; Author: alarawms
;; Keywords: health, org, adhd

;;; Commentary:

;; First-run setup wizard for sanad-health.  Triggered automatically when
;; `sanad-health-dashboard' is called with no health directory configured.
;;
;; The wizard guides the user through:
;; 1. Choosing a health data directory (recommends syncable location)
;; 2. Creating the folder structure (logs, routines, meds, captures)
;; 3. Setting up a user profile (name, conditions)
;; 4. Adding medications with dosage and timing
;; 5. Installing default routine blocks
;; 6. Selecting which modules to enable
;;
;; All data is stored as .org files for full org-mode compatibility.

;;; Code:

(require 'sanad-health)

(defvar sanad-health-setup--template-dir
  (expand-file-name "templates"
                    (file-name-directory
                     (or load-file-name buffer-file-name
                         (locate-library "sanad-health-setup"))))
  "Directory containing template files shipped with the package.")

;;; --- Directory Creation ---

(defun sanad-health-setup--create-directories (dir)
  "Create the standard health subdirectories inside DIR."
  (dolist (subdir '("logs" "routines" "meds" "captures"))
    (make-directory (expand-file-name subdir dir) t)))

;;; --- Profile Creation ---

(defun sanad-health-setup--create-profile (dir user-name conditions)
  "Create profile.org in DIR with USER-NAME and CONDITIONS."
  (let ((profile-path (expand-file-name "profile.org" dir)))
    (with-temp-file profile-path
      (insert (format "#+TITLE: Health Profile
#+PROPERTY: SANAD_USER %s
#+PROPERTY: SANAD_CONDITIONS %s
#+PROPERTY: SANAD_MODULES %s

* Preferences
:PROPERTIES:
:WAKE_TIME: 06:30
:SLEEP_TIME: 22:00
:POMODORO_WORK: 25
:POMODORO_BREAK: 5
:POMODORO_LONG_BREAK: 15
:POMODORO_SESSIONS: 4
:ONBOARDED: t
:SHOW_HINTS: t
:WELCOMED: nil
:END:
"
                      user-name
                      conditions
                      (mapconcat #'symbol-name sanad-health-modules " "))))))

;;; --- Inbox Creation ---

(defun sanad-health-setup--create-inbox (dir)
  "Create captures/inbox.org in DIR."
  (with-temp-file (expand-file-name "captures/inbox.org" dir)
    (insert "#+TITLE: Health Inbox
#+FILETAGS: :sanad:inbox:

* Inbox

* Notes
")))

;;; --- Template Installation ---

(defun sanad-health-setup--install-routine-template (dir)
  "Copy the default routine template to DIR/routines/daily.org."
  (let ((src (expand-file-name "routine.org" sanad-health-setup--template-dir))
        (dst (expand-file-name "routines/daily.org" dir)))
    (if (file-exists-p src)
        (copy-file src dst t)
      ;; Fallback: create a minimal routine file
      (with-temp-file dst
        (insert "#+TITLE: Daily Routine
#+CATEGORY: Health
#+FILETAGS: :sanad:

* Routines
** TODO Morning routine
   SCHEDULED: <%%(diary-daily)>
   :PROPERTIES:
   :BLOCK: morning
   :ORDER: 1
   :END:
")))))

(defun sanad-health-setup--install-meds-template (dir)
  "Copy the supplements template to DIR/meds/medications.org."
  (let ((src (expand-file-name "supplements.org" sanad-health-setup--template-dir))
        (dst (expand-file-name "meds/medications.org" dir)))
    (if (file-exists-p src)
        (copy-file src dst t)
      ;; Fallback: create a minimal meds file
      (with-temp-file dst
        (insert "#+TITLE: Supplement Reference
#+CATEGORY: Meds
#+FILETAGS: :sanad:meds:

* Medications

* Supplements

* Inactive

* Side Effects Log
")))))

;;; --- Medication Entry ---

(defun sanad-health-setup--add-medication (dir name dosage frequency times with-food prescriber)
  "Add a medication entry to medications.org in DIR.
NAME is the medication name, DOSAGE the dose string,
FREQUENCY is daily/twice-daily/weekly/as-needed,
TIMES is the time string (e.g., \"07:00\" or \"07:00 13:00\"),
WITH-FOOD is t or nil, PRESCRIBER is a string or nil."
  (let ((meds-file (expand-file-name "meds/medications.org" dir)))
    (with-current-buffer (find-file-noselect meds-file)
      (goto-char (point-min))
      (if (re-search-forward "^\\* Medications" nil t)
          (progn
            (end-of-line)
            (insert (format "\n** %s %s%s
   :PROPERTIES:
   :DOSAGE:    %s
   :FREQUENCY: %s
   :TIMES:     %s
   :WITH_FOOD: %s%s
   :STARTED:   %s
   :END:
"
                            name dosage
                            "                                  :prescription:"
                            dosage
                            frequency
                            times
                            (if with-food "yes" "no")
                            (if prescriber
                                (format "\n   :PRESCRIBER: %s" prescriber)
                              "")
                            (format-time-string "[%Y-%m-%d %a]"))))
        (goto-char (point-max))
        (insert (format "\n* Medications\n** %s %s\n" name dosage)))
      (save-buffer)
      (kill-buffer))))

(defun sanad-health-setup--add-supplement (dir name dosage frequency times with-food evidence cost-tier phase)
  "Add a supplement entry to medications.org in DIR.
NAME, DOSAGE, FREQUENCY, TIMES, WITH-FOOD as in `sanad-health-setup--add-medication'.
EVIDENCE is strong/moderate/mixed, COST-TIER is budget/mid/premium,
PHASE is foundation/deficiency-correction/fine-tuning/optimize."
  (let ((meds-file (expand-file-name "meds/medications.org" dir)))
    (with-current-buffer (find-file-noselect meds-file)
      (goto-char (point-min))
      (if (re-search-forward "^\\* Supplements" nil t)
          (progn
            (end-of-line)
            (insert (format "\n** %s%s
   :PROPERTIES:
   :DOSAGE:    %s
   :FREQUENCY: %s
   :TIMES:     %s
   :WITH_FOOD: %s
   :EVIDENCE:  %s
   :COST_TIER: %s
   :PHASE:     %s
   :STARTED:   %s
   :END:
"
                            name
                            "                                  :supplement:"
                            dosage
                            frequency
                            times
                            (if with-food "yes" "no")
                            evidence
                            cost-tier
                            phase
                            (format-time-string "[%Y-%m-%d %a]"))))
        (goto-char (point-max))
        (insert (format "\n* Supplements\n** %s\n" name)))
      (save-buffer)
      (kill-buffer))))

;;; --- Goals File ---

(defun sanad-health-setup--create-goals-file (dir)
  "Create routines/goals.org in DIR."
  (with-temp-file (expand-file-name "routines/goals.org" dir)
    (insert "#+TITLE: Goals & Projects
#+CATEGORY: Goals
#+FILETAGS: :sanad:goals:

* Active Projects

* Goals
** Daily                                             :daily:
** Quarterly                                         :quarterly:
")))

;;; --- Interactive Wizard ---

(defun sanad-health-setup-wizard ()
  "Run the interactive onboarding wizard for sanad-health.
Guides the user through directory setup, profile creation,
medication entry, and routine configuration."
  (interactive)
  ;; Step 1: Welcome
  (message "")
  (when (not (y-or-n-p "Welcome to Sanad Health! Ready to set up your health tracking? "))
    (user-error "Setup cancelled. Run M-x sanad-health-dashboard when ready"))

  ;; Step 2: Choose directory
  (let* ((default-dir (cond
                       ((file-directory-p "~/Dropbox/") "~/Dropbox/health/")
                       ((file-directory-p "~/org/") "~/org/health/")
                       (t "~/health/")))
         (dir (read-directory-name
               (format "Health directory (syncable recommended) [%s]: " default-dir)
               nil default-dir))
         (dir (expand-file-name dir)))

    ;; Warn if not syncable
    (unless (or (string-match-p "Dropbox\\|Google Drive\\|Syncthing\\|org" dir))
      (when (not (y-or-n-p
                  "This directory may not be synced across devices. Continue anyway? "))
        (user-error "Setup cancelled")))

    ;; Step 3: Create structure
    (make-directory dir t)
    (sanad-health-setup--create-directories dir)

    ;; Step 4: User profile
    (let ((name (read-string "Your name: "))
          (conditions (completing-read-multiple
                       "Conditions (comma-separated, e.g., ADHD, anxiety): "
                       '("ADHD" "anxiety" "depression" "chronic-pain"
                         "insomnia" "bipolar" "OCD" "PTSD" "other"))))
      (sanad-health-setup--create-profile
       dir name (mapconcat #'identity conditions " ")))

    ;; Step 5: Medications
    (while (y-or-n-p "Add a medication? ")
      (let ((name (read-string "Medication name: "))
            (dosage (read-string "Dosage (e.g., 40mg): "))
            (frequency (completing-read "Frequency: "
                                        '("daily" "twice-daily" "weekly" "as-needed")))
            (times (read-string "Time(s) to take (e.g., 07:00 or 07:00 13:00): "))
            (with-food (y-or-n-p "Take with food? "))
            (prescriber (let ((p (read-string "Prescriber (optional, press RET to skip): ")))
                          (if (string-empty-p p) nil p))))
        (sanad-health-setup--add-medication dir name dosage frequency times with-food prescriber)))

    ;; Step 5b: Supplements
    (while (y-or-n-p "Add a supplement? ")
      (let ((name (read-string "Supplement name: "))
            (dosage (read-string "Dosage (e.g., 400mg): "))
            (frequency (completing-read "Frequency: "
                                        '("daily" "twice-daily" "weekly" "as-needed")))
            (times (read-string "Time(s) to take: "))
            (with-food (y-or-n-p "Take with food? "))
            (evidence (completing-read "Evidence level: "
                                       '("strong" "moderate" "mixed")))
            (cost-tier (completing-read "Cost tier: "
                                        '("budget" "mid" "premium")))
            (phase (completing-read "Phase: "
                                    '("foundation" "deficiency-correction"
                                      "fine-tuning" "optimize"))))
        (sanad-health-setup--add-supplement dir name dosage frequency times with-food
                                            evidence cost-tier phase)))

    ;; Step 6: Routine
    (if (y-or-n-p "Install default ADHD daily routine? (Recommended) ")
        (sanad-health-setup--install-routine-template dir)
      ;; Install minimal routine
      (with-temp-file (expand-file-name "routines/daily.org" dir)
        (insert "#+TITLE: Daily Routine\n#+CATEGORY: Health\n#+FILETAGS: :sanad:\n\n* Routines\n")))

    ;; Step 6b: Install meds template if not already populated
    (unless (file-exists-p (expand-file-name "meds/medications.org" dir))
      (sanad-health-setup--install-meds-template dir))

    ;; Step 7: Create inbox and goals
    (sanad-health-setup--create-inbox dir)
    (sanad-health-setup--create-goals-file dir)

    ;; Step 8: Save config
    (customize-save-variable 'sanad-health-directory dir)
    (customize-save-variable 'sanad-health-user-name
                             (sanad-health-profile-get "SANAD_USER"))

    ;; Done — open dashboard
    (message "Setup complete! Opening your dashboard...")
    (sanad-health-dashboard)))

(provide 'sanad-health-setup)
;;; sanad-health-setup.el ends here
```

- [ ] **Step 4: Run the tests**

```bash
cd sanad-health && make test-setup
```

Expected: All tests PASS.

- [ ] **Step 5: Commit**

```bash
git add sanad-health/sanad-health-setup.el sanad-health/tests/test-sanad-health-setup.el
git commit -m "feat: add onboarding setup wizard with directory, profile, and medication creation"
```

---

## Task 5: Agenda Integration (`sanad-health-agenda.el`)

**Files:**
- Create: `sanad-health/sanad-health-agenda.el`
- Create: `sanad-health/tests/test-sanad-health-agenda.el`

- [ ] **Step 1: Write failing tests**

```elisp
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
    ;; Both should now be TODO
    (should (= (length (s-match-strings-all "TODO" (buffer-string))) 2))
    (should (= (length (s-match-strings-all "DONE" (buffer-string))) 0)))
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
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd sanad-health && make test-agenda
```

Expected: FAIL — `sanad-health-agenda` feature not found.

- [ ] **Step 3: Implement the agenda module**

```elisp
;;; sanad-health-agenda.el --- Org-agenda integration for sanad-health -*- lexical-binding: t; -*-

;; Author: alarawms
;; Keywords: health, org, adhd

;;; Commentary:

;; Integrates sanad-health routine blocks with org-agenda.
;;
;; Features:
;; - Reads routine blocks from routines/daily.org
;; - Groups items by time-of-day block (morning, midday, afternoon, evening)
;; - Provides custom agenda views filtered by :sanad: tag
;; - Focus block assignment to projects/goals
;; - Nightly reset of completed routine items
;; - Goals and habit tracking via routines/goals.org
;;
;; Custom agenda commands:
;;   C-c h a  - Health agenda (all items today, grouped by block)
;;   C-c h p  - Filter by project
;;   C-c h g  - Goals progress (habits + deadlines)

;;; Code:

(require 'sanad-health)
(require 'org-agenda)

;;; --- Reading Routine Blocks ---

(defun sanad-health-agenda--read-routine-blocks ()
  "Read routine entries from daily.org, return a list of plists.
Each plist has keys :title, :block, :order, :pomodoro, :meds,
:assigned, :goal, :effort."
  (let ((routine-file (sanad-health-routines-file))
        items)
    (when (file-exists-p routine-file)
      (with-temp-buffer
        (insert-file-contents routine-file)
        (org-mode)
        (goto-char (point-min))
        (org-map-entries
         (lambda ()
           (let ((title (org-get-heading t t t t))
                 (block (org-entry-get (point) "BLOCK"))
                 (order (org-entry-get (point) "ORDER"))
                 (pomodoro (org-entry-get (point) "POMODORO"))
                 (meds (org-entry-get (point) "MEDS"))
                 (assigned (org-entry-get (point) "ASSIGNED"))
                 (goal (org-entry-get (point) "GOAL"))
                 (effort (org-entry-get (point) "EFFORT"))
                 (todo-state (org-get-todo-state)))
             (when block
               (push (list :title title
                           :block block
                           :order (if order (string-to-number order) 99)
                           :pomodoro (equal pomodoro "t")
                           :meds (equal meds "t")
                           :assigned (or assigned "")
                           :goal (or goal "")
                           :effort (or effort "")
                           :done (equal todo-state "DONE"))
                     items))))
         nil nil)))
    ;; Sort by block order then by ORDER property
    (let ((block-order '("morning" "midday" "afternoon" "evening")))
      (sort (nreverse items)
            (lambda (a b)
              (let ((ba (cl-position (plist-get a :block) block-order :test #'equal))
                    (bb (cl-position (plist-get b :block) block-order :test #'equal)))
                (if (= (or ba 99) (or bb 99))
                    (< (plist-get a :order) (plist-get b :order))
                  (< (or ba 99) (or bb 99)))))))))

(defun sanad-health-agenda-today-items ()
  "Return today's routine items as a list of plists for the dashboard.
Each plist includes :time, :title, :assigned, :pomodoro, :done."
  (let ((blocks (sanad-health-agenda--read-routine-blocks))
        (times (sanad-health-agenda--default-times)))
    (let ((idx 0))
      (mapcar (lambda (item)
                (let ((time (nth idx times)))
                  (setq idx (1+ idx))
                  (plist-put item :time (or time ""))))
              blocks))))

(defun sanad-health-agenda--default-times ()
  "Return a list of default times for routine blocks.
Based on the user's WAKE_TIME from profile, or 06:30 default."
  (let* ((wake (or (sanad-health-profile-get "WAKE_TIME") "06:30"))
         (wake-hour (string-to-number (substring wake 0 2)))
         (wake-min (string-to-number (substring wake 3 5))))
    ;; Generate times starting from wake time, spaced appropriately
    (list
     (format "%02d:%02d" wake-hour wake-min)                          ;; Wake
     (format "%02d:%02d" wake-hour (+ wake-min 30))                   ;; Meds
     (format "%02d:%02d" (1+ wake-hour) wake-min)                     ;; Breakfast
     (format "%02d:%02d" (+ wake-hour 1) (+ wake-min 30))            ;; Focus 1
     (format "%02d:%02d" (+ wake-hour 3) wake-min)                    ;; Exercise
     (format "%02d:%02d" (+ wake-hour 3) (+ wake-min 30))            ;; Focus 2
     (format "%02d:%02d" (+ wake-hour 5) (+ wake-min 30))            ;; Lunch
     (format "%02d:%02d" (+ wake-hour 6) (+ wake-min 30))            ;; Focus 3
     (format "%02d:%02d" (+ wake-hour 10) (+ wake-min 30))           ;; Prep
     (format "%02d:%02d" (+ wake-hour 14) (+ wake-min 30))           ;; Sunset
     (format "%02d:%02d" (+ wake-hour 15) (+ wake-min 30))           ;; Sleep
     )))

;;; --- Nightly Reset ---

(defun sanad-health-agenda--reset-routines ()
  "Reset all DONE routine items back to TODO in daily.org.
Called by the nightly reset timer."
  (let ((routine-file (sanad-health-routines-file)))
    (when (file-exists-p routine-file)
      (with-current-buffer (find-file-noselect routine-file)
        (org-map-entries
         (lambda ()
           (when (equal (org-get-todo-state) "DONE")
             (org-todo "TODO")))
         nil nil)
        (save-buffer)))))

(defvar sanad-health-agenda--reset-timer nil
  "Timer for nightly routine reset.")

(defun sanad-health-agenda-start-nightly-reset ()
  "Schedule the nightly routine reset.
Uses the SLEEP_TIME from profile.org, defaults to midnight."
  (when sanad-health-agenda--reset-timer
    (cancel-timer sanad-health-agenda--reset-timer))
  (let* ((sleep-time (or (sanad-health-profile-get "SLEEP_TIME") "00:00"))
         (hour (string-to-number (substring sleep-time 0 2)))
         (min (string-to-number (substring sleep-time 3 5))))
    (setq sanad-health-agenda--reset-timer
          (run-at-time (format "%02d:%02d" hour min)
                       (* 24 60 60)  ;; repeat daily
                       #'sanad-health-agenda--reset-routines))))

;;; --- Focus Block Assignment ---

(defun sanad-health-agenda--set-assignment (block-title project goal)
  "Set ASSIGNED to PROJECT and GOAL on the routine entry titled BLOCK-TITLE."
  (let ((routine-file (sanad-health-routines-file)))
    (when (file-exists-p routine-file)
      (with-current-buffer (find-file-noselect routine-file)
        (goto-char (point-min))
        (org-map-entries
         (lambda ()
           (when (equal (org-get-heading t t t t) block-title)
             (org-entry-put (point) "ASSIGNED" project)
             (org-entry-put (point) "GOAL" goal)))
         nil nil)
        (save-buffer)))))

(defun sanad-health-agenda--assign-block ()
  "Interactively assign a project and goal to a focus block."
  (interactive)
  (let* ((blocks (sanad-health-agenda--read-routine-blocks))
         (pomodoro-blocks (cl-remove-if-not
                           (lambda (b) (plist-get b :pomodoro))
                           blocks))
         (titles (mapcar (lambda (b) (plist-get b :title)) pomodoro-blocks))
         (block-title (completing-read "Assign focus block: " titles nil t))
         (project (read-string "Project (e.g., phd/chapter3): "))
         (goal (read-string "Session goal: ")))
    (sanad-health-agenda--set-assignment block-title project goal)
    (message "Assigned %s \u2192 %s (%s)" block-title project goal)
    (when (get-buffer sanad-health-dashboard-buffer-name)
      (sanad-health-dashboard-refresh))))

;;; --- Custom Agenda Views ---

(defun sanad-health-agenda-setup-commands ()
  "Add sanad-health custom commands to `org-agenda-custom-commands'."
  ;; Add health dir to agenda files
  (when sanad-health-directory
    (let ((routine-file (sanad-health-routines-file))
          (goals-file (sanad-health-goals-file)))
      (dolist (f (list routine-file goals-file))
        (when (file-exists-p f)
          (add-to-list 'org-agenda-files f)))))
  ;; Add custom agenda commands
  (add-to-list 'org-agenda-custom-commands
               '("sh" "Sanad Health Agenda"
                 ((tags-todo "sanad"
                             ((org-agenda-overriding-header "Health Routine")
                              (org-agenda-sorting-strategy '(priority-down)))))))
  (add-to-list 'org-agenda-custom-commands
               '("sg" "Sanad Health Goals"
                 ((tags "sanad+STYLE=\"habit\""
                        ((org-agenda-overriding-header "Health Habits")))
                  (tags "sanad+DEADLINE<>\"\""
                        ((org-agenda-overriding-header "Health Deadlines")))))))

(defun sanad-health-agenda ()
  "Open the sanad-health custom agenda view."
  (interactive)
  (sanad-health-agenda-setup-commands)
  (org-agenda nil "sh"))

;;; --- Register with Core ---

;; Add agenda keybindings to the global command map
(define-key sanad-health-command-map "a" #'sanad-health-agenda)

;; Start nightly reset when this module loads
(when sanad-health-directory
  (sanad-health-agenda-start-nightly-reset))

(provide 'sanad-health-agenda)
;;; sanad-health-agenda.el ends here
```

- [ ] **Step 4: Fix the nightly reset test**

The test uses `s-match-strings-all` from the `s` library. Replace with plain Elisp to avoid the dependency:

Replace the reset test assertion with:

```elisp
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
```

- [ ] **Step 5: Run the tests**

```bash
cd sanad-health && make test-agenda
```

Expected: All tests PASS.

- [ ] **Step 6: Commit**

```bash
git add sanad-health/sanad-health-agenda.el sanad-health/tests/test-sanad-health-agenda.el
git commit -m "feat: add org-agenda integration with routine blocks, assignment, and nightly reset"
```

---

## Task 6: Medication Tracking (`sanad-health-meds.el`)

**Files:**
- Create: `sanad-health/sanad-health-meds.el`
- Create: `sanad-health/tests/test-sanad-health-meds.el`

- [ ] **Step 1: Write failing tests**

```elisp
;;; tests/test-sanad-health-meds.el --- Tests for medication tracking -*- lexical-binding: t; -*-

;;; Commentary:
;; Tests for medication CRUD, reminders, stack review, and take confirmation.

;;; Code:

(require 'test-helper)
(require 'sanad-health)
(require 'sanad-health-meds)

(ert-deftest sanad-health-meds-test-read-active-medications ()
  "Should read active medication entries from medications.org."
  (sanad-health-test-setup)
  (make-directory (expand-file-name "meds" sanad-health-directory) t)
  (with-temp-file (expand-file-name "meds/medications.org" sanad-health-directory)
    (insert "#+CATEGORY: Meds\n\n")
    (insert "* Medications\n")
    (insert "** Vyvanse 40mg\n")
    (insert "   :PROPERTIES:\n   :DOSAGE: 40mg\n   :TIMES: 07:00\n   :FREQUENCY: daily\n   :END:\n")
    (insert "* Supplements\n")
    (insert "** Magnesium\n")
    (insert "   :PROPERTIES:\n   :DOSAGE: 400mg\n   :TIMES: 21:00\n   :FREQUENCY: daily\n   :END:\n")
    (insert "* Inactive\n"))
  (let ((meds (sanad-health-meds--read-active)))
    (should (= (length meds) 2))
    (should (equal (plist-get (car meds) :name) "Vyvanse 40mg"))
    (should (equal (plist-get (cadr meds) :name) "Magnesium")))
  (sanad-health-test-teardown))

(ert-deftest sanad-health-meds-test-record-taken ()
  "Recording a med as taken should add a LOGBOOK entry."
  (sanad-health-test-setup)
  (make-directory (expand-file-name "meds" sanad-health-directory) t)
  (with-temp-file (expand-file-name "meds/medications.org" sanad-health-directory)
    (insert "#+CATEGORY: Meds\n\n* Medications\n")
    (insert "** Vyvanse 40mg\n")
    (insert "   :PROPERTIES:\n   :DOSAGE: 40mg\n   :TIMES: 07:00\n   :END:\n"))
  (sanad-health-meds--record-taken "Vyvanse 40mg")
  (with-temp-buffer
    (insert-file-contents (expand-file-name "meds/medications.org" sanad-health-directory))
    (should (string-match-p "LOGBOOK" (buffer-string)))
    (should (string-match-p "Taken at" (buffer-string))))
  (sanad-health-test-teardown))

(ert-deftest sanad-health-meds-test-discontinue ()
  "Discontinuing a med should move it under the Inactive heading."
  (sanad-health-test-setup)
  (make-directory (expand-file-name "meds" sanad-health-directory) t)
  (with-temp-file (expand-file-name "meds/medications.org" sanad-health-directory)
    (insert "#+CATEGORY: Meds\n\n* Medications\n")
    (insert "** Vyvanse 40mg\n")
    (insert "   :PROPERTIES:\n   :DOSAGE: 40mg\n   :END:\n")
    (insert "* Inactive\n"))
  (sanad-health-meds--discontinue "Vyvanse 40mg" "side effects")
  (with-temp-buffer
    (insert-file-contents (expand-file-name "meds/medications.org" sanad-health-directory))
    ;; Should be under Inactive now
    (goto-char (point-min))
    (should (re-search-forward "^\\* Inactive" nil t))
    (should (re-search-forward "Vyvanse" nil t)))
  (sanad-health-test-teardown))

(ert-deftest sanad-health-meds-test-format-stack-table ()
  "Stack review should produce a formatted table string."
  (let ((meds (list (list :name "Vyvanse" :dosage "40mg" :times "07:00"
                          :evidence nil :cost-tier nil :phase nil)
                    (list :name "Magnesium" :dosage "400mg" :times "21:00"
                          :evidence "strong" :cost-tier "budget" :phase "foundation"))))
    (let ((table (sanad-health-meds--format-stack-table meds)))
      (should (stringp table))
      (should (string-match-p "Vyvanse" table))
      (should (string-match-p "Magnesium" table)))))

(provide 'test-sanad-health-meds)
;;; test-sanad-health-meds.el ends here
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd sanad-health && make test-meds
```

Expected: FAIL.

- [ ] **Step 3: Implement the meds module**

```elisp
;;; sanad-health-meds.el --- Medication tracking for sanad-health -*- lexical-binding: t; -*-

;; Author: alarawms
;; Keywords: health, org, adhd

;;; Commentary:

;; Medication and supplement tracking for sanad-health.
;;
;; Features:
;; - Read/add/edit/discontinue medications and supplements
;; - Timed reminders via `run-at-time' and `notifications-notify'
;; - Medication taken confirmation with LOGBOOK timestamps
;; - Stack review buffer (table view of all active meds)
;; - Supplement evaluation workflow (keep/drop/adjust)
;;
;; Keybindings (prefix C-c h m):
;;   a - Add medication or supplement
;;   e - Edit existing entry
;;   r - Review stack (table view)
;;   v - Evaluate supplement
;;   d - Discontinue
;;   h - History

;;; Code:

(require 'sanad-health)
(require 'notifications nil t)  ;; Optional: system notifications

;;; --- Reading Medications ---

(defun sanad-health-meds--read-active ()
  "Read all active medications and supplements from medications.org.
Returns a list of plists with :name, :dosage, :times, :frequency,
:with-food, :evidence, :cost-tier, :phase, :type."
  (let ((meds-file (sanad-health-meds-file))
        items current-section)
    (when (file-exists-p meds-file)
      (with-temp-buffer
        (insert-file-contents meds-file)
        (org-mode)
        (goto-char (point-min))
        (org-map-entries
         (lambda ()
           (let ((level (org-current-level))
                 (heading (org-get-heading t t t t)))
             (cond
              ((= level 1)
               (setq current-section heading))
              ((and (= level 2)
                    (not (equal current-section "Inactive"))
                    (not (equal current-section "Side Effects Log")))
               (push (list :name heading
                           :dosage (or (org-entry-get (point) "DOSAGE") "")
                           :times (or (org-entry-get (point) "TIMES") "")
                           :frequency (or (org-entry-get (point) "FREQUENCY") "")
                           :with-food (equal (org-entry-get (point) "WITH_FOOD") "yes")
                           :evidence (org-entry-get (point) "EVIDENCE")
                           :cost-tier (org-entry-get (point) "COST_TIER")
                           :phase (org-entry-get (point) "PHASE")
                           :type (if (equal current-section "Medications")
                                     "medication" "supplement"))
                     items)))))
         nil nil)))
    (nreverse items)))

;;; --- Recording Taken ---

(defun sanad-health-meds--record-taken (med-name)
  "Record that MED-NAME was taken by adding a LOGBOOK entry."
  (let ((meds-file (sanad-health-meds-file)))
    (with-current-buffer (find-file-noselect meds-file)
      (goto-char (point-min))
      (org-map-entries
       (lambda ()
         (when (equal (org-get-heading t t t t) med-name)
           ;; Add logbook entry
           (org-end-of-meta-data t)
           (unless (looking-at "[ \t]*:LOGBOOK:")
             (insert "   :LOGBOOK:\n   :END:\n")
             (forward-line -1))
           (when (re-search-forward ":LOGBOOK:" (line-end-position) t)
             (forward-line 1)
             (insert (format "   - Taken at %s\n"
                             (format-time-string "[%Y-%m-%d %a %H:%M]"))))))
       nil nil)
      (save-buffer))))

(defun sanad-health-meds--take ()
  "Interactively mark a medication as taken."
  (interactive)
  (let* ((meds (sanad-health-meds--read-active))
         (names (mapcar (lambda (m) (plist-get m :name)) meds))
         (chosen (completing-read "Mark as taken: " names nil t)))
    (sanad-health-meds--record-taken chosen)
    (message "Marked %s as taken at %s" chosen (format-time-string "%H:%M"))))

;;; --- Discontinue ---

(defun sanad-health-meds--discontinue (med-name reason)
  "Move MED-NAME to the Inactive section with REASON."
  (let ((meds-file (sanad-health-meds-file)))
    (with-current-buffer (find-file-noselect meds-file)
      (goto-char (point-min))
      ;; Find the entry
      (let (entry-text entry-start entry-end)
        (org-map-entries
         (lambda ()
           (when (equal (org-get-heading t t t t) med-name)
             (setq entry-start (point))
             (org-end-of-subtree t t)
             (setq entry-end (point))
             (setq entry-text (buffer-substring entry-start entry-end))))
         nil nil)
        (when entry-text
          ;; Delete from current location
          (delete-region entry-start entry-end)
          ;; Find Inactive heading and insert there
          (goto-char (point-min))
          (when (re-search-forward "^\\* Inactive" nil t)
            (end-of-line)
            (insert "\n" entry-text)
            ;; Add discontinuation note
            (goto-char (point-min))
            (when (re-search-forward "^\\* Inactive" nil t)
              (when (re-search-forward (regexp-quote med-name) nil t)
                (org-end-of-meta-data t)
                (insert (format "   DISCONTINUED: %s — %s\n"
                                (format-time-string "[%Y-%m-%d %a]")
                                reason)))))))
      (save-buffer))))

;;; --- Stack Review ---

(defun sanad-health-meds--format-stack-table (meds)
  "Format MEDS list as a readable table string."
  (let ((header (format "%-25s %-10s %-8s %-10s %-8s %-15s\n"
                        "Name" "Dosage" "Time" "Evidence" "Cost" "Phase"))
        (separator (make-string 76 ?\u2500)))
    (concat
     "Supplement Stack \u2014 Active\n"
     separator "\n"
     header
     separator "\n"
     (mapconcat
      (lambda (m)
        (format "%-25s %-10s %-8s %-10s %-8s %-15s"
                (plist-get m :name)
                (plist-get m :dosage)
                (plist-get m :times)
                (or (plist-get m :evidence) "\u2014")
                (or (plist-get m :cost-tier) "\u2014")
                (or (plist-get m :phase) "\u2014")))
      meds "\n")
     "\n" separator "\n")))

(defun sanad-health-meds-review ()
  "Open the medication stack review buffer."
  (interactive)
  (let* ((meds (sanad-health-meds--read-active))
         (buf (get-buffer-create "*Sanad Health Meds*")))
    (with-current-buffer buf
      (let ((inhibit-read-only t))
        (erase-buffer)
        (insert (sanad-health-meds--format-stack-table meds))
        (when sanad-health-show-hints
          (insert "\n[a] add  [v] evaluate  [d] discontinue  [h] history  [q] close\n")))
      (special-mode))
    (pop-to-buffer buf)))

;;; --- Add Medication/Supplement (Interactive) ---

(defun sanad-health-meds-add ()
  "Interactively add a new medication or supplement."
  (interactive)
  (let* ((type (completing-read "Type: " '("medication" "supplement") nil t))
         (name (read-string (format "%s name: " (capitalize type))))
         (dosage (read-string "Dosage (e.g., 40mg): "))
         (frequency (completing-read "Frequency: "
                                     '("daily" "twice-daily" "weekly" "as-needed") nil t))
         (times (read-string "Time(s) (e.g., 07:00 or 07:00 13:00): "))
         (with-food (y-or-n-p "Take with food? ")))
    (if (equal type "medication")
        (let ((prescriber (let ((p (read-string "Prescriber (optional, RET to skip): ")))
                            (if (string-empty-p p) nil p))))
          (sanad-health-setup--add-medication
           sanad-health-directory name dosage frequency times with-food prescriber))
      (let ((evidence (completing-read "Evidence: " '("strong" "moderate" "mixed") nil t))
            (cost-tier (completing-read "Cost tier: " '("budget" "mid" "premium") nil t))
            (phase (completing-read "Phase: "
                                    '("foundation" "deficiency-correction"
                                      "fine-tuning" "optimize") nil t)))
        (sanad-health-setup--add-supplement
         sanad-health-directory name dosage frequency times with-food
         evidence cost-tier phase)))
    ;; Set up reminder immediately
    (sanad-health-meds--setup-reminder name times)
    (message "Added %s. Reminder set for %s." name times)))

;;; --- Reminders ---

(defvar sanad-health-meds--reminder-timers nil
  "Alist of (med-name . timer) for active reminders.")

(defun sanad-health-meds--setup-reminder (med-name times-str)
  "Set up a timed reminder for MED-NAME at TIMES-STR.
TIMES-STR can be a single time \"07:00\" or multiple \"07:00 13:00\"."
  (dolist (time-str (split-string times-str " " t))
    (let* ((hour (string-to-number (substring time-str 0 2)))
           (min (string-to-number (substring time-str 3 5)))
           (timer (run-at-time (format "%02d:%02d" hour min)
                               (* 24 60 60)
                               #'sanad-health-meds--remind
                               med-name)))
      (push (cons (format "%s@%s" med-name time-str) timer)
            sanad-health-meds--reminder-timers))))

(defun sanad-health-meds--remind (med-name)
  "Show a reminder to take MED-NAME."
  (message "Sanad Health: Time to take %s" med-name)
  (when (fboundp 'notifications-notify)
    (notifications-notify
     :title "Sanad Health"
     :body (format "Time to take %s" med-name)
     :urgency 'normal)))

(defun sanad-health-meds--setup-all-reminders ()
  "Set up reminders for all active medications."
  (let ((meds (sanad-health-meds--read-active)))
    (dolist (med meds)
      (let ((times (plist-get med :times))
            (name (plist-get med :name)))
        (when (and times (not (string-empty-p times)))
          (sanad-health-meds--setup-reminder name times))))))

;;; --- Evaluate Supplement ---

(defun sanad-health-meds-evaluate ()
  "Evaluate a supplement: keep, drop, or adjust."
  (interactive)
  (let* ((meds (sanad-health-meds--read-active))
         (supps (cl-remove-if-not
                 (lambda (m) (equal (plist-get m :type) "supplement"))
                 meds))
         (names (mapcar (lambda (m) (plist-get m :name)) supps))
         (chosen (completing-read "Evaluate supplement: " names nil t))
         (decision (completing-read "Decision: " '("keep" "drop" "adjust") nil t))
         (reason (read-string "Reason: ")))
    (if (equal decision "drop")
        (sanad-health-meds--discontinue chosen (format "Dropped: %s" reason))
      (message "Logged: %s \u2014 %s (%s)" chosen decision reason))))

;;; --- Keybindings ---

(defvar sanad-health-meds-command-map
  (let ((map (make-sparse-keymap)))
    (define-key map "a" #'sanad-health-meds-add)
    (define-key map "r" #'sanad-health-meds-review)
    (define-key map "v" #'sanad-health-meds-evaluate)
    map)
  "Command map for medication keybindings under C-c h m.")

(define-key sanad-health-command-map "m" sanad-health-meds-command-map)

;; Start reminders when module loads
(when sanad-health-directory
  (sanad-health-meds--setup-all-reminders))

(provide 'sanad-health-meds)
;;; sanad-health-meds.el ends here
```

- [ ] **Step 4: Run the tests**

```bash
cd sanad-health && make test-meds
```

Expected: All tests PASS.

- [ ] **Step 5: Commit**

```bash
git add sanad-health/sanad-health-meds.el sanad-health/tests/test-sanad-health-meds.el
git commit -m "feat: add medication tracking with reminders, stack review, and discontinue"
```

---

## Task 7: Brain Dump & Capture (`sanad-health-capture.el`)

**Files:**
- Create: `sanad-health/sanad-health-capture.el`
- Create: `sanad-health/tests/test-sanad-health-capture.el`

- [ ] **Step 1: Write failing tests**

```elisp
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
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd sanad-health && make test-capture
```

- [ ] **Step 3: Implement the capture module**

```elisp
;;; sanad-health-capture.el --- Brain dump and capture for sanad-health -*- lexical-binding: t; -*-

;; Author: alarawms
;; Keywords: health, org, adhd

;;; Commentary:

;; Brain dump and quick capture for sanad-health, built on org-capture.
;;
;; Registers health-specific capture templates into the user's existing
;; org-capture-templates without replacing them.
;;
;; Templates:
;;   h t - Health Task (TODO item to inbox)
;;   h b - Brain Dump (free-form thought to inbox)
;;   h n - Health Note (tagged note)
;;   h s - Side Effect (medication side effect log)
;;
;; Dashboard integration:
;;   c - Quick capture
;;   r - Refile item from inbox
;;   d - Mark item done
;;   k - Kill/delete item

;;; Code:

(require 'sanad-health)
(require 'org-capture)

;;; --- Template Registration ---

(defun sanad-health-capture--register-templates ()
  "Register sanad-health capture templates with org-capture.
Appends to `org-capture-templates' without replacing existing entries."
  (let ((inbox-file (sanad-health-captures-file))
        (meds-file (sanad-health-meds-file)))
    ;; Parent entry for health captures
    (unless (assoc "h" org-capture-templates)
      (add-to-list 'org-capture-templates '("h" "Health") t))
    ;; Health Task
    (unless (assoc "ht" org-capture-templates)
      (add-to-list 'org-capture-templates
                   `("ht" "Health Task" entry
                     (file+headline ,inbox-file "Inbox")
                     "* TODO %?\n  :PROPERTIES:\n  :CAPTURED: %U\n  :END:\n"
                     :empty-lines 1)
                   t))
    ;; Brain Dump
    (unless (assoc "hb" org-capture-templates)
      (add-to-list 'org-capture-templates
                   `("hb" "Brain Dump" entry
                     (file+headline ,inbox-file "Inbox")
                     "* %?\n  :PROPERTIES:\n  :CAPTURED: %U\n  :END:\n"
                     :empty-lines 1)
                   t))
    ;; Health Note
    (unless (assoc "hn" org-capture-templates)
      (add-to-list 'org-capture-templates
                   `("hn" "Health Note" entry
                     (file+headline ,inbox-file "Notes")
                     "* %? :note:\n  %U\n"
                     :empty-lines 1)
                   t))
    ;; Side Effect
    (unless (assoc "hs" org-capture-templates)
      (add-to-list 'org-capture-templates
                   `("hs" "Side Effect" entry
                     (file+headline ,meds-file "Side Effects Log")
                     "* %U \u2014 %?\n  :PROPERTIES:\n  :MED:  %^{Medication}\n  :SEVERITY: %^{Severity|mild|moderate|severe}\n  :END:\n"
                     :empty-lines 1)
                   t))))

;;; --- Reading Inbox ---

(defun sanad-health-capture--read-inbox ()
  "Read items under the Inbox heading in captures/inbox.org.
Returns a list of heading strings."
  (let ((inbox-file (sanad-health-captures-file))
        items)
    (when (file-exists-p inbox-file)
      (with-temp-buffer
        (insert-file-contents inbox-file)
        (org-mode)
        (goto-char (point-min))
        (when (re-search-forward "^\\* Inbox" nil t)
          (let ((bound (save-excursion
                         (or (re-search-forward "^\\* " nil t)
                             (point-max)))))
            (while (re-search-forward "^\\*\\* \\(.*\\)$" bound t)
              (push (match-string 1) items))))))
    (nreverse items)))

;;; --- Interactive Commands ---

(defun sanad-health-capture--do ()
  "Open org-capture with health templates pre-selected."
  (interactive)
  (sanad-health-capture--register-templates)
  (org-capture nil "h"))

(defun sanad-health-capture--refile ()
  "Refile the item at point in the dashboard brain dump section."
  (interactive)
  (let ((inbox-file (sanad-health-captures-file)))
    (when (file-exists-p inbox-file)
      (find-file inbox-file)
      (call-interactively #'org-refile))))

;;; --- Register with Core ---

;; Register templates when module loads
(when sanad-health-directory
  (sanad-health-capture--register-templates))

(provide 'sanad-health-capture)
;;; sanad-health-capture.el ends here
```

- [ ] **Step 4: Run the tests**

```bash
cd sanad-health && make test-capture
```

Expected: All tests PASS.

- [ ] **Step 5: Commit**

```bash
git add sanad-health/sanad-health-capture.el sanad-health/tests/test-sanad-health-capture.el
git commit -m "feat: add brain dump and capture with org-capture templates"
```

---

## Task 8: Pomodoro Timer (`sanad-health-pomodoro.el`)

**Files:**
- Create: `sanad-health/sanad-health-pomodoro.el`
- Create: `sanad-health/tests/test-sanad-health-pomodoro.el`

- [ ] **Step 1: Write failing tests**

```elisp
;;; tests/test-sanad-health-pomodoro.el --- Tests for pomodoro timer -*- lexical-binding: t; -*-

;;; Commentary:
;; Tests for pomodoro timer state machine, mode-line display, and logging.

;;; Code:

(require 'test-helper)
(require 'sanad-health)
(require 'sanad-health-pomodoro)

(ert-deftest sanad-health-pomodoro-test-initial-state ()
  "Pomodoro state should be idle initially."
  (should (equal sanad-health-pomodoro--state 'idle)))

(ert-deftest sanad-health-pomodoro-test-start-sets-state ()
  "Starting a pomodoro should set state to work."
  (let ((sanad-health-pomodoro--state 'idle)
        (sanad-health-pomodoro--timer nil)
        (sanad-health-pomodoro--seconds-remaining 0)
        (sanad-health-pomodoro--current-task "Test Task")
        (sanad-health-pomodoro--current-project "")
        (sanad-health-pomodoro--session-count 0)
        (sanad-health-pomodoro--distraction-count 0)
        (sanad-health-pomodoro-work-minutes 25))
    (sanad-health-pomodoro--begin-work "Test Task" "Test Project")
    (should (equal sanad-health-pomodoro--state 'work))
    (should (= sanad-health-pomodoro--seconds-remaining (* 25 60)))
    (should (equal sanad-health-pomodoro--current-task "Test Task"))
    ;; Clean up timer
    (when sanad-health-pomodoro--timer
      (cancel-timer sanad-health-pomodoro--timer)
      (setq sanad-health-pomodoro--timer nil))))

(ert-deftest sanad-health-pomodoro-test-mode-line-format ()
  "Mode line should show task, time, and session count."
  (let ((sanad-health-pomodoro--state 'work)
        (sanad-health-pomodoro--current-task "Focus Block 1")
        (sanad-health-pomodoro--current-project "PhD Ch.3")
        (sanad-health-pomodoro--seconds-remaining 1122) ;; 18:42
        (sanad-health-pomodoro--session-count 2)
        (sanad-health-pomodoro-sessions-per-set 4))
    (let ((ml (sanad-health-pomodoro--mode-line-string)))
      (should (string-match-p "Focus Block 1" ml))
      (should (string-match-p "18:42" ml))
      (should (string-match-p "2/4" ml)))))

(ert-deftest sanad-health-pomodoro-test-distraction-counter ()
  "Logging a distraction should increment the counter."
  (let ((sanad-health-pomodoro--state 'work)
        (sanad-health-pomodoro--distraction-count 0))
    (sanad-health-pomodoro--log-distraction)
    (should (= sanad-health-pomodoro--distraction-count 1))
    (sanad-health-pomodoro--log-distraction)
    (should (= sanad-health-pomodoro--distraction-count 2))))

(ert-deftest sanad-health-pomodoro-test-stop-resets-state ()
  "Stopping should reset state to idle."
  (let ((sanad-health-pomodoro--state 'work)
        (sanad-health-pomodoro--timer nil)
        (sanad-health-pomodoro--seconds-remaining 500))
    (sanad-health-pomodoro--stop)
    (should (equal sanad-health-pomodoro--state 'idle))
    (should (= sanad-health-pomodoro--seconds-remaining 0))))

(provide 'test-sanad-health-pomodoro)
;;; test-sanad-health-pomodoro.el ends here
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd sanad-health && make test-pomodoro
```

- [ ] **Step 3: Implement the pomodoro module**

```elisp
;;; sanad-health-pomodoro.el --- Pomodoro timer for sanad-health -*- lexical-binding: t; -*-

;; Author: alarawms
;; Keywords: health, org, adhd

;;; Commentary:

;; Pomodoro timer with ADHD-specific features for sanad-health.
;;
;; Features:
;; - Customizable work/break/long-break intervals from profile.org
;; - Mode-line countdown display with task and session info
;; - org-clock integration (clocks into the org entry)
;; - Forced break enforcement (configurable)
;; - Session goal display during work
;; - Distraction counter
;; - Pomodoro logging to daily log
;;
;; Lifecycle:
;; 1. Start pomodoro on a focus block -> clocks in
;; 2. Work phase counts down -> notification on finish
;; 3. Break phase starts automatically
;; 4. After N sessions -> long break
;; 5. Each pomodoro logged to daily log table
;;
;; Keybindings (prefix C-c h p):
;;   p - Start pomodoro
;;   s - Stop pomodoro
;;   e - Extend +5 min
;;   d - Log distraction
;;   v - View today's stats

;;; Code:

(require 'sanad-health)
(require 'notifications nil t)

;;; --- Customization ---

(defcustom sanad-health-pomodoro-work-minutes 25
  "Work phase duration in minutes."
  :type 'integer
  :group 'sanad-health)

(defcustom sanad-health-pomodoro-break-minutes 5
  "Short break duration in minutes."
  :type 'integer
  :group 'sanad-health)

(defcustom sanad-health-pomodoro-long-break-minutes 15
  "Long break duration in minutes."
  :type 'integer
  :group 'sanad-health)

(defcustom sanad-health-pomodoro-sessions-per-set 4
  "Number of work sessions before a long break."
  :type 'integer
  :group 'sanad-health)

(defcustom sanad-health-pomodoro-enforce-breaks t
  "When non-nil, do not offer a skip-break option."
  :type 'boolean
  :group 'sanad-health)

;;; --- Internal State ---

(defvar sanad-health-pomodoro--state 'idle
  "Current pomodoro state: idle, work, break, long-break.")

(defvar sanad-health-pomodoro--timer nil
  "The countdown timer object.")

(defvar sanad-health-pomodoro--seconds-remaining 0
  "Seconds remaining in current phase.")

(defvar sanad-health-pomodoro--current-task ""
  "Name of the current task.")

(defvar sanad-health-pomodoro--current-project ""
  "Name of the current project assignment.")

(defvar sanad-health-pomodoro--session-count 0
  "Number of completed work sessions in current set.")

(defvar sanad-health-pomodoro--distraction-count 0
  "Number of distractions logged in current pomodoro.")

(defvar sanad-health-pomodoro--start-time nil
  "Time when current work phase started.")

;;; --- Mode Line ---

(defun sanad-health-pomodoro--mode-line-string ()
  "Return the mode-line string for the current pomodoro state."
  (if (eq sanad-health-pomodoro--state 'idle)
      ""
    (let* ((mins (/ sanad-health-pomodoro--seconds-remaining 60))
           (secs (% sanad-health-pomodoro--seconds-remaining 60))
           (time-str (format "%02d:%02d" mins secs))
           (phase (pcase sanad-health-pomodoro--state
                    ('work "Pomodoro")
                    ('break "Break")
                    ('long-break "Long Break")))
           (task sanad-health-pomodoro--current-task)
           (project sanad-health-pomodoro--current-project)
           (session (format "%d/%d"
                            sanad-health-pomodoro--session-count
                            sanad-health-pomodoro-sessions-per-set)))
      (if (eq sanad-health-pomodoro--state 'work)
          (format " %s: %s%s [%s] (%s) "
                  phase task
                  (if (and project (not (string-empty-p project)))
                      (format " \u2192 %s" project) "")
                  time-str session)
        (format " %s [%s] \u2014 stand up and stretch! "
                phase time-str)))))

(defvar sanad-health-pomodoro--mode-line-entry
  '(:eval (sanad-health-pomodoro--mode-line-string))
  "Mode line construct for pomodoro display.")

;;; --- Timer Logic ---

(defun sanad-health-pomodoro--tick ()
  "Called every second to update the countdown."
  (if (> sanad-health-pomodoro--seconds-remaining 0)
      (progn
        (setq sanad-health-pomodoro--seconds-remaining
              (1- sanad-health-pomodoro--seconds-remaining))
        (force-mode-line-update t))
    ;; Phase complete
    (sanad-health-pomodoro--phase-complete)))

(defun sanad-health-pomodoro--phase-complete ()
  "Handle completion of the current phase."
  (cancel-timer sanad-health-pomodoro--timer)
  (setq sanad-health-pomodoro--timer nil)
  (pcase sanad-health-pomodoro--state
    ('work
     (setq sanad-health-pomodoro--session-count
           (1+ sanad-health-pomodoro--session-count))
     ;; Log completed pomodoro
     (sanad-health-pomodoro--log-completed)
     ;; Notify
     (message "Pomodoro complete! Time for a break.")
     (when (fboundp 'notifications-notify)
       (notifications-notify :title "Sanad Health"
                             :body "Pomodoro complete! Take a break."
                             :urgency 'normal))
     (ding)
     ;; Start break
     (if (= (% sanad-health-pomodoro--session-count
               sanad-health-pomodoro-sessions-per-set) 0)
         (sanad-health-pomodoro--begin-long-break)
       (sanad-health-pomodoro--begin-break)))
    ((or 'break 'long-break)
     (message "Break over! Ready for the next session.")
     (when (fboundp 'notifications-notify)
       (notifications-notify :title "Sanad Health"
                             :body "Break over! Ready to focus."
                             :urgency 'normal))
     (ding)
     (setq sanad-health-pomodoro--state 'idle)
     (setq sanad-health-pomodoro--distraction-count 0)
     (force-mode-line-update t))))

(defun sanad-health-pomodoro--begin-work (task project)
  "Begin a work phase for TASK with PROJECT assignment."
  (setq sanad-health-pomodoro--state 'work
        sanad-health-pomodoro--current-task task
        sanad-health-pomodoro--current-project (or project "")
        sanad-health-pomodoro--seconds-remaining (* sanad-health-pomodoro-work-minutes 60)
        sanad-health-pomodoro--distraction-count 0
        sanad-health-pomodoro--start-time (current-time))
  (setq sanad-health-pomodoro--timer
        (run-at-time 1 1 #'sanad-health-pomodoro--tick))
  ;; Add to mode line
  (unless (member sanad-health-pomodoro--mode-line-entry
                  global-mode-string)
    (push sanad-health-pomodoro--mode-line-entry global-mode-string))
  (force-mode-line-update t))

(defun sanad-health-pomodoro--begin-break ()
  "Begin a short break phase."
  (setq sanad-health-pomodoro--state 'break
        sanad-health-pomodoro--seconds-remaining (* sanad-health-pomodoro-break-minutes 60))
  (setq sanad-health-pomodoro--timer
        (run-at-time 1 1 #'sanad-health-pomodoro--tick))
  (force-mode-line-update t))

(defun sanad-health-pomodoro--begin-long-break ()
  "Begin a long break phase."
  (setq sanad-health-pomodoro--state 'long-break
        sanad-health-pomodoro--seconds-remaining (* sanad-health-pomodoro-long-break-minutes 60))
  (setq sanad-health-pomodoro--timer
        (run-at-time 1 1 #'sanad-health-pomodoro--tick))
  (message "Take a real break \u2014 move!")
  (force-mode-line-update t))

(defun sanad-health-pomodoro--stop ()
  "Stop the current pomodoro."
  (when sanad-health-pomodoro--timer
    (cancel-timer sanad-health-pomodoro--timer)
    (setq sanad-health-pomodoro--timer nil))
  (when (eq sanad-health-pomodoro--state 'work)
    (sanad-health-pomodoro--log-abandoned))
  (setq sanad-health-pomodoro--state 'idle
        sanad-health-pomodoro--seconds-remaining 0)
  (setq global-mode-string
        (delete sanad-health-pomodoro--mode-line-entry global-mode-string))
  (force-mode-line-update t))

;;; --- Logging ---

(defun sanad-health-pomodoro--log-completed ()
  "Log a completed pomodoro to today's daily log."
  (when (fboundp 'sanad-health-log-today-path)
    (let ((log-path (sanad-health-log-today-path))
          (start-str (format-time-string "%H:%M" sanad-health-pomodoro--start-time))
          (end-str (format-time-string "%H:%M")))
      (when (and log-path (file-exists-p log-path))
        (with-current-buffer (find-file-noselect log-path)
          (goto-char (point-min))
          (when (re-search-forward "^|---" nil t)
            (end-of-line)
            (insert (format "\n| %d | %s | %s | %s | %s | yes |"
                            sanad-health-pomodoro--session-count
                            sanad-health-pomodoro--current-task
                            sanad-health-pomodoro--current-project
                            start-str end-str)))
          (save-buffer))))))

(defun sanad-health-pomodoro--log-abandoned ()
  "Log an abandoned pomodoro to today's daily log."
  (when (fboundp 'sanad-health-log-today-path)
    (let ((log-path (sanad-health-log-today-path))
          (start-str (if sanad-health-pomodoro--start-time
                         (format-time-string "%H:%M" sanad-health-pomodoro--start-time)
                       "??:??"))
          (end-str (format-time-string "%H:%M")))
      (when (and log-path (file-exists-p log-path))
        (with-current-buffer (find-file-noselect log-path)
          (goto-char (point-min))
          (when (re-search-forward "^|---" nil t)
            (end-of-line)
            (insert (format "\n| %d | %s | %s | %s | %s | abandoned |"
                            (1+ sanad-health-pomodoro--session-count)
                            sanad-health-pomodoro--current-task
                            sanad-health-pomodoro--current-project
                            start-str end-str)))
          (save-buffer))))))

;;; --- Distraction Counter ---

(defun sanad-health-pomodoro--log-distraction ()
  "Increment the distraction counter for the current pomodoro."
  (when (eq sanad-health-pomodoro--state 'work)
    (setq sanad-health-pomodoro--distraction-count
          (1+ sanad-health-pomodoro--distraction-count))
    (message "Distraction #%d logged" sanad-health-pomodoro--distraction-count)))

;;; --- Interactive Commands ---

(defun sanad-health-pomodoro--start ()
  "Start a pomodoro interactively.
If called from dashboard on a focus block, uses that block.
Otherwise prompts for a task name."
  (interactive)
  (when (eq sanad-health-pomodoro--state 'work)
    (user-error "A pomodoro is already running. Stop it first with C-c h p s"))
  ;; Load settings from profile
  (let ((work (sanad-health-profile-get "POMODORO_WORK"))
        (brk (sanad-health-profile-get "POMODORO_BREAK"))
        (long-brk (sanad-health-profile-get "POMODORO_LONG_BREAK"))
        (sessions (sanad-health-profile-get "POMODORO_SESSIONS")))
    (when work (setq sanad-health-pomodoro-work-minutes (string-to-number work)))
    (when brk (setq sanad-health-pomodoro-break-minutes (string-to-number brk)))
    (when long-brk (setq sanad-health-pomodoro-long-break-minutes (string-to-number long-brk)))
    (when sessions (setq sanad-health-pomodoro-sessions-per-set (string-to-number sessions))))
  (let* ((task (read-string "Task: " nil nil "Focus Block"))
         (project (read-string "Project (optional): ")))
    (sanad-health-pomodoro--begin-work task project)
    (message "Pomodoro started: %s [%d min]" task sanad-health-pomodoro-work-minutes)))

(defun sanad-health-pomodoro-stop ()
  "Stop the current pomodoro."
  (interactive)
  (if (eq sanad-health-pomodoro--state 'idle)
      (message "No pomodoro running")
    (sanad-health-pomodoro--stop)
    (message "Pomodoro stopped")))

(defun sanad-health-pomodoro-extend ()
  "Extend the current phase by 5 minutes."
  (interactive)
  (if (eq sanad-health-pomodoro--state 'idle)
      (message "No pomodoro running")
    (setq sanad-health-pomodoro--seconds-remaining
          (+ sanad-health-pomodoro--seconds-remaining 300))
    (message "Extended by 5 minutes")))

(defun sanad-health-pomodoro-log-distraction ()
  "Log a distraction during the current pomodoro."
  (interactive)
  (if (eq sanad-health-pomodoro--state 'work)
      (sanad-health-pomodoro--log-distraction)
    (message "No active work session")))

(defun sanad-health-pomodoro-stats ()
  "Show today's pomodoro statistics."
  (interactive)
  (message "Sessions: %d | Distractions: %d | State: %s"
           sanad-health-pomodoro--session-count
           sanad-health-pomodoro--distraction-count
           sanad-health-pomodoro--state))

;;; --- Keybindings ---

(defvar sanad-health-pomodoro-command-map
  (let ((map (make-sparse-keymap)))
    (define-key map "p" #'sanad-health-pomodoro--start)
    (define-key map "s" #'sanad-health-pomodoro-stop)
    (define-key map "e" #'sanad-health-pomodoro-extend)
    (define-key map "d" #'sanad-health-pomodoro-log-distraction)
    (define-key map "v" #'sanad-health-pomodoro-stats)
    map)
  "Command map for pomodoro keybindings under C-c h p.")

(define-key sanad-health-command-map "p" sanad-health-pomodoro-command-map)

(provide 'sanad-health-pomodoro)
;;; sanad-health-pomodoro.el ends here
```

- [ ] **Step 4: Run the tests**

```bash
cd sanad-health && make test-pomodoro
```

Expected: All tests PASS.

- [ ] **Step 5: Commit**

```bash
git add sanad-health/sanad-health-pomodoro.el sanad-health/tests/test-sanad-health-pomodoro.el
git commit -m "feat: add pomodoro timer with mode-line display, breaks, and distraction counter"
```

---

## Task 9: Daily Log (`sanad-health-log.el`)

**Files:**
- Create: `sanad-health/sanad-health-log.el`
- Create: `sanad-health/tests/test-sanad-health-log.el`

- [ ] **Step 1: Write failing tests**

```elisp
;;; tests/test-sanad-health-log.el --- Tests for daily log module -*- lexical-binding: t; -*-

;;; Commentary:
;; Tests for daily log creation, metric reading, and weekly aggregation.

;;; Code:

(require 'test-helper)
(require 'sanad-health)
(require 'sanad-health-log)

(ert-deftest sanad-health-log-test-today-path ()
  "Today's log path should use YYYY-MM subdirectory."
  (let ((sanad-health-directory "/tmp/test-health"))
    (let ((path (sanad-health-log-today-path)))
      (should (string-match-p "logs/" path))
      (should (string-match-p "daily-log-" path))
      (should (string-match-p "\\.org$" path)))))

(ert-deftest sanad-health-log-test-create-from-template ()
  "Creating a log should populate with template content."
  (sanad-health-test-setup)
  (make-directory (expand-file-name "logs" sanad-health-directory) t)
  (make-directory (expand-file-name "meds" sanad-health-directory) t)
  (make-directory (expand-file-name "routines" sanad-health-directory) t)
  ;; Create minimal meds and routines files
  (with-temp-file (expand-file-name "meds/medications.org" sanad-health-directory)
    (insert "#+CATEGORY: Meds\n\n* Medications\n** TestMed\n   :PROPERTIES:\n   :DOSAGE: 10mg\n   :TIMES: 08:00\n   :END:\n* Supplements\n* Inactive\n"))
  (with-temp-file (expand-file-name "routines/daily.org" sanad-health-directory)
    (insert "#+CATEGORY: Health\n\n* Routines\n** TODO TestRoutine\n   :PROPERTIES:\n   :BLOCK: morning\n   :ORDER: 1\n   :END:\n"))
  (sanad-health-log--create-today)
  (let ((log-path (sanad-health-log-today-path)))
    (should (file-exists-p log-path))
    (with-temp-buffer
      (insert-file-contents log-path)
      (should (string-match-p "Metrics" (buffer-string)))
      (should (string-match-p "Pomodoros" (buffer-string)))))
  (sanad-health-test-teardown))

(ert-deftest sanad-health-log-test-read-metric ()
  "Should read a metric value from today's log."
  (sanad-health-test-setup)
  (let ((log-dir (expand-file-name
                  (format "logs/%s" (format-time-string "%Y-%m"))
                  sanad-health-directory)))
    (make-directory log-dir t)
    (with-temp-file (expand-file-name
                     (format "daily-log-%s.org" (format-time-string "%Y-%m-%d"))
                     log-dir)
      (insert "#+TITLE: Test Log\n\n* Metrics\n:PROPERTIES:\n:FOCUS: 7\n:SLEEP: 8\n:END:\n")))
  (should (equal (sanad-health-log--read-metric "FOCUS") "7"))
  (should (equal (sanad-health-log--read-metric "SLEEP") "8"))
  (should (null (sanad-health-log--read-metric "ENERGY")))
  (sanad-health-test-teardown))

(ert-deftest sanad-health-log-test-compute-weekly-averages ()
  "Should compute averages across multiple daily logs."
  (let ((logs (list (list :focus 7 :sleep 8 :energy 6 :mood 7)
                    (list :focus 8 :sleep 7 :energy 7 :mood 8)
                    (list :focus 6 :sleep 9 :energy 5 :mood 6))))
    (let ((avgs (sanad-health-log--compute-averages logs)))
      (should (= (plist-get avgs :focus) 7.0))
      (should (= (plist-get avgs :sleep) 8.0))
      (should (= (plist-get avgs :energy) 6.0))
      (should (= (plist-get avgs :mood) 7.0)))))

(provide 'test-sanad-health-log)
;;; test-sanad-health-log.el ends here
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd sanad-health && make test-log
```

- [ ] **Step 3: Implement the log module**

```elisp
;;; sanad-health-log.el --- Daily logging for sanad-health -*- lexical-binding: t; -*-

;; Author: alarawms
;; Keywords: health, org, adhd

;;; Commentary:

;; Daily metric logging and weekly aggregation for sanad-health.
;;
;; Features:
;; - Auto-creates today's log from template on first access
;; - Populates med checkboxes and routine checkboxes from active data
;; - Interactive metric logging (all 6 scores or quick 3)
;; - Weekly aggregation on Sundays (or manual trigger)
;; - Trend comparison across weeks
;;
;; Log files are stored as: logs/YYYY-MM/daily-log-YYYY-MM-DD.org
;;
;; Keybindings (prefix C-c h l):
;;   l - Open today's log
;;   m - Log all metrics interactively
;;   q - Quick log (Focus + Energy + Mood)
;;   w - Generate weekly summary
;;   t - View trends

;;; Code:

(require 'sanad-health)

;;; --- Path Helpers ---

(defun sanad-health-log-today-path ()
  "Return the file path for today's daily log."
  (let* ((date-str (format-time-string "%Y-%m-%d"))
         (month-dir (format-time-string "%Y-%m"))
         (log-dir (expand-file-name (format "logs/%s" month-dir)
                                    sanad-health-directory)))
    (expand-file-name (format "daily-log-%s.org" date-str) log-dir)))

(defun sanad-health-log--date-path (date-str)
  "Return the log file path for DATE-STR (YYYY-MM-DD format)."
  (let* ((month-dir (substring date-str 0 7))
         (log-dir (expand-file-name (format "logs/%s" month-dir)
                                    sanad-health-directory)))
    (expand-file-name (format "daily-log-%s.org" date-str) log-dir)))

;;; --- Log Creation ---

(defun sanad-health-log--create-today ()
  "Create today's daily log file from template if it doesn't exist."
  (let ((log-path (sanad-health-log-today-path)))
    (unless (file-exists-p log-path)
      (make-directory (file-name-directory log-path) t)
      (with-temp-file log-path
        (insert (format "#+TITLE: Daily Log \u2014 %s %s\n"
                        (format-time-string "%Y-%m-%d")
                        (format-time-string "%A")))
        (insert "#+FILETAGS: :sanad:log:\n\n")
        ;; Metrics
        (insert "* Metrics\n:PROPERTIES:\n")
        (insert ":FOCUS:\n:SLEEP:\n:ENERGY:\n:MOOD:\n")
        (insert ":PRODUCTIVITY:\n:DOPAMINE_CTRL:\n")
        (insert ":BEST_FOCUS_TIME:\n:WORST_FOCUS_TIME:\n")
        (insert ":END:\n\n")
        ;; Medications
        (insert "* Medications\n")
        (when (file-exists-p (sanad-health-meds-file))
          (let ((meds (sanad-health-log--read-active-meds)))
            (dolist (med meds)
              (insert (format "- [ ] %s %s %s\n"
                              (plist-get med :times)
                              (plist-get med :name)
                              (plist-get med :dosage))))))
        (insert "\n")
        ;; Routine
        (insert "* Routine Completion\n")
        (when (file-exists-p (sanad-health-routines-file))
          (let ((routines (sanad-health-log--read-routine-names)))
            (dolist (r routines)
              (insert (format "- [ ] %s\n" r)))))
        (insert "\n")
        ;; Pomodoros
        (insert "* Pomodoros\n")
        (insert "| # | Task | Project | Start | End | Completed |\n")
        (insert "|---+------+---------+-------+-----+-----------|\n\n")
        ;; Other sections
        (insert "* Side Effects / Adjustments\n\n")
        (insert "* Notes\n")))))

(defun sanad-health-log--read-active-meds ()
  "Read active meds for log template population."
  (when (fboundp 'sanad-health-meds--read-active)
    (sanad-health-meds--read-active)))

(defun sanad-health-log--read-routine-names ()
  "Read routine item titles for log template population."
  (let ((routine-file (sanad-health-routines-file))
        names)
    (when (file-exists-p routine-file)
      (with-temp-buffer
        (insert-file-contents routine-file)
        (org-mode)
        (goto-char (point-min))
        (org-map-entries
         (lambda ()
           (when (org-entry-get (point) "BLOCK")
             (push (org-get-heading t t t t) names)))
         nil nil)))
    (nreverse names)))

;;; --- Reading Metrics ---

(defun sanad-health-log--read-metric (metric)
  "Read METRIC from today's daily log.
Returns the value as a string, or nil."
  (let ((log-path (sanad-health-log-today-path)))
    (when (file-exists-p log-path)
      (with-temp-buffer
        (insert-file-contents log-path)
        (org-mode)
        (goto-char (point-min))
        (when (re-search-forward "^\\* Metrics" nil t)
          (let ((val (org-entry-get (point) metric)))
            (when (and val (not (string-empty-p val)))
              val)))))))

;;; --- Interactive Logging ---

(defun sanad-health-log--prompt-metrics ()
  "Prompt for all daily metrics and write to today's log."
  (interactive)
  (sanad-health-log--create-today)
  (let* ((focus (read-number "Focus (1-10): "))
         (sleep (read-number "Sleep quality (1-10): "))
         (energy (read-number "Energy (1-10): "))
         (mood (read-number "Mood (1-10): "))
         (productivity (read-number "Productivity (1-10): "))
         (dopamine (read-number "Dopamine control (1-10): "))
         (best-focus (read-string "Best focus time today: "))
         (worst-focus (read-string "Worst focus time today: "))
         (log-path (sanad-health-log-today-path)))
    (with-current-buffer (find-file-noselect log-path)
      (goto-char (point-min))
      (when (re-search-forward "^\\* Metrics" nil t)
        (org-entry-put (point) "FOCUS" (number-to-string focus))
        (org-entry-put (point) "SLEEP" (number-to-string sleep))
        (org-entry-put (point) "ENERGY" (number-to-string energy))
        (org-entry-put (point) "MOOD" (number-to-string mood))
        (org-entry-put (point) "PRODUCTIVITY" (number-to-string productivity))
        (org-entry-put (point) "DOPAMINE_CTRL" (number-to-string dopamine))
        (org-entry-put (point) "BEST_FOCUS_TIME" best-focus)
        (org-entry-put (point) "WORST_FOCUS_TIME" worst-focus))
      (save-buffer))
    (message "Metrics logged!")))

(defun sanad-health-log--prompt-quick ()
  "Quick log: prompt for Focus, Energy, and Mood only."
  (interactive)
  (sanad-health-log--create-today)
  (let* ((focus (read-number "Focus (1-10): "))
         (energy (read-number "Energy (1-10): "))
         (mood (read-number "Mood (1-10): "))
         (log-path (sanad-health-log-today-path)))
    (with-current-buffer (find-file-noselect log-path)
      (goto-char (point-min))
      (when (re-search-forward "^\\* Metrics" nil t)
        (org-entry-put (point) "FOCUS" (number-to-string focus))
        (org-entry-put (point) "ENERGY" (number-to-string energy))
        (org-entry-put (point) "MOOD" (number-to-string mood)))
      (save-buffer))
    (message "Quick metrics logged!")))

;;; --- Weekly Aggregation ---

(defun sanad-health-log--compute-averages (logs)
  "Compute average metrics across LOGS (list of plists with :focus :sleep :energy :mood)."
  (let ((n (length logs))
        (sum-focus 0) (sum-sleep 0) (sum-energy 0) (sum-mood 0))
    (dolist (log logs)
      (setq sum-focus (+ sum-focus (plist-get log :focus)))
      (setq sum-sleep (+ sum-sleep (plist-get log :sleep)))
      (setq sum-energy (+ sum-energy (plist-get log :energy)))
      (setq sum-mood (+ sum-mood (plist-get log :mood))))
    (list :focus (/ (float sum-focus) n)
          :sleep (/ (float sum-sleep) n)
          :energy (/ (float sum-energy) n)
          :mood (/ (float sum-mood) n))))

(defun sanad-health-log--weekly-summary ()
  "Generate a weekly summary and append to logs/weekly-summaries.org."
  (interactive)
  (let* ((today (current-time))
         (logs '())
         (summaries-file (expand-file-name "logs/weekly-summaries.org"
                                           sanad-health-directory)))
    ;; Read the last 7 days of logs
    (dotimes (i 7)
      (let* ((day (time-subtract today (seconds-to-time (* i 86400))))
             (date-str (format-time-string "%Y-%m-%d" day))
             (log-path (sanad-health-log--date-path date-str)))
        (when (file-exists-p log-path)
          (with-temp-buffer
            (insert-file-contents log-path)
            (org-mode)
            (goto-char (point-min))
            (when (re-search-forward "^\\* Metrics" nil t)
              (let ((f (org-entry-get (point) "FOCUS"))
                    (s (org-entry-get (point) "SLEEP"))
                    (e (org-entry-get (point) "ENERGY"))
                    (m (org-entry-get (point) "MOOD")))
                (when (and f s e m)
                  (push (list :focus (string-to-number f)
                              :sleep (string-to-number s)
                              :energy (string-to-number e)
                              :mood (string-to-number m))
                        logs))))))))
    (if (null logs)
        (message "No log data found for this week")
      (let ((avgs (sanad-health-log--compute-averages logs))
            (week-num (format-time-string "%V"))
            (week-start (format-time-string "%b %d"
                                            (time-subtract today (seconds-to-time (* 6 86400)))))
            (week-end (format-time-string "%b %d")))
        (with-current-buffer (find-file-noselect summaries-file)
          (goto-char (point-max))
          (insert (format "\n* Weekly Summary \u2014 Week %s (%s\u2013%s)\n" week-num week-start week-end))
          (insert ":PROPERTIES:\n")
          (insert (format ":AVG_FOCUS:    %.1f\n" (plist-get avgs :focus)))
          (insert (format ":AVG_SLEEP:    %.1f\n" (plist-get avgs :sleep)))
          (insert (format ":AVG_ENERGY:   %.1f\n" (plist-get avgs :energy)))
          (insert (format ":AVG_MOOD:     %.1f\n" (plist-get avgs :mood)))
          (insert (format ":DAYS_LOGGED:  %d\n" (length logs)))
          (insert ":END:\n")
          (save-buffer))
        (message "Weekly summary generated: Focus %.1f | Sleep %.1f | Energy %.1f | Mood %.1f"
                 (plist-get avgs :focus) (plist-get avgs :sleep)
                 (plist-get avgs :energy) (plist-get avgs :mood))))))

;;; --- Interactive Commands ---

(defun sanad-health-log--open-today ()
  "Open today's daily log, creating it if necessary."
  (interactive)
  (sanad-health-log--create-today)
  (find-file (sanad-health-log-today-path)))

;;; --- Keybindings ---

(defvar sanad-health-log-command-map
  (let ((map (make-sparse-keymap)))
    (define-key map "l" #'sanad-health-log--open-today)
    (define-key map "m" #'sanad-health-log--prompt-metrics)
    (define-key map "q" #'sanad-health-log--prompt-quick)
    (define-key map "w" #'sanad-health-log--weekly-summary)
    map)
  "Command map for log keybindings under C-c h l.")

(define-key sanad-health-command-map "l" sanad-health-log-command-map)

(provide 'sanad-health-log)
;;; sanad-health-log.el ends here
```

- [ ] **Step 4: Run the tests**

```bash
cd sanad-health && make test-log
```

Expected: All tests PASS.

- [ ] **Step 5: Commit**

```bash
git add sanad-health/sanad-health-log.el sanad-health/tests/test-sanad-health-log.el
git commit -m "feat: add daily log with metrics, auto-population, and weekly aggregation"
```

---

## Task 10: Start My Day Tracker (`sanad-health-tracker.el`)

**Files:**
- Create: `sanad-health/sanad-health-tracker.el`
- Create: `sanad-health/tests/test-sanad-health-tracker.el`

- [ ] **Step 1: Write failing tests**

```elisp
;;; tests/test-sanad-health-tracker.el --- Tests for Start My Day tracker -*- lexical-binding: t; -*-

;;; Commentary:
;; Tests for the interactive checklist buffer, progress bar, and completion syncing.

;;; Code:

(require 'test-helper)
(require 'sanad-health)
(require 'sanad-health-tracker)

(ert-deftest sanad-health-tracker-test-progress-string ()
  "Progress bar should reflect completion percentage."
  (should (string-match-p "0/5"
                          (sanad-health-tracker--progress-string 0 5)))
  (should (string-match-p "3/5"
                          (sanad-health-tracker--progress-string 3 5)))
  (should (string-match-p "5/5"
                          (sanad-health-tracker--progress-string 5 5))))

(ert-deftest sanad-health-tracker-test-progress-bar-visual ()
  "Progress bar should use filled/empty characters."
  (let ((bar (sanad-health-tracker--progress-bar 5 10 20)))
    (should (= (length bar) 20))
    ;; First half should be filled
    (should (string-match-p (regexp-quote (make-string 10 ?\u2588)) bar))))

(ert-deftest sanad-health-tracker-test-group-items-by-block ()
  "Items should be grouped by their :block property."
  (let ((items (list (list :title "Wake" :block "morning" :done nil)
                     (list :title "Meds" :block "morning" :done nil)
                     (list :title "Exercise" :block "midday" :done nil))))
    (let ((grouped (sanad-health-tracker--group-by-block items)))
      (should (= (length (cdr (assoc "morning" grouped))) 2))
      (should (= (length (cdr (assoc "midday" grouped))) 1)))))

(ert-deftest sanad-health-tracker-test-streak-calculation ()
  "Streak should count consecutive days with >80% completion."
  (sanad-health-test-setup)
  (make-directory (expand-file-name "logs" sanad-health-directory) t)
  ;; Streak of 0 when no logs exist
  (should (= (sanad-health-tracker--calculate-streak) 0))
  (sanad-health-test-teardown))

(provide 'test-sanad-health-tracker)
;;; test-sanad-health-tracker.el ends here
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd sanad-health && make test-tracker
```

- [ ] **Step 3: Implement the tracker module**

```elisp
;;; sanad-health-tracker.el --- Start My Day tracker for sanad-health -*- lexical-binding: t; -*-

;; Author: alarawms
;; Keywords: health, org, adhd

;;; Commentary:

;; "Start My Day" interactive checklist for sanad-health.
;;
;; Features:
;; - Interactive buffer showing today's routine items with checkboxes
;; - Visual progress bar with live updates
;; - Completion timestamps synced to daily log
;; - Items grouped by time-of-day block
;; - ADHD motivators: progress bar, streak counter, celebration on 100%
;; - Subtle overdue highlighting (not aggressive)
;; - End-of-day review with reflection prompt
;;
;; Keybindings:
;;   RET - Toggle item done/undone
;;   a   - Assign work to focus block
;;   p   - Start pomodoro for item at point
;;   n   - Add note to item
;;   e   - End-of-day review
;;   g   - Refresh
;;   q   - Back to dashboard

;;; Code:

(require 'sanad-health)

;;; --- Constants ---

(defconst sanad-health-tracker-buffer-name "*Sanad Health Tracker*"
  "Name of the tracker buffer.")

;;; --- Internal State ---

(defvar-local sanad-health-tracker--items nil
  "List of tracker items (plists) for the current session.")

;;; --- Progress Display ---

(defun sanad-health-tracker--progress-bar (completed total width)
  "Return a progress bar string of WIDTH chars for COMPLETED out of TOTAL."
  (let* ((ratio (if (= total 0) 0.0 (/ (float completed) total)))
         (filled (round (* ratio width)))
         (empty (- width filled)))
    (concat (make-string filled ?\u2588)
            (make-string empty ?\u2591))))

(defun sanad-health-tracker--progress-string (completed total)
  "Return a progress summary string like 'Progress: [bar] 3/10 (30%)'."
  (let* ((bar (sanad-health-tracker--progress-bar completed total 20))
         (pct (if (= total 0) 0 (round (* 100.0 (/ (float completed) total))))))
    (format "Progress: %s %d/%d (%d%%)" bar completed total pct)))

;;; --- Item Grouping ---

(defun sanad-health-tracker--group-by-block (items)
  "Group ITEMS by their :block property.
Returns an alist of (block-name . items-list)."
  (let (groups)
    (dolist (item items)
      (let* ((block (plist-get item :block))
             (existing (assoc block groups)))
        (if existing
            (setcdr existing (append (cdr existing) (list item)))
          (push (cons block (list item)) groups))))
    ;; Sort by block order
    (let ((block-order '("morning" "midday" "afternoon" "evening")))
      (sort groups
            (lambda (a b)
              (< (or (cl-position (car a) block-order :test #'equal) 99)
                 (or (cl-position (car b) block-order :test #'equal) 99)))))))

;;; --- Streak ---

(defun sanad-health-tracker--calculate-streak ()
  "Count consecutive past days with >80% routine completion.
Returns the streak count."
  (let ((streak 0)
        (checking t)
        (day-offset 1))  ;; Start from yesterday
    (while checking
      (let* ((day (time-subtract (current-time)
                                 (seconds-to-time (* day-offset 86400))))
             (date-str (format-time-string "%Y-%m-%d" day))
             (log-path (when (fboundp 'sanad-health-log--date-path)
                         (sanad-health-log--date-path date-str))))
        (if (and log-path (file-exists-p log-path))
            (let ((completion-rate (sanad-health-tracker--log-completion-rate log-path)))
              (if (>= completion-rate 80)
                  (progn
                    (setq streak (1+ streak))
                    (setq day-offset (1+ day-offset)))
                (setq checking nil)))
          (setq checking nil))))
    streak))

(defun sanad-health-tracker--log-completion-rate (log-path)
  "Read the routine completion rate from LOG-PATH.
Returns a percentage (0-100)."
  (with-temp-buffer
    (insert-file-contents log-path)
    (goto-char (point-min))
    (let ((total 0) (done 0))
      (when (re-search-forward "^\\* Routine Completion" nil t)
        (let ((bound (save-excursion
                       (or (re-search-forward "^\\* " nil t) (point-max)))))
          (while (re-search-forward "^- \\[\\([ X]\\)\\]" bound t)
            (setq total (1+ total))
            (when (equal (match-string 1) "X")
              (setq done (1+ done))))))
      (if (= total 0) 0 (round (* 100.0 (/ (float done) total)))))))

;;; --- Buffer Rendering ---

(defvar sanad-health-tracker-mode-map
  (let ((map (make-sparse-keymap)))
    (set-keymap-parent map special-mode-map)
    (define-key map (kbd "RET") #'sanad-health-tracker-toggle)
    (define-key map "a" #'sanad-health-assign-block)
    (define-key map "p" #'sanad-health-pomodoro-start)
    (define-key map "n" #'sanad-health-tracker-add-note)
    (define-key map "e" #'sanad-health-tracker-end-of-day)
    (define-key map "g" #'sanad-health-tracker-refresh)
    map)
  "Keymap for `sanad-health-tracker-mode'.")

(define-derived-mode sanad-health-tracker-mode special-mode "Sanad Tracker"
  "Major mode for the Start My Day tracker.
\\{sanad-health-tracker-mode-map}"
  (setq buffer-read-only t))

(defun sanad-health-tracker--open ()
  "Open the Start My Day tracker buffer."
  (interactive)
  (let ((buf (get-buffer-create sanad-health-tracker-buffer-name)))
    (switch-to-buffer buf)
    (unless (eq major-mode 'sanad-health-tracker-mode)
      (sanad-health-tracker-mode))
    (sanad-health-tracker--render)))

(defun sanad-health-tracker-refresh ()
  "Refresh the tracker buffer."
  (interactive)
  (sanad-health-tracker--render))

(defun sanad-health-tracker--render ()
  "Render the tracker buffer contents."
  (let ((inhibit-read-only t))
    (erase-buffer)
    ;; Read items from agenda module
    (setq sanad-health-tracker--items
          (if (fboundp 'sanad-health-agenda--read-routine-blocks)
              (sanad-health-agenda--read-routine-blocks)
            nil))
    (let* ((total (length sanad-health-tracker--items))
           (done (cl-count-if (lambda (i) (plist-get i :done))
                              sanad-health-tracker--items))
           (streak (sanad-health-tracker--calculate-streak))
           (today (format-time-string "%A %b %d, %Y"))
           (grouped (sanad-health-tracker--group-by-block
                     sanad-health-tracker--items)))
      ;; Header
      (insert (propertize (format " Start My Day \u2014 %s\n" today)
                          'face '(:weight bold :height 1.2)))
      (insert (format " %s\n" (sanad-health-tracker--progress-string done total)))
      (when (> streak 0)
        (insert (format " Streak: %d day%s\n" streak (if (= streak 1) "" "s"))))
      (insert (make-string 50 ?\u2500) "\n\n")
      ;; Grouped items
      (if grouped
          (dolist (group grouped)
            (insert (propertize (format "%s\n" (capitalize (car group)))
                                'face '(:weight bold)))
            (dolist (item (cdr group))
              (let* ((is-done (plist-get item :done))
                     (title (plist-get item :title))
                     (assigned (plist-get item :assigned))
                     (checkbox (if is-done "[X]" "[ ]"))
                     (time (plist-get item :time))
                     (hint (cond
                            ((and sanad-health-show-hints
                                  (plist-get item :pomodoro)
                                  (not is-done))
                             "    [p] pomodoro")
                            ((and sanad-health-show-hints
                                  (not assigned)
                                  (plist-get item :pomodoro))
                             "    [a] assign")
                            (t ""))))
                (insert (format "  %s %s  %s%s%s\n"
                                checkbox
                                (or time "     ")
                                title
                                (if (and assigned (not (string-empty-p assigned)))
                                    (format " \u2192 %s" assigned) "")
                                hint))))
            (insert "\n"))
        (insert "  No routine items found. Run setup or add to routines/daily.org\n\n"))
      ;; Celebration
      (when (and (> total 0) (= done total))
        (insert (propertize "\nPerfect day! All blocks completed!\n"
                            'face '(:weight bold :foreground "green"))))
      ;; Footer
      (insert (make-string 50 ?\u2500) "\n")
      (when sanad-health-show-hints
        (insert "[RET] toggle  [a] assign  [p] pomodoro  [n] note  [e] end of day  [q] back\n")))
    (goto-char (point-min))))

;;; --- Toggle Item ---

(defun sanad-health-tracker-toggle ()
  "Toggle the routine item at point between TODO and DONE."
  (interactive)
  (let ((line (buffer-substring-no-properties
               (line-beginning-position) (line-end-position))))
    (when (string-match "\\[[ X]\\].*?  \\(.+?\\)\\( \u2192\\|    \\[\\|$\\)" line)
      (let ((title (string-trim (match-string 1 line))))
        ;; Toggle in routine file
        (when (fboundp 'sanad-health-agenda--read-routine-blocks)
          (let ((routine-file (sanad-health-routines-file)))
            (when (file-exists-p routine-file)
              (with-current-buffer (find-file-noselect routine-file)
                (goto-char (point-min))
                (org-map-entries
                 (lambda ()
                   (when (equal (org-get-heading t t t t) title)
                     (if (equal (org-get-todo-state) "DONE")
                         (org-todo "TODO")
                       (org-todo "DONE"))))
                 nil nil)
                (save-buffer)))))
        (sanad-health-tracker--render)))))

;;; --- Notes ---

(defun sanad-health-tracker-add-note ()
  "Add a note to the item at point."
  (interactive)
  (let ((note (read-string "Note: ")))
    (when (and note (not (string-empty-p note)))
      (when (fboundp 'sanad-health-log--open-today)
        (let ((log-path (sanad-health-log-today-path)))
          (sanad-health-log--create-today)
          (with-current-buffer (find-file-noselect log-path)
            (goto-char (point-max))
            (unless (re-search-backward "^\\* Notes" nil t)
              (goto-char (point-max))
              (insert "\n* Notes\n"))
            (goto-char (point-max))
            (insert (format "- %s: %s\n" (format-time-string "%H:%M") note))
            (save-buffer))))
      (message "Note added"))))

;;; --- End of Day ---

(defun sanad-health-tracker-end-of-day ()
  "Run end-of-day review: show completion summary and prompt for reflection."
  (interactive)
  (let* ((items sanad-health-tracker--items)
         (total (length items))
         (done (cl-count-if (lambda (i) (plist-get i :done)) items))
         (missed (cl-remove-if (lambda (i) (plist-get i :done)) items))
         (reflection (read-string
                      (format "Day complete (%d/%d). One-line reflection: " done total))))
    ;; Log reflection
    (when (and reflection (not (string-empty-p reflection)))
      (let ((log-path (sanad-health-log-today-path)))
        (when (fboundp 'sanad-health-log--create-today)
          (sanad-health-log--create-today))
        (when (file-exists-p log-path)
          (with-current-buffer (find-file-noselect log-path)
            (goto-char (point-max))
            (insert (format "\n** End of Day Reflection\n%s\n\nMissed:\n" reflection))
            (dolist (m missed)
              (insert (format "- %s\n" (plist-get m :title))))
            (save-buffer)))))
    ;; Trigger nightly reset
    (when (fboundp 'sanad-health-agenda--reset-routines)
      (sanad-health-agenda--reset-routines))
    (message "End of day logged. See you tomorrow!")))

(provide 'sanad-health-tracker)
;;; sanad-health-tracker.el ends here
```

- [ ] **Step 4: Run the tests**

```bash
cd sanad-health && make test-tracker
```

Expected: All tests PASS.

- [ ] **Step 5: Commit**

```bash
git add sanad-health/sanad-health-tracker.el sanad-health/tests/test-sanad-health-tracker.el
git commit -m "feat: add Start My Day tracker with progress bar, streaks, and end-of-day review"
```

---

## Task 11: README Documentation

**Files:**
- Create: `sanad-health/README.org`

- [ ] **Step 1: Write the README**

```org
#+TITLE: Sanad Health Mode
#+AUTHOR: alarawms
#+DESCRIPTION: Emacs major mode for health and ADHD management

* Sanad Health Mode

A modular Emacs major mode for health and ADHD management, built on org-mode.

** Features

- *Dashboard* — unified view with metrics, agenda, and brain dump
- *Agenda Integration* — routine blocks appear in your org-agenda
- *Medication Tracking* — reminders, LOGBOOK timestamps, stack review
- *Brain Dump* — quick capture via org-capture templates
- *Pomodoro Timer* — customizable intervals with mode-line display
- *Daily Logging* — 1-10 metric scales with weekly aggregation
- *Start My Day* — interactive checklist with progress bar and streaks
- *Setup Wizard* — guided onboarding for new users

** Installation

Clone this repository and add to your load path:

#+begin_src elisp
(add-to-list 'load-path "/path/to/sanad-health")
(require 'sanad-health)
#+end_src

For Doom Emacs, add to =packages.el=:

#+begin_src elisp
(package! sanad-health :recipe (:host github :repo "alarawms/sanad-emacs"
                                 :files ("sanad-health/*.el" "sanad-health/templates")))
#+end_src

** Quick Start

Run =M-x sanad-health-dashboard=. On first launch, the setup wizard guides you through:

1. Choosing a health directory (syncable location recommended)
2. Creating your profile
3. Adding your medications and supplements
4. Installing default ADHD routine blocks
5. Selecting which modules to enable

** Keybindings

*** Global (prefix =C-c h=)

| Key       | Command                       |
|-----------+-------------------------------|
| =C-c h d= | Open dashboard                |
| =C-c h a= | Health agenda                 |
| =C-c h c= | Quick capture (brain dump)    |
| =C-c h t= | Start My Day tracker          |
| =C-c h l= | Log prefix                    |
| =C-c h p= | Pomodoro prefix               |
| =C-c h m= | Medications prefix            |
| =C-c h s= | Settings / profile            |
| =C-c h ?= | Context-aware help            |

*** Dashboard

| Key   | Action                          |
|-------+---------------------------------|
| =RET= | Jump to item at point           |
| =c=   | Quick capture                   |
| =p=   | Start pomodoro                  |
| =t=   | Open tracker                    |
| =l=   | Open today's log                |
| =m=   | Mark medication taken           |
| =a=   | Assign focus block              |
| =g=   | Refresh                         |

*** Medications (=C-c h m=)

| Key | Action                     |
|-----+----------------------------|
| =a= | Add medication/supplement  |
| =r= | Review stack               |
| =v= | Evaluate supplement        |

*** Pomodoro (=C-c h p=)

| Key | Action                   |
|-----+--------------------------|
| =p= | Start pomodoro           |
| =s= | Stop                     |
| =e= | Extend +5 min            |
| =d= | Log distraction          |
| =v= | View stats               |

*** Daily Log (=C-c h l=)

| Key | Action                    |
|-----+---------------------------|
| =l= | Open today's log          |
| =m= | Log all metrics           |
| =q= | Quick log (3 metrics)     |
| =w= | Weekly summary            |

** Modules

Configure which modules to load:

#+begin_src elisp
(setq sanad-health-modules '(agenda meds capture pomodoro log tracker))
#+end_src

Each module is independent. You can load any subset.

** Requirements

- Emacs 28.1+
- org-mode 9.6+ (bundled with Emacs)

** License

GPL-3.0
```

- [ ] **Step 2: Create CHANGELOG**

```org
#+TITLE: Changelog

* v0.1.0 (2026-04-08)

Initial release.

- Core module with dashboard, profiles, and module loader
- Setup wizard with medication and routine onboarding
- Org-agenda integration with routine blocks and nightly reset
- Medication tracking with reminders and stack review
- Brain dump capture via org-capture templates
- Pomodoro timer with mode-line display and distraction counter
- Daily log with metrics and weekly aggregation
- Start My Day tracker with progress bar and streaks
```

- [ ] **Step 3: Commit**

```bash
git add sanad-health/README.org sanad-health/CHANGELOG.org
git commit -m "docs: add README with installation, usage guide, and keybinding reference"
```

---

## Task 12: Integration Test & Final Push

**Files:**
- Modify: `sanad-health/Makefile` (already handles all test files)

- [ ] **Step 1: Run the full test suite**

```bash
cd sanad-health && make test
```

Expected: All tests across all modules PASS.

- [ ] **Step 2: Fix any failures**

If any test fails, read the error, fix the specific issue, re-run that module's tests, then re-run the full suite.

- [ ] **Step 3: Push to GitHub**

```bash
git push origin main
```

- [ ] **Step 4: Verify CI passes**

```bash
gh run list --limit 1
```

Wait for the GitHub Actions run to complete. If it fails, check the logs:

```bash
gh run view --log
```

- [ ] **Step 5: Final commit if any fixes were needed**

```bash
git add -A && git commit -m "fix: address test failures from integration run"
git push origin main
```
