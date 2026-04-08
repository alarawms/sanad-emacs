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
            (insert (format "\n** %s %s                                  :prescription:
   :PROPERTIES:
   :DOSAGE:    %s
   :FREQUENCY: %s
   :TIMES:     %s
   :WITH_FOOD: %s%s
   :STARTED:   %s
   :END:
"
                            name dosage
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

;;; --- Supplement Entry ---

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
            (insert (format "\n** %s                                  :supplement:
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

;;;###autoload
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
    (unless (string-match-p "Dropbox\\|Google Drive\\|Syncthing\\|org" dir)
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
      (let ((med-name (read-string "Medication name: "))
            (dosage (read-string "Dosage (e.g., 40mg): "))
            (frequency (completing-read "Frequency: "
                                        '("daily" "twice-daily" "weekly" "as-needed")))
            (times (read-string "Time(s) to take (e.g., 07:00 or 07:00 13:00): "))
            (with-food (y-or-n-p "Take with food? "))
            (prescriber (let ((p (read-string "Prescriber (optional, press RET to skip): ")))
                          (if (string-empty-p p) nil p))))
        (sanad-health-setup--add-medication dir med-name dosage frequency times with-food prescriber)))

    ;; Step 5b: Supplements
    (while (y-or-n-p "Add a supplement? ")
      (let ((sup-name (read-string "Supplement name: "))
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
        (sanad-health-setup--add-supplement dir sup-name dosage frequency times with-food
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
                             (let ((sanad-health-directory dir))
                               (sanad-health-profile-get "SANAD_USER")))

    ;; Done — open dashboard
    (message "Setup complete! Opening your dashboard...")
    (sanad-health-dashboard)))

(provide 'sanad-health-setup)
;;; sanad-health-setup.el ends here
