# Tally — Product Spec

> A scheduled-todo app where every day is binary: hit every task on its schedule, earn the day, extend the streak. Miss any task, break the chain. Built around iterative goal logging — pushups, water, reading minutes — so a daily target accumulates across the day.

This document is the source of truth for product behavior. It's written to be handed to an implementation team (or another Claude session) to draft a build plan. Where the design prototype (`tally.html`) and this spec disagree, the spec wins — but the prototype is the canonical reference for visual and interaction patterns.

---

## 1. Product North Star

**One rule: 100% the day.**

Tally is the opposite of a habit-tracker that rewards "best effort." A day is **earned** only if every task scheduled for that day is at 100% by midnight local time. There is no soft win, no points goal, no daily-average mode. This is the constraint that makes the streak meaningful — and the constraint everything else in the product must reinforce.

Target audience: people who want to build a few specific routines (fitness, hydration, reading, supplements) and respond to streak-loss anxiety as the motivator.

Platform: iOS (SwiftUI). The prototype is an HTML proof-of-concept.

---

## 2. Core Concepts

### 2.1 Task

A repeating commitment with:
- **Name** — user-defined
- **Type** — determines how completion is measured (see §2.2)
- **Schedule** — which days of the week + which times of day
- **Target** (some types) — numeric goal to reach by midnight
- **Unit** (some types) — for display (reps, oz, min, kg, pages, etc.)

A task can be archived (hidden from Today / library but history preserved) or deleted (history wiped — with confirmation).

### 2.2 Task Types

| Type      | What it tracks | How completion works | Logging UX |
|-----------|---------------|----------------------|------------|
| **check**   | One-shot: did you do it? | Single `true` log entry marks done. | Single "Mark complete" button. |
| **count**   | Iterative accumulation toward a target. (e.g. "100 pushups", "128 oz water") | Sum of log values ≥ target = done. Partial = "in progress." | Preset chips (`+5 / +10 / +20`) + custom input. |
| **timer**   | Minutes spent. (e.g. "Read 20 min", "Walk 30 min") | Sum of logged minutes ≥ target. | Preset chips (`+5m / +10m / target`) + custom input. |
| **numeric** | Single reading per day, no target. (e.g. weigh-in, mood 1–10) | Any entry counts as done for the day. | Numeric pad. |
| **yesno**   | A reflective daily question. (e.g. "Did you stretch?") | Either Yes or No answer counts as done. The value is recorded for stats but does not gate completion. | Two-button choice. |

### 2.3 Scheduling

- **Days** — array of weekdays (Mon=0..Sun=6). Empty array = every day. Presets: Daily, Weekdays, Weekends, M·W·F.
- **Times** — array of `HH:MM` strings, OR the special value `["all-day"]`.
  - For specific times, the *first* time is what's shown on Today; additional times act as reminder pings.
  - All-day tasks (water, mood) can be logged any time — no overdue state until midnight.
- **Overdue grace** — a task is "overdue" once its first scheduled time passes, but it's still catchable until midnight. The day flips at local midnight; missed tasks lock at that moment.

### 2.4 Day Completion + Streak

For a given date:
1. Compute the set of tasks scheduled that day (filter by day-of-week).
2. Compute each task's state (`done | partial | overdue | due`).
3. **Day earned** ⇔ every scheduled task is `done`.

