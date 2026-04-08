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
