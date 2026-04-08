# Sanad Health Mode — Design Specification

**Date**: 2026-04-08
**Status**: Approved
**Approach**: Modular Package with Core + Plugins (Approach B)

---

## 1. Overview

Sanad Health Mode is an Emacs major mode for health and ADHD management. It provides a unified command center for daily routines, medication tracking, brain dumps, focus timers, metric logging, and goal tracking — all built on top of org-mode.

### Design Principles

- **Multi-user**: Different people with different conditions, medications, and routines
- **Org-native**: All data in `.org` format, integrates with `org-agenda`
- **Modular**: Core + optional modules — users enable only what they need
- **ADHD-aware**: Fast logging, visual progress, minimal friction, forced breaks
- **Documented**: Thorough docstrings, commentary headers, onboarding guidance, contextual help
- **Future-proof**: New features = new module file, no monolith

### Target Users

- People with ADHD managing medication, routines, and focus
- People tracking supplements with evidence-based optimization cycles
- Anyone wanting structured daily health tracking integrated into their Emacs workflow

---

## 2. Package Structure

```
sanad-health/
├── sanad-health.el            ;; Core: profiles, customization, data paths, dashboard
├── sanad-health-setup.el      ;; Onboarding wizard (first-use interactive setup)
├── sanad-health-agenda.el     ;; org-agenda integration, routine blocks, goals/projects
├── sanad-health-meds.el       ;; Medication/supplement tracking and reminders
├── sanad-health-capture.el    ;; Brain dump and quick capture via org-capture
├── sanad-health-pomodoro.el   ;; Pomodoro timer with org-clock integration
├── sanad-health-log.el        ;; Daily metrics logging and weekly aggregation
├── sanad-health-tracker.el    ;; "Start My Day" interactive checklist
├── templates/
│   ├── daily-log.org          ;; Template for daily logs
│   ├── routine.org            ;; Default routine blocks
│   └── supplements.org        ;; Supplement tracker template
└── README.org                 ;; Package documentation and usage guide
```

### Module Loading

Users configure which modules to load:

```elisp
(setq sanad-health-modules '(agenda meds capture pomodoro log tracker))
```

Each module is independent — loading `pomodoro` without `meds` works fine. The core (`sanad-health.el`) is always loaded.

---

## 3. Core (`sanad-health.el`)

### Responsibilities

- `defgroup sanad-health` with all customization variables
- User profile management: name, health directory path, active modules
- `sanad-health-dashboard` command — opens the main buffer
- Auto-detection: if health dir doesn't exist, triggers setup wizard
- Module loading based on `sanad-health-modules` list
- Top-level keymap `sanad-health-mode-map`

### Customization Variables

| Variable | Default | Purpose |
|---|---|---|
| `sanad-health-directory` | `nil` | Path to user's health data directory |
| `sanad-health-modules` | `'(agenda meds capture pomodoro log tracker)` | Active modules |
| `sanad-health-show-hints` | `t` | Show inline keybinding hints in buffers |
| `sanad-health-user-name` | `nil` | User's display name |

### Global Keybindings (prefix: `C-c h`)

| Key | Command | Description |
|---|---|---|
| `C-c h d` | `sanad-health-dashboard` | Open dashboard |
| `C-c h a` | `sanad-health-agenda` | Health agenda view |
| `C-c h c` | `sanad-health-capture` | Quick capture / brain dump |
| `C-c h t` | `sanad-health-tracker` | Start My Day tracker |
| `C-c h l` | `sanad-health-log` | Today's daily log |
| `C-c h p` | `sanad-health-pomodoro` | Pomodoro prefix |
| `C-c h m` | `sanad-health-meds` | Medications prefix |
| `C-c h s` | `sanad-health-settings` | Open profile/settings |
| `C-c h ?` | `sanad-health-help` | Context-aware help |
| `C-c h h` | `sanad-health-toggle-hints` | Toggle inline hints |

---

## 4. Onboarding Wizard (`sanad-health-setup.el`)

Triggered on first `M-x sanad-health-dashboard` when `sanad-health-directory` is nil.

### Setup Flow

