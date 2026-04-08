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

;;;###autoload
(defun sanad-health-dashboard ()
  "Open the Sanad Health dashboard.
On first run (when `sanad-health-directory' is nil), launches the
setup wizard instead."
  (interactive)
  (if (or (null sanad-health-directory)
          (not (file-directory-p sanad-health-directory)))
      (if (fboundp 'sanad-health-setup-wizard)
          (sanad-health-setup-wizard)
        (user-error "sanad-health-setup not loaded. Add 'setup to sanad-health-modules or run (require 'sanad-health-setup)"))
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
        (sanad-health-profile-set "WELCOMED" "t")))))

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

;;;###autoload
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

;;;###autoload
(global-set-key (kbd "C-c h") sanad-health-command-map)

(provide 'sanad-health)
;;; sanad-health.el ends here
