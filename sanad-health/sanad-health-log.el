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
