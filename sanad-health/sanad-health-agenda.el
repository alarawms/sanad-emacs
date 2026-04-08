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
:assigned, :goal, :effort, :done."
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
