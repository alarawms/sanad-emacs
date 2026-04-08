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

(require 'cl-lib)
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

;; Evil compatibility
(with-eval-after-load 'evil
  (evil-define-key* 'normal sanad-health-tracker-mode-map
    (kbd "RET") #'sanad-health-tracker-toggle
    "a" #'sanad-health-assign-block
    "p" #'sanad-health-pomodoro-start
    "n" #'sanad-health-tracker-add-note
    "e" #'sanad-health-tracker-end-of-day
    "g" #'sanad-health-tracker-refresh))

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