**Streak** = consecutive earned days, walking back from yesterday. Today is *included* if it's already at 100%, otherwise it's not counted (so streak doesn't drop to 0 mid-morning).

**No grace days. No freezes. No partial credit.** This is intentional — see §1.

### 2.5 Log Entries

Every interaction produces an immutable `LogEntry`:
```
{ id, taskId, date (YYYY-MM-DD), time (HH:MM), value, ts (unix ms) }
```
- `value` is type-specific: `true`/`false` for check/yesno, a number for count/timer/numeric.
- Entries can be deleted (undo). The prototype lets you tap any entry in today's log to remove it.
- All derived state (day %, streak, task stats) is computed from the log on demand.

---

## 3. Screens

The prototype defines 8 primary screens + 2 detail overlays. Order reflects user priority.

### 3.1 Today (`/today`)
**Purpose:** the daily dashboard. What needs doing, what's done, day percentage.

Components:
- **Header** — date kicker, "Today" title, streak badge (taps through to Streak tab).
- **Day completion card** — large %, segmented bar (one tile per scheduled task, colored by status), count summary ("X done · Y in progress · Z overdue").
- **Time-block sections** — Morning (06–12), Afternoon (12–18), Evening (18+), All-day. Each section shows count `done/total` and a list of task rows.
- **Task row** — status pip, name, first scheduled time + current value label, 14-day sparkline, completion %. Tap → Task Detail.

Empty state: copy + "Add task" CTA.

### 3.2 Task Detail (overlay)
**Purpose:** log against one task and review its progress today.

Components:
- Back arrow + Edit shortcut.
- Type-specific **hero** (progress card for count/timer; status card for check; latest reading for numeric; yes/no answer).
- Type-specific **log controls** (see §2.2 logging UX).
- **Today's entries** — chronological list, tap to undo.
- **14-day mini-trend** + "View full stats" link.

### 3.3 Tasks (`/tasks`)
**Purpose:** browse all tasks ranked by completion rate.

Components:
- Header with "New" button.
- Sort toggle (rate / name).
- List rows: status dot (rate health), name + schedule meta, sparkline, 14-day rate %.
- Tap row → Task Stats.

### 3.4 Task Stats (overlay)
**Purpose:** see how you've actually been doing on one task.

Components:
- 30-day bar chart (height = day completion% for check/yesno, sum for count/timer, normalized value for numeric).
- Stat tiles (type-specific):
  - count/timer: Average/day, Best day, Total 30D, On-target count.
  - numeric: Latest, Average, Log rate, Entry count.
  - check/yesno: Completion %, Done count.
- Hour-of-day heatmap (when you tend to log).
- Recent entries list.

### 3.5 Add / Edit Task (overlay)
**Purpose:** create or modify a task.

Components:
- Name input.
- Type radio (5 options, with subtitles).
- Target + Unit inputs (shown for count, timer, numeric).
- Day-of-week picker (7 boxes, multi-select) + preset chips (Daily / Weekdays / M·W·F / Weekends).
- Times list with native time inputs + "All-day" toggle.
- Delete button (edit mode only).
- Save CTA in header.

Validation: name required, target > 0 for count/timer, at least one day selected, at least one time (or all-day).

### 3.6 Streak (`/streak`)
**Purpose:** the long view.

Components:
- **Hero card** — current streak number ("Xd"), best comparison, 30-day strip (each day = colored bar, click to review).
- **Stat tiles** — Best, Earned 60D, Average completion %.
- **Month calendar** — paginated month grid, days color-coded by completion. Tap a past day → Day Detail. Today is outlined.

### 3.7 Day Detail (overlay)
**Purpose:** review what happened on a past day.

Components:
- Header summary: "Day earned ✓" or "X of Y · missed" or "Rest day."
- Task list for that day with status + final %.
- Full log entries for that day.

### 3.8 More (`/more`)
**Purpose:** settings + management.

Components:
- Profile row (initials, active task count).
- **Appearance** — dark mode toggle, density (regular/compact), show icons.
- **Notifications** — link to Reminders.
- **Tasks** — link to Manage tasks (archive/delete), Add task.
- **Demo time-travel** *(prototype only)* — advance simulated clock +1h / +4h / +1d / +1wk; reset. Removed before ship.
- **Data** — replay onboarding, reset prototype.

### 3.9 Reminders (overlay)
**Purpose:** per-task notification config.

Components:
- Quiet hours toggle (22:00–06:30 default).
- Per-task chip set: `PING` (notify at task time), `NAG +15` (re-ping 15 min later if still pending), `SOUND`.

### 3.10 Manage Tasks (overlay)
**Purpose:** bulk task admin.

Components:
- All tasks (including archived). Per row: Edit, Archive/Restore, Delete.

### 3.11 Onboarding
**Purpose:** explain the rule, set expectations.

Components:
- "One rule. 100% the day." headline.
- Live 30-day strip preview (so the user sees the streak metaphor).
- 4 numbered features: Schedule, Log iteratively, Grace till midnight, Track everything.
- "Start tallying" CTA.

---

## 4. Interactions & UX Principles

- **Tap-to-log primacy** — every numeric task needs to be one tap away from a +N increment. Preset chips beat custom input. Custom input is the escape hatch.
- **Tap-to-undo** — every log entry shown is removable with a tap. No swipes, no menus. Mistakes are common; undoing must be effortless.
- **Status colors** (the only colors in the app besides ink + bg):
  - `pos` green — done
  - `accent` indigo — partial / in progress
  - `neg` red — overdue / missed
  - `dim` gray — pending / not scheduled
- **No filler** — the design is intentionally sparse. Sparklines beat sentences. Mono numerals everywhere. Editorial labels (`UPPERCASE WIDE TRACKING`) for category headers.
- **Streak anxiety, gently** — the segmented day bar shows the *shape* of today (3 of 5 tiles green) before showing the percent. This is more readable at a glance than a number.
- **Grace till midnight is a feature, not a bug** — overdue tasks should pulse red but stay catchable. Most "habit" apps that hard-fail at the scheduled time train people to give up at 8:05 AM when they miss an 8 AM ping.

---

## 5. Data Model

### Task
```ts
type TaskType = 'check' | 'count' | 'timer' | 'numeric' | 'yesno';

interface Task {
  id: string;
  name: string;
  type: TaskType;
  target: number | null;   // required for count, timer; null otherwise
  unit: string | null;     // display only; null for check/yesno
  days: number[];          // 0=Mon..6=Sun; empty = every day
  times: string[];         // ["HH:MM", ...] or ["all-day"]
  notif?: { ping: boolean; nag: boolean; sound: boolean; };
  archived: boolean;
  createdAt: number;       // unix ms
}
```

### LogEntry
```ts
interface LogEntry {
  id: string;
  taskId: string;
  date: string;            // "YYYY-MM-DD" — local
  time: string;            // "HH:MM" — local
  value: number | boolean; // see §2.5
  ts: number;              // unix ms
}
```

### Settings
```ts
interface Settings {
  dark: boolean;
  density: 'regular' | 'compact';
  icons: boolean;
  quietHours?: { start: string; end: string };
}
```

### Derived (selectors)
Don't store these — compute on demand:
- `taskState(task, date, log, now) → { status, pct, sum?, label, value? }`
- `dayCompletion(date, tasks, log, now) → { done, partial, overdue, total, pct }`
- `streak(tasks, log, now) → { current, best, history[] }`
- `taskHistory(task, log, now, days) → number[]` (for sparklines)

---

## 6. iOS Implementation Notes

The prototype is HTML + React for design exploration only. Native:

- **SwiftUI** for screens; **SwiftData** (or Core Data with CloudKit) for persistence.
- **Local notifications** via `UNUserNotificationCenter` — scheduled per task time, with optional +15 min nag follow-up.
- **WidgetKit**:
  - Lock-screen complication: streak number + day completion %.
  - Home screen medium widget: today's tasks as a checklist.
- **App Intents / Shortcuts** — "Log 20 pushups" voice intent that adds a count entry against the matching task.
- **iCloud sync** for multi-device — single source of truth is the log; tasks rarely change.
- **HealthKit** *(future)* — weigh-in and water tasks could mirror to Health.

### Performance
- Computing day completion or streak is O(tasks × days). For typical use (≤20 tasks, ≤365 days) this is trivially fast. No need for materialized views in v1.
- Log can grow indefinitely; assume ~5 entries/task/day × 365 days × 20 tasks ≈ 36k entries/year. Index by `(taskId, date)` for stats queries.

### Edge cases to handle
- **Midnight rollover** while app is open — observe `Calendar.current.startOfDay(for: now)` changes, refresh views.
- **DST / timezone changes** — entries store local `date` + `time` strings; reading `ts` for sorting only. Never re-derive `date` from `ts` after the fact.
- **Task created mid-day** — the task counts for "today" immediately if its `days` includes today's DOW and the user hasn't already passed all its times. Earning today requires hitting it.
- **Editing a task's schedule** — past completion data is preserved; only future days are reevaluated.
- **Deleting a task** — all its log entries go with it. Confirm destructive action.
- **Clock manipulation** — production should ignore the demo clock offset. Use `Date.now()` directly.

---

## 7. Out of Scope (v1)

Things explicitly **not** in v1, kept here so they're not accidentally rebuilt:

- Multi-user / sharing / accountability partners.
- Difficulty ramps ("week 1: 50 pushups, week 4: 100").
- Pause / vacation mode (gracefully break the streak — by design).
- Tagging / categories beyond time-block grouping.
- Wellness tracking integrations (Strava, MyFitnessPal).
- AI suggestions or coaching copy.
- Web app or Android.

---

## 8. Open Questions for the Build Plan

These are decisions the engineering planning step should weigh in on:

1. **Streak freeze?** v1 spec says no. But losing a 60-day streak to one off-day is brutal. Should there be a "one freeze per month" emergency button, off by default?
2. **Time-of-day grouping** — Today groups Morning/Afternoon/Evening/All-day. Should the boundaries be user-configurable?
3. **Notification fatigue** — what's the right default? PING only at first time? Or all scheduled times?
4. **Onboarding required?** — should new users be forced through seed-task selection (pushups, water, etc.) or land in an empty Today?
5. **Local-first vs cloud-first** — SwiftData with iCloud sync is the assumption. Confirm before scoping the data layer.

---

## 9. Reference

- **Prototype:** `Tally.html` (interactive, persistent via localStorage)
- **Component breakdown:** `tally/tally-*.jsx` — state, UI atoms, today, tasks, streak, more
- **Design exploration history:** `explorations/Habits.html` (4 habit-app directions + 3 todo directions including the original Tally exploration)