1. **Welcome message** — explains what sanad-health does
2. **Choose directory** — `read-directory-name` prompt, suggests `~/org/health/` or `~/Dropbox/health/`, warns if not in a syncable location
3. **Create folder structure**:
   ```
   health-dir/
   ├── logs/          ;; daily logs (YYYY-MM/ subdirs)
   ├── routines/      ;; routine block definitions
   ├── meds/          ;; medication/supplement files
   ├── captures/      ;; brain dump inbox
   └── profile.org    ;; user profile and config
   ```
4. **User profile** — asks name, conditions (ADHD, chronic pain, etc. stored as org tags)
5. **Medications** — interactive loop: "Add a medication? (y/n)" then name, dosage, time(s), with/without food, prescriber (optional). Also supports supplements with evidence level, cost tier, and phase. Writes to `meds/medications.org`
6. **Routine blocks** — offers default ADHD routine or blank. Writes to `routines/daily.org`
7. **Module selection** — checkboxes for which modules to enable
8. **Done** — saves config to Emacs custom variables, opens dashboard

### Profile File (`profile.org`)

```org
#+TITLE: Health Profile
#+PROPERTY: SANAD_USER SOS
#+PROPERTY: SANAD_CONDITIONS ADHD
#+PROPERTY: SANAD_MODULES agenda meds capture pomodoro log tracker

* Preferences
:PROPERTIES:
:WAKE_TIME: 06:30
:SLEEP_TIME: 22:00
:POMODORO_WORK: 25
:POMODORO_BREAK: 5
:POMODORO_LONG_BREAK: 15
:POMODORO_SESSIONS: 4
:ONBOARDED: t
:SHOW_HINTS: t
:END:
```

---

## 5. Dashboard (`sanad-health.el`)

The main view. A read-only `special-mode` buffer with three visible panels.

### Layout

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 Sanad Health — SOS — Tue Apr 8, 2026
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Dashboard
  Focus: 7/10 (avg 6.2)  Sleep: 8/10  Energy: 6/10  Mood: 7/10
  Streak: 4 days  |  Pomodoros today: 3/8  |  Meds: taken
  ─────────────────────────────────────────────

Agenda (today)
  06:30  Wake + hydrate
  07:00  Morning meds (Vyvanse 40mg)
  08:00  Focus Block 1 -> PhD Ch.3        [p] start pomodoro
  10:00  Focus Block 2 -> PHPS40600       [p] start pomodoro
  14:00  Focus Block 3 -> (unassigned)    [a] assign
  ...
  ─────────────────────────────────────────────

Brain Dump (captures/inbox.org)
  - [ ] Look into magnesium glycinate dosage
  - [ ] Email supervisor about chapter draft
  [c] quick capture   [r] refile
```

### Dashboard Keybindings

| Key | Action |
|---|---|
| `RET` | Jump to item at point (opens the org entry) |
| `c` | Quick capture (brain dump) |
| `p` | Start pomodoro for item at point |
| `t` | Open Start My Day tracker |
| `l` | Open today's daily log |
| `m` | Mark medication taken (timestamps it) |
| `r` | Refile brain dump item |
| `a` | Assign work to focus block |
| `g` | Refresh dashboard |
| `s` | Open settings/profile |
| `?` | Context-aware help |
| `q` | Quit dashboard |

### Data Sources

- **Metrics**: reads today's log file properties (shows "—" if not logged yet)
- **Agenda**: pulls from `org-agenda-files` filtered by `sanad-health` tag/category
- **Brain dump**: reads `captures/inbox.org` top-level headings
- **Auto-refresh**: updates on `window-state-change-hook`

### First-Time Welcome Overlay

On first dashboard open after setup (`:ONBOARDED: t` but no prior usage):

```
Welcome to Sanad Health, SOS!

Here's how to get started:
1. Press [t] to open Start My Day — check off your morning routine
2. Press [m] when you take your meds
3. Press [p] on a focus block to start a pomodoro
4. Press [c] anytime to brain dump a thought
5. Press [l] at end of day to log your metrics

Press [?] anytime for full keybindings
Press [q] to dismiss this message
```

Dismissed with `q`, never shown again.

---

## 6. Agenda Integration (`sanad-health-agenda.el`)

### Org-Agenda Integration

- Adds user's health dir to `org-agenda-files`
- All health entries use category `Health` and tag `:sanad:`
- Custom agenda command bound to `C-c h a`

### Routine Blocks (`routines/daily.org`)

```org
#+CATEGORY: Health
#+FILETAGS: :sanad:

* Routines
** TODO Wake + hydrate
   SCHEDULED: <%%(diary-daily)>
   :PROPERTIES:
   :EFFORT:   5min
   :BLOCK:    morning
   :ORDER:    1
   :END:

** TODO Focus Block 1
   SCHEDULED: <%%(diary-daily)>
   :PROPERTIES:
   :EFFORT:   90min
   :BLOCK:    morning
   :ORDER:    4
   :POMODORO: t
   :ASSIGNED:
   :GOAL:
   :END:
```

### Properties

| Property | Purpose |
|---|---|
| `:BLOCK:` | Groups items: morning, midday, afternoon, evening |
| `:ORDER:` | Display sequence within a block |
| `:POMODORO: t` | Marks entries that can trigger pomodoro timer |
| `:MEDS: t` | Marks entries that trigger medication confirmation |
| `:ASSIGNED:` | Links to a project (e.g., `phd/chapter3`) |
| `:GOAL:` | Free-text session goal, shown in pomodoro header |

### Tags — Three-Layer System

**System tags** (internal, used by the mode):
- `:sanad:`, `:meds:`, `:pomodoro:`, `:inbox:`

**Project tags** (user-defined, filterable in agenda):
- `:phd:`, `:course:`, `:chapter3:`, `:PHPS40600:`

**Goal tags** (tracked toward targets):
- `:goal:`, `:daily:`, `:quarterly:`

### Focus Block Assignment

- `a` key on a focus block in dashboard prompts to pick from active projects or type new
- `:ASSIGNED:` links to a project/goal entry
- `:GOAL:` is a free-text session goal visible during pomodoros
- Unassigned blocks show as "(unassigned)" with `[a] assign` hint

### Goals/Projects File (`routines/goals.org`)

```org
#+CATEGORY: Goals
#+FILETAGS: :sanad:goals:

* Active Projects
** PhD Thesis                                        :phd:
   :PROPERTIES:
   :DEADLINE:  2026-09-01
   :TARGET:    Complete chapters 1-4
   :END:
*** TODO Chapter 3 draft                             :chapter3:
*** TODO Chapter 4 outline                           :chapter4:

** PHPS40600 Course                                  :course:
   :PROPERTIES:
   :DEADLINE:  2026-06-15
   :END:

* Goals
** Daily                                             :daily:
*** Habit: Exercise 30 min                           :exercise:
    :PROPERTIES:
    :STYLE:    habit
    :END:
*** Habit: Sleep by 22:00                            :sleep:
    :PROPERTIES:
    :STYLE:    habit
    :END:

** Quarterly                                         :quarterly:
*** Complete supplement optimization (6-week cycle)
    :PROPERTIES:
    :DEADLINE:  2026-05-19
    :END:
```

### Custom Agenda Views

| Binding | View |
|---|---|
| `C-c h a` | All health items for today (grouped by block) |
| `C-c h p` | Filter by project (prompted) |
| `C-c h g` | Goals progress (habits + deadlines) |

### Nightly Reset

- At midnight (or configured sleep time), all routine `DONE` items revert to `TODO`
- Day's completion data logged to daily log before reset
- Uses `org-map-entries` scoped to routine files
- Implemented via `run-at-time` or `midnight-hook`

---

## 7. Medication Tracking (`sanad-health-meds.el`)

### Medication File (`meds/medications.org`)

```org
#+CATEGORY: Meds
#+FILETAGS: :sanad:meds:

* Medications
** Vyvanse 40mg                                  :prescription:adhd:
   :PROPERTIES:
   :DOSAGE:    40mg
   :FREQUENCY: daily
   :TIMES:     07:00
   :WITH_FOOD: yes
   :PRESCRIBER: Dr. Smith
   :STARTED:   2026-03-01
   :END:

* Supplements
** Magnesium Glycinate                           :supplement:sleep:
   :PROPERTIES:
   :DOSAGE:    400mg
   :FREQUENCY: daily
   :TIMES:     21:00
   :WITH_FOOD: no
   :EVIDENCE:  strong
   :COST_TIER: budget
   :PHASE:     foundation
   :END:

