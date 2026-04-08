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
