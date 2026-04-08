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