* Inactive

* Side Effects Log
```

### Reminders

- On mode activation, `run-at-time` timers set for each `:TIMES:` entry
- Reminder shows minibuffer message + optional `notifications-notify` (system notification)
- If not confirmed within 15 min, second reminder fires
- `m` key in dashboard marks med as taken, timestamps a LOGBOOK entry:
  ```org
  :LOGBOOK:
  - Taken at [2026-04-08 Tue 07:05]
  - Taken at [2026-04-07 Mon 07:12]
  :END:
  ```

### Adding Medications (`C-c h m a`)

Interactive prompts:
1. Type: medication or supplement
2. Name: free text
3. Dosage: free text (e.g., "40mg", "2000mg EPA/DHA")
4. Frequency: daily / twice daily / weekly / as needed
5. Time(s): prompted per frequency
6. With food: yes/no
7. If medication: prescriber name (optional)
8. If supplement: evidence level (strong/moderate/mixed), cost tier ($/$$/$$$), phase (foundation/deficiency-correction/fine-tuning/optimize)

Writes entry to `meds/medications.org`, sets up reminder timer immediately.

### Supplement Testing Workflow

- `:PHASE:` property tracks optimization phase
- 4-6 week trial cycles per supplement
- `C-c h m v` — evaluate supplement: prompts for keep/drop/adjust, logs decision with date and reason

### Keybindings (prefix: `C-c h m`)

| Key | Action |
|---|---|
| `C-c h m a` | Add new medication or supplement |
| `C-c h m e` | Edit existing entry |
| `C-c h m r` | Review full stack (table view) |
| `C-c h m v` | Evaluate supplement (keep/drop/adjust) |
| `C-c h m d` | Discontinue (moves to Inactive with date + reason) |
| `C-c h m h` | History (all changes with dates) |

### Stack Review Buffer (`C-c h m r`)

```
Supplement Stack — Active
───────────────────────────────────────────────────────────
Name                 Dosage    Time   Evidence  Cost   Phase
Magnesium Glycinate  400mg     21:00  strong    $      foundation
Omega-3 Fish Oil     2000mg    07/13  moderate  $$     deficiency
Vitamin D3           4000IU    07:00  strong    $      foundation
───────────────────────────────────────────────────────────
[a] add  [e] evaluate  [d] drop  [h] history
```

---

## 8. Brain Dump & Capture (`sanad-health-capture.el`)

### Org-Capture Templates

Registered into the user's existing `org-capture-templates`, not replacing:

| Key | Name | Target | Purpose |
|---|---|---|---|
| `h t` | Health Task | `captures/inbox.org :: Inbox` | Actionable task with TODO |
| `h b` | Brain Dump | `captures/inbox.org :: Inbox` | Free-form thought/note |
| `h n` | Health Note | `captures/inbox.org :: Notes` | Tagged note |
| `h s` | Side Effect | `meds/medications.org :: Side Effects Log` | Med/severity/description |

### Inbox File (`captures/inbox.org`)

```org
#+TITLE: Health Inbox
#+FILETAGS: :sanad:inbox:

* Inbox
** TODO Look into magnesium glycinate dosage
   :PROPERTIES:
   :CAPTURED: [2026-04-08 Tue 09:32]
   :END:

* Notes
** Felt jittery after doubling omega-3 dose :note:
   [2026-04-07 Mon 14:22]
