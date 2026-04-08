;;; sanad-health-meds.el --- Medication tracking for sanad-health -*- lexical-binding: t; -*-

;; Author: alarawms
;; Keywords: health, org, adhd

;;; Commentary:

;; Medication and supplement tracking for sanad-health.
;;
;; Features:
;; - Read/add/edit/discontinue medications and supplements
;; - Timed reminders via `run-at-time' and `notifications-notify'
;; - Medication taken confirmation with LOGBOOK timestamps
;; - Stack review buffer (table view of all active meds)
;; - Supplement evaluation workflow (keep/drop/adjust)
;;
;; Keybindings (prefix C-c h m):
;;   a - Add medication or supplement
;;   r - Review stack (table view)
;;   v - Evaluate supplement

;;; Code:

(require 'sanad-health)
(require 'notifications nil t)  ;; Optional: system notifications

;;; --- Reading Medications ---

(defun sanad-health-meds--read-active ()
  "Read all active medications and supplements from medications.org.
Returns a list of plists with :name, :dosage, :times, :frequency,
:with-food, :evidence, :cost-tier, :phase, :type.
Skips items under * Inactive and * Side Effects Log headings."
  (let ((meds-file (sanad-health-meds-file))
        items current-section)
    (when (file-exists-p meds-file)
      (with-temp-buffer
        (insert-file-contents meds-file)
        (org-mode)
        (goto-char (point-min))
        (org-map-entries
         (lambda ()
           (let ((level (org-current-level))
                 (heading (org-get-heading t t t t)))
             (cond
              ((= level 1)
               (setq current-section heading))
              ((and (= level 2)
                    (not (equal current-section "Inactive"))
                    (not (equal current-section "Side Effects Log")))
               (push (list :name heading
                           :dosage (or (org-entry-get (point) "DOSAGE") "")
                           :times (or (org-entry-get (point) "TIMES") "")
                           :frequency (or (org-entry-get (point) "FREQUENCY") "")
                           :with-food (equal (org-entry-get (point) "WITH_FOOD") "yes")
                           :evidence (org-entry-get (point) "EVIDENCE")
                           :cost-tier (org-entry-get (point) "COST_TIER")
                           :phase (org-entry-get (point) "PHASE")
                           :type (if (equal current-section "Medications")
                                     "medication" "supplement"))
                     items)))))
         nil nil)))
    (nreverse items)))

;;; --- Recording Taken ---

(defun sanad-health-meds--record-taken (med-name)
  "Record that MED-NAME was taken by adding a LOGBOOK entry."
  (let ((meds-file (sanad-health-meds-file)))
    (with-current-buffer (find-file-noselect meds-file)
      (goto-char (point-min))
      (org-map-entries
       (lambda ()
         (when (equal (org-get-heading t t t t) med-name)
           (let ((entry-begin (point))
                 (entry-end (save-excursion (org-end-of-subtree t t) (point))))
             ;; Look for existing LOGBOOK within the entry
             (if (re-search-forward "^[ \t]*:LOGBOOK:" entry-end t)
                 ;; LOGBOOK exists — insert after the :LOGBOOK: line
                 (progn
                   (forward-line 1)
                   (insert (format "   - Taken at %s\n"
                                   (format-time-string "[%Y-%m-%d %a %H:%M]"))))
               ;; No LOGBOOK — create one after the properties drawer
               (goto-char entry-begin)
               (org-end-of-meta-data t)
               (insert (format "   :LOGBOOK:\n   - Taken at %s\n   :END:\n"
                               (format-time-string "[%Y-%m-%d %a %H:%M]")))))))
       nil nil)
      (save-buffer))))

(defun sanad-health-meds--take ()
  "Interactively mark a medication as taken."
  (interactive)
  (let* ((meds (sanad-health-meds--read-active))
         (names (mapcar (lambda (m) (plist-get m :name)) meds))
         (chosen (completing-read "Mark as taken: " names nil t)))
    (sanad-health-meds--record-taken chosen)
    (message "Marked %s as taken at %s" chosen (format-time-string "%H:%M"))))

;;; --- Discontinue ---

(defun sanad-health-meds--discontinue (med-name reason)
  "Move MED-NAME to the Inactive section with REASON."
  (let ((meds-file (sanad-health-meds-file)))
    (with-current-buffer (find-file-noselect meds-file)
      (goto-char (point-min))
      ;; Find the entry, capture text and bounds
      (let (entry-text entry-start entry-end)
        (org-map-entries
         (lambda ()
           (when (equal (org-get-heading t t t t) med-name)
             (setq entry-start (point))
             (org-end-of-subtree t t)
             (setq entry-end (point))
             (setq entry-text (buffer-substring entry-start entry-end))))
         nil nil)
        (when entry-text
          ;; Delete from current location
          (delete-region entry-start entry-end)
          ;; Find Inactive heading and insert there
          (goto-char (point-min))
          (when (re-search-forward "^\\* Inactive" nil t)
            (end-of-line)
            (insert "\n" entry-text)
            ;; Add discontinuation note after the entry heading
            (goto-char (point-min))
            (when (re-search-forward "^\\* Inactive" nil t)
              (when (re-search-forward (regexp-quote med-name) nil t)
                (org-end-of-meta-data t)
                (insert (format "   DISCONTINUED: %s -- %s\n"
                                (format-time-string "[%Y-%m-%d %a]")
                                reason)))))))
      (save-buffer))))

;;; --- Stack Review ---

(defun sanad-health-meds--format-stack-table (meds)
  "Format MEDS list as a readable table string."
  (let ((header (format "%-25s %-10s %-8s %-10s %-8s %-15s\n"
                        "Name" "Dosage" "Time" "Evidence" "Cost" "Phase"))
        (separator (make-string 76 ?\u2500)))
    (concat
     "Supplement Stack \u2014 Active\n"
     separator "\n"
     header
     separator "\n"
     (mapconcat
      (lambda (m)
        (format "%-25s %-10s %-8s %-10s %-8s %-15s"
                (plist-get m :name)
                (or (plist-get m :dosage) "")
                (or (plist-get m :times) "")
                (or (plist-get m :evidence) "\u2014")
                (or (plist-get m :cost-tier) "\u2014")
                (or (plist-get m :phase) "\u2014")))
      meds "\n")
     "\n" separator "\n")))

(defun sanad-health-meds-review ()
  "Open the medication stack review buffer."
  (interactive)
  (let* ((meds (sanad-health-meds--read-active))
         (buf (get-buffer-create "*Sanad Health Meds*")))
    (with-current-buffer buf
      (let ((inhibit-read-only t))
        (erase-buffer)
        (insert (sanad-health-meds--format-stack-table meds))
        (when sanad-health-show-hints
          (insert "\n[a] add  [v] evaluate  [d] discontinue  [h] history  [q] close\n")))
      (special-mode))
    (pop-to-buffer buf)))

;;; --- Add Medication/Supplement (Interactive) ---

(defun sanad-health-meds-add ()
  "Interactively add a new medication or supplement."
  (interactive)
  (let* ((type (completing-read "Type: " '("medication" "supplement") nil t))
         (name (read-string (format "%s name: " (capitalize type))))
         (dosage (read-string "Dosage (e.g., 40mg): "))
         (frequency (completing-read "Frequency: "
                                     '("daily" "twice-daily" "weekly" "as-needed") nil t))
         (times (read-string "Time(s) (e.g., 07:00 or 07:00 13:00): "))
         (with-food (y-or-n-p "Take with food? ")))
    (if (equal type "medication")
        (let ((prescriber (let ((p (read-string "Prescriber (optional, RET to skip): ")))
                            (if (string-empty-p p) nil p))))
          (sanad-health-setup--add-medication
           sanad-health-directory name dosage frequency times with-food prescriber))
      (let ((evidence (completing-read "Evidence: " '("strong" "moderate" "mixed") nil t))
            (cost-tier (completing-read "Cost tier: " '("budget" "mid" "premium") nil t))
            (phase (completing-read "Phase: "
                                    '("foundation" "deficiency-correction"
                                      "fine-tuning" "optimize") nil t)))
        (sanad-health-setup--add-supplement
         sanad-health-directory name dosage frequency times with-food
         evidence cost-tier phase)))
    ;; Set up reminder immediately
    (sanad-health-meds--setup-reminder name times)
    (message "Added %s. Reminder set for %s." name times)))

;;; --- Reminders ---

(defvar sanad-health-meds--reminder-timers nil
  "Alist of (med-name . timer) for active reminders.")

(defun sanad-health-meds--setup-reminder (med-name times-str)
  "Set up a timed reminder for MED-NAME at TIMES-STR.
TIMES-STR can be a single time \"07:00\" or multiple \"07:00 13:00\"."
  (dolist (time-str (split-string times-str " " t))
    (let* ((hour (string-to-number (substring time-str 0 2)))
           (min (string-to-number (substring time-str 3 5)))
           (timer (run-at-time (format "%02d:%02d" hour min)
                               (* 24 60 60)
                               #'sanad-health-meds--remind
                               med-name)))
      (push (cons (format "%s@%s" med-name time-str) timer)
            sanad-health-meds--reminder-timers))))

(defun sanad-health-meds--remind (med-name)
  "Show a reminder to take MED-NAME."
  (message "Sanad Health: Time to take %s" med-name)
  (when (fboundp 'notifications-notify)
    (notifications-notify
     :title "Sanad Health"
     :body (format "Time to take %s" med-name)
     :urgency 'normal)))

(defun sanad-health-meds--setup-all-reminders ()
  "Set up reminders for all active medications."
  (let ((meds (sanad-health-meds--read-active)))
    (dolist (med meds)
      (let ((times (plist-get med :times))
            (name (plist-get med :name)))
        (when (and times (not (string-empty-p times)))
          (sanad-health-meds--setup-reminder name times))))))

;;; --- Evaluate Supplement ---

(defun sanad-health-meds-evaluate ()
  "Evaluate a supplement: keep, drop, or adjust."
  (interactive)
  (let* ((meds (sanad-health-meds--read-active))
         (supps (cl-remove-if-not
                 (lambda (m) (equal (plist-get m :type) "supplement"))
                 meds))
         (names (mapcar (lambda (m) (plist-get m :name)) supps))
         (chosen (completing-read "Evaluate supplement: " names nil t))
         (decision (completing-read "Decision: " '("keep" "drop" "adjust") nil t))
         (reason (read-string "Reason: ")))
    (if (equal decision "drop")
        (sanad-health-meds--discontinue chosen (format "Dropped: %s" reason))
      (message "Logged: %s \u2014 %s (%s)" chosen decision reason))))

;;; --- Keybindings ---

(defvar sanad-health-meds-command-map
  (let ((map (make-sparse-keymap)))
    (define-key map "a" #'sanad-health-meds-add)
    (define-key map "r" #'sanad-health-meds-review)
    (define-key map "v" #'sanad-health-meds-evaluate)
    map)
  "Command map for medication keybindings under C-c h m.")

(define-key sanad-health-command-map "m" sanad-health-meds-command-map)

;; Start reminders when module loads (only if health directory is configured)
(when sanad-health-directory
  (sanad-health-meds--setup-all-reminders))

(provide 'sanad-health-meds)
;;; sanad-health-meds.el ends here
