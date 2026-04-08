;;; sanad-health-capture.el --- Brain dump and capture for sanad-health -*- lexical-binding: t; -*-

;; Author: alarawms
;; Keywords: health, org, adhd

;;; Commentary:

;; Brain dump and quick capture for sanad-health, built on org-capture.
;;
;; Registers health-specific capture templates into the user's existing
;; org-capture-templates without replacing them.
;;
;; Templates:
;;   h t - Health Task (TODO item to inbox)
;;   h b - Brain Dump (free-form thought to inbox)
;;   h n - Health Note (tagged note)
;;   h s - Side Effect (medication side effect log)
;;
;; Dashboard integration:
;;   c - Quick capture
;;   r - Refile item from inbox
;;   d - Mark item done
;;   k - Kill/delete item

;;; Code:

(require 'sanad-health)
(require 'org-capture)

;;; --- Template Registration ---

(defun sanad-health-capture--register-templates ()
  "Register sanad-health capture templates with org-capture.
Appends to `org-capture-templates' without replacing existing entries."
  (let ((inbox-file (sanad-health-captures-file))
        (meds-file (sanad-health-meds-file)))
    ;; Parent entry for health captures
    (unless (assoc "h" org-capture-templates)
      (add-to-list 'org-capture-templates '("h" "Health") t))
    ;; Health Task
    (unless (assoc "ht" org-capture-templates)
      (add-to-list 'org-capture-templates
                   `("ht" "Health Task" entry
                     (file+headline ,inbox-file "Inbox")
                     "* TODO %?\n  :PROPERTIES:\n  :CAPTURED: %U\n  :END:\n"
                     :empty-lines 1)
                   t))
    ;; Brain Dump
    (unless (assoc "hb" org-capture-templates)
      (add-to-list 'org-capture-templates
                   `("hb" "Brain Dump" entry
                     (file+headline ,inbox-file "Inbox")
                     "* %?\n  :PROPERTIES:\n  :CAPTURED: %U\n  :END:\n"
                     :empty-lines 1)
                   t))
    ;; Health Note
    (unless (assoc "hn" org-capture-templates)
      (add-to-list 'org-capture-templates
                   `("hn" "Health Note" entry
                     (file+headline ,inbox-file "Notes")
                     "* %? :note:\n  %U\n"
                     :empty-lines 1)
                   t))
    ;; Side Effect
    (unless (assoc "hs" org-capture-templates)
      (add-to-list 'org-capture-templates
                   `("hs" "Side Effect" entry
                     (file+headline ,meds-file "Side Effects Log")
                     "* %U \u2014 %?\n  :PROPERTIES:\n  :MED:  %^{Medication}\n  :SEVERITY: %^{Severity|mild|moderate|severe}\n  :END:\n"
                     :empty-lines 1)
                   t))))

;;; --- Reading Inbox ---

(defun sanad-health-capture--read-inbox ()
  "Read items under the Inbox heading in captures/inbox.org.
Returns a list of heading strings."
  (let ((inbox-file (sanad-health-captures-file))
        items)
    (when (file-exists-p inbox-file)
      (with-temp-buffer
        (insert-file-contents inbox-file)
        (org-mode)
        (goto-char (point-min))
        (when (re-search-forward "^\\* Inbox" nil t)
          (let ((bound (save-excursion
                         (or (re-search-forward "^\\* " nil t)
                             (point-max)))))
            (while (re-search-forward "^\\*\\* \\(.*\\)$" bound t)
              (push (match-string 1) items))))))
    (nreverse items)))

;;; --- Interactive Commands ---

(defun sanad-health-capture--do ()
  "Open org-capture with health templates pre-selected."
  (interactive)
  (sanad-health-capture--register-templates)
  (org-capture nil "h"))

(defun sanad-health-capture--refile ()
  "Refile the item at point in the dashboard brain dump section."
  (interactive)
  (let ((inbox-file (sanad-health-captures-file)))
    (when (file-exists-p inbox-file)
      (find-file inbox-file)
      (call-interactively #'org-refile))))

;;; --- Register with Core ---

;; Register templates when module loads
(when sanad-health-directory
  (sanad-health-capture--register-templates))

(provide 'sanad-health-capture)
;;; sanad-health-capture.el ends here