```

### Dashboard Integration

- Brain dump section shows top-level entries from inbox
- `c` in dashboard triggers `org-capture` with health templates pre-selected
- `r` on item triggers `org-refile`
- `d` marks done, `k` kills/deletes

### Refile Targets

Project headings in `goals.org`, routine blocks, and an archive file.

---

## 9. Pomodoro Timer (`sanad-health-pomodoro.el`)

### Configuration (from `profile.org`)

| Setting | Default | Property |
|---|---|---|
| Work duration | 25 min | `:POMODORO_WORK:` |
| Break duration | 5 min | `:POMODORO_BREAK:` |
| Long break | 15 min | `:POMODORO_LONG_BREAK:` |
| Sessions per set | 4 | `:POMODORO_SESSIONS:` |

### Mode-Line Display

```
Pomodoro: Focus Block 1 -> PhD Ch.3  [18:42] (2/4)
```

During break:
```
Break [4:32] — stand up and stretch!
```

### Lifecycle

1. `p` on a focus block (or `C-c h p p`) starts pomodoro, clocks into org entry
2. Work phase counts down. On finish: system notification + audio bell
3. Break phase starts automatically
4. After configured sessions: long break with "Take a real break — move!" notification
5. Each completed pomodoro logged to daily log pomodoro table

### Pomodoro Log Entry (in daily log)

```org
* Pomodoros
| # | Task          | Project   | Start | End   | Completed |
|---+---------------+-----------+-------+-------+-----------|
| 1 | Focus Block 1 | PhD Ch.3  | 08:00 | 08:25 | yes       |
| 2 | Focus Block 1 | PhD Ch.3  | 08:30 | 08:55 | yes       |
| 3 | Focus Block 2 | PHPS40600 | 10:00 | 10:25 | abandoned |
```

### ADHD-Specific Features

- **Forced break enforcement**: during break, reminder to stand/stretch. No "skip break" by default (configurable)
- **Session goal visible**: `:GOAL:` property text stays on screen during work
- **Distraction counter**: `C-c h p d` logs a distraction tally during pomodoro

### Keybindings (prefix: `C-c h p`)

| Key | Action |
|---|---|
| `C-c h p p` | Start pomodoro (prompts for task if not on one) |
| `C-c h p s` | Stop current pomodoro |
| `C-c h p e` | Extend current phase +5 min |
| `C-c h p d` | Log a distraction |
| `C-c h p v` | View today's pomodoro stats |

---

## 10. Daily Log (`sanad-health-log.el`)

### Log File Location

`logs/YYYY-MM/daily-log-YYYY-MM-DD.org` — auto-created from template on first access.

### Log Structure

```org
#+TITLE: Daily Log — 2026-04-08 Tuesday
#+FILETAGS: :sanad:log:
#+PROPERTY: SANAD_USER SOS

* Metrics
:PROPERTIES:
:FOCUS:
:SLEEP:
:ENERGY:
:MOOD:
:PRODUCTIVITY:
:DOPAMINE_CTRL:
:BEST_FOCUS_TIME:
:WORST_FOCUS_TIME:
:END:

* Medications
- [ ] 07:00 Vyvanse 40mg
- [ ] 07:00 Omega-3 2000mg
- [ ] 21:00 Magnesium 400mg

* Routine Completion
- [ ] Wake + hydrate
- [ ] Morning meds
- [ ] Protein breakfast
- [ ] Focus Block 1
- [ ] Focus Block 2
- [ ] Focus Block 3
- [ ] Exercise
- [ ] Prep for tomorrow
- [ ] Digital sunset
- [ ] Sleep on time

* Pomodoros
| # | Task | Project | Start | End | Completed |
|---+------+---------+-------+-----+-----------|

* Side Effects / Adjustments

* Notes
```

### Auto-Population

- Medication checkboxes generated from active entries in `meds/medications.org`
- Routine checkboxes generated from `routines/daily.org`
- Pomodoro table filled throughout the day by `sanad-health-pomodoro.el`
- Med confirmations from dashboard sync to log checkboxes

### Interactive Logging

| Command | Description |
|---|---|
| `C-c h l l` | Open today's log |
| `C-c h l m` | Log all metrics (prompts for each 1-10 score) |
| `C-c h l q` | Quick log: Focus + Energy + Mood only |
| `C-c h l w` | Generate weekly summary |
| `C-c h l t` | View trends (last 4 weeks comparison) |

### Weekly Aggregation (Sundays)

Reads the week's log files, computes averages, appends to `logs/weekly-summaries.org`:

```org
* Weekly Summary — Week 15 (Apr 7-13)
:PROPERTIES:
:AVG_FOCUS:    6.8
:AVG_SLEEP:    7.2
:AVG_ENERGY:   6.0
:AVG_MOOD:     7.0
:ROUTINE_RATE: 78%
:POMODOROS:    24
:DISTRACTIONS: 18
:END:
```

---

## 11. Start My Day Tracker (`sanad-health-tracker.el`)

### Buffer Layout

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 Start My Day — Tuesday Apr 8, 2026
 Progress: xxxxxxxx........ 4/10 (40%)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Morning
  [X] 06:30  Wake + hydrate                    done 06:35
  [X] 07:00  Morning meds (Vyvanse 40mg)       done 07:02
  [X] 07:30  Protein breakfast                 done 07:28
  [X] 08:00  Focus Block 1 -> PhD Ch.3         done 09:25

Midday
  [ ] 09:30  Exercise break
  [ ] 10:00  Focus Block 2 -> PHPS40600
  [ ] 12:00  Lunch + supplements

Afternoon
  [ ] 13:00  Focus Block 3 -> (unassigned)     [a] assign
  [ ] 17:00  Prep for tomorrow

Evening
  [ ] 21:00  Digital sunset
  [ ] 22:00  Sleep on time
```

