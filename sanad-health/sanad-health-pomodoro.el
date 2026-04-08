;;; sanad-health-pomodoro.el --- Pomodoro timer for sanad-health -*- lexical-binding: t; -*-

;; Author: alarawms
;; Keywords: health, org, adhd

;;; Commentary:

;; Pomodoro timer with ADHD-specific features for sanad-health.
;;
;; Features:
;; - Customizable work/break/long-break intervals from profile.org
;; - Mode-line countdown display with task and session info
;; - Forced break enforcement (configurable)
;; - Session goal display during work
;; - Distraction counter
;; - Pomodoro logging to daily log
;;
;; Lifecycle:
;; 1. Start pomodoro on a focus block -> begins countdown
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
