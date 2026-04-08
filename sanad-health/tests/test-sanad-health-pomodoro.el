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