### Behavior

- `RET` toggles item done/undone, records completion timestamp
- Progress bar updates live
- Completion timestamps sync to daily log
- Items pulled from `routines/daily.org`

### ADHD Motivators

- Visual progress bar for immediate dopamine feedback
- 100% completion: celebratory message
- Streak counter: consecutive days with >80% completion
- 30+ min overdue items: subtle highlight (not aggressive — avoids shame spiraling)

### End of Day

- `e` key triggers end-of-day review: completed vs. missed, one-line reflection prompt
- Reflection stored in daily log under Notes
- Triggers nightly reset of routine items

### Keybindings

| Key | Action |
|---|---|
| `RET` | Toggle item done/undone |
| `a` | Assign work to focus block |
| `p` | Start pomodoro for item at point |
| `n` | Add a note to this item |
| `e` | End-of-day review |
| `g` | Refresh |
| `q` | Back to dashboard |

---

## 12. Help & Onboarding System

### First-Time Welcome Overlay

Shown on first dashboard open after setup:

```
Welcome to Sanad Health, SOS!

Here's how to get started:
1. Press [t] to open Start My Day — check off your morning routine
2. Press [m] when you take your meds
3. Press [p] on a focus block to start a pomodoro
4. Press [c] anytime to brain dump a thought
5. Press [l] at end of day to log your metrics

Press [?] anytime for full keybindings
Press [q] to dismiss this message
```

Dismissed once, never shown again (`:ONBOARDED: t` in profile).

### Context-Aware Help (`?` key)

Available in every sanad-health buffer. Shows bindings relevant to the current buffer.

### Inline Hints

- Keybinding hints shown next to actionable items (e.g., `[p]`, `[a]`, `[c]`)
- Toggle on/off with `C-c h h`
- Setting stored in profile as `:SHOW_HINTS:`

---

## 13. Data Export

Org-mode's built-in export system handles doctor-ready reports:
- `C-c C-e` on any health file exports to PDF, HTML, or plain text
- Weekly summaries and daily logs are already structured for readability
- Auto-generated reports are a planned future module (not in initial scope)

---

## 14. File Naming Conventions

| File Type | Pattern | Example |
|---|---|---|
| Daily log | `logs/YYYY-MM/daily-log-YYYY-MM-DD.org` | `logs/2026-04/daily-log-2026-04-08.org` |
| Weekly summary | `logs/weekly-summaries.org` | — |
| Routine | `routines/daily.org` | — |
| Goals/projects | `routines/goals.org` | — |
| Medications | `meds/medications.org` | — |
| Captures/inbox | `captures/inbox.org` | — |
| Profile | `profile.org` | — |
| Templates | `templates/*.org` | `templates/daily-log.org` |

---

## 15. Dependencies

- Emacs 28+ (for `special-mode` features and native compilation)
- `org-mode` (bundled with Emacs)
- `org-agenda` (bundled with org-mode)
- `notifications` (bundled with Emacs, for system notifications)
- No external packages required for core functionality

---

## 16. Future Modules (Out of Scope for v1)

- `sanad-health-report.el` — auto-generated doctor reports with trends and charts
- `sanad-health-sync.el` — multi-device sync coordination
- `sanad-health-export.el` — CSV/JSON export for external analysis
- `sanad-health-mood.el` — detailed mood/emotion tracking beyond 1-10 scale
- `sanad-health-sleep.el` — sleep diary with detailed sleep stage tracking
