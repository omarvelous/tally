# Tally iOS — Implementation Plan

## Context

Tally is a scheduled-todo streak app: 100% the day or break the chain. A working HTML/React prototype (~2,100 lines) and detailed spec exist at `../_tally/`. A fresh Xcode 26.5 project (Swift 6.3.2, SwiftData) is initialized at the current repo with one "Initial Commit" containing boilerplate. This plan replaces the boilerplate and builds the full app in phases.

**Current repo:** `/Users/omarjohnson/Development/github.com/omarvelous/tally/`
**Spec + prototype:** `/Users/omarjohnson/Development/github.com/omarvelous/_tally/`

---

## Phase 0: Project Scaffolding

**Goal:** Replace boilerplate, copy spec into repo, establish conventions.

### Steps

1. **Copy spec into repo** — `cp ../_tally/spec.md .` (source of truth lives in the project)
2. **Copy prototype into repo** — `cp -r ../_tally/prototype ./prototype` (reference material)
3. **Create CLAUDE.md** at repo root with conventions:
   - Swift 6.3.2, iOS 26.5, SwiftUI + SwiftData, `@Observable`
   - Selectors are pure functions in `Tally/Logic/`, not methods on models
   - Models in `Tally/Models/`, views grouped by screen in `Tally/Views/`
   - Design tokens in `Tally/Design/`
   - Build: `xcodebuild -scheme Tally -destination 'platform=iOS Simulator,name=iPhone 16' build`
   - Test: `xcodebuild -scheme Tally -destination 'platform=iOS Simulator,name=iPhone 16' test`
   - spec.md is source of truth; prototype/ is visual reference
4. **Delete `Item.swift`** (boilerplate model)
5. **Replace `ContentView.swift`** with a TabView shell (4 tabs: Today, Tasks, Streak, More + center Add button)
6. **Update `TallyApp.swift`** — remove `Item` from ModelContainer, wire new models (Phase 1)
7. **Create directory groups** in Xcode:
   ```
   Tally/Models/
   Tally/Logic/
   Tally/Design/
   Tally/Views/Components/
   Tally/Views/Today/
   Tally/Views/Tasks/
   Tally/Views/Streak/
   Tally/Views/More/
   Tally/Services/
   ```

### Files to modify
- `Tally/TallyApp.swift` — rewire ModelContainer
- `Tally/ContentView.swift` — replace with TabView shell
- `Tally/Item.swift` — delete

### Verification
- Project builds, app launches with 4 empty tabs + center Add button
- `git status` is clean after commit

---

## Phase 1: Data Models + Pure Logic + Tests

**Goal:** Core brain of the app — models, all selectors, comprehensive tests. No UI beyond the shell.

### 1A: SwiftData Models

**`Tally/Models/TaskType.swift`** — `String`-backed Codable enum: `check`, `count`, `timer`, `numeric`, `yesno`

**`Tally/Models/TallyTask.swift`** — `@Model`:
- `id: String`, `name: String`, `type: String` (TaskType raw value)
- `target: Double?`, `unit: String?`
- `days: [Int]` (0=Mon..6=Sun, empty=daily), `times: [String]` (HH:MM or "all-day")
- `notifPing: Bool`, `notifNag: Bool`, `notifSound: Bool` (flattened — SwiftData handles this cleanly)
- `archived: Bool`, `createdAt: Double` (unix ms)

**`Tally/Models/LogEntry.swift`** — `@Model`:
- `id: String`, `taskId: String` (indexed)
- `date: String` (YYYY-MM-DD, indexed), `time: String` (HH:MM)
- `value: Double` (booleans mapped: 1.0=true, 0.0=false; task type disambiguates)
- `ts: Double` (unix ms, for sort order)

**`Tally/Models/TallySettings.swift`** — `@Model` singleton:
- `dark: Bool`, `density: String`, `showIcons: Bool`
- `quietHoursEnabled: Bool`, `quietHoursStart: String`, `quietHoursEnd: String`
- `hasOnboarded: Bool`

### 1B: Pure Logic (Selectors)

Port from `prototype/tally/tally-state.jsx` lines 193-321. All free functions, no side effects.

| File | Function | Source reference |
|------|----------|----------------|
| `Logic/DateHelpers.swift` | `localDateKey()`, `localTimeKey()`, `dayOfWeek()`, `startOfDay()`, `addDays()`, `parseHHMM()` | tally-state.jsx:6-25 |
| `Logic/TaskState.swift` | `taskStateFor(task:date:entries:now:) -> TaskStatus` | tally-state.jsx:193-245 |
| `Logic/DayCompletion.swift` | `dayCompletionFor(date:tasks:entries:now:) -> DayCompletion` | tally-state.jsx:248-257 |
| `Logic/Streak.swift` | `streakFor(tasks:entries:now:) -> StreakResult` | tally-state.jsx:261-281 |
| `Logic/TaskHistory.swift` | `taskHistoryFor(task:entries:now:days:) -> [Double]` | tally-state.jsx:284-291 |
| `Logic/TimeBlocks.swift` | `groupByTimeBlock(tasks:date:)`, `describeSchedule()`, `pickPresets()` | tally-state.jsx:294-335 |

### 1C: Tests

- `TallyTests/TaskStateTests.swift` — each of 5 task types in done/partial/overdue/due/off states
- `TallyTests/DayCompletionTests.swift` — 100%, partial, 0%, no-tasks-scheduled
- `TallyTests/StreakTests.swift` — consecutive days, broken chain, today inclusion/exclusion
- `TallyTests/DateHelperTests.swift` — dayOfWeek mapping, dateKey format, DST boundary

### Verification
- `cmd+U` passes all logic tests
- App still builds and launches (shell only)

---

## Phase 2: Design System + Reusable Components

**Goal:** Port the visual language so screens can compose from tested atoms.

### Design Tokens

**`Design/TallyColors.swift`** — light/dark palette from tally-ui.jsx:6-37:
- bg/bg2/bg3/bg4, text/dim/dim2/dim3, rule, accent/accentSoft, pos, neg, warn

**`Design/TallyTypography.swift`** — IBM Plex Sans + Mono fonts bundled as `.otf`:
- `.tallyHeading(_:)`, `.tallyMono(_:)`, `.tallyBody(_:)`, `.tallyLabel` modifiers

### Components (in `Views/Components/`)

| Component | What it does |
|-----------|-------------|
| `StatusPip` | Colored circle by task status |
| `SparklineView` | 14-day mini line chart via `Path` |
| `ProgressBarView` | Horizontal progress bar |
| `CircularRingView` | Ring progress via `Circle().trim()` |
| `SegmentedDayBar` | Row of task-status colored tiles |
| `PresetChipGrid` | Grid of +N buttons for count/timer |
| `TallyCard` | Rounded card container |
| `StatTile` | Label + large mono value |
| `TaskRow` | Reusable row: pip + name + time + sparkline + % |

### Verification
- Xcode Previews render all components in light and dark mode with mock data

---

## Phase 3: Today Screen (Critical Path)

**Goal:** The primary surface. Validates data + logic + design + navigation end-to-end.

### Files

**`Views/Today/TodayScreen.swift`**:
- Header: date kicker, "Today" title, streak badge
- Day completion card: large %, SegmentedDayBar, count summary
- Time-block sections (Morning/Afternoon/Evening/All Day) with TaskRow lists
- Empty state with "Add task" CTA
- 60-second timer for overdue refresh
- `@Query` for tasks and entries, selectors computed inline

**`Views/Today/TaskDetailView.swift`**:
- Type-specific hero (progress for count/timer, status for check, reading for numeric, answer for yesno)
- Log controls: PresetChipGrid for count/timer, Mark Complete for check, Yes/No for yesno, numeric input for numeric
- Today's entries — tap to undo (delete LogEntry)
- 14-day mini trend + "View full stats" link

**`Services/SeedData.swift`** (`#if DEBUG`):
- Port `SEED_TASKS` + `buildSeedLog()` from tally-state.jsx:35-114
- 8 tasks, 30 days of history with intentional misses at offsets 16, 22, 9

### Verification
1. App launches, Today screen renders seed data with time-block sections
2. Tap count task → detail opens, tap +5 chip → value increments, entry appears
3. Tap entry to undo → value decrements
4. Complete all tasks → 100% day, segmented bar fully green

---

## Phase 4: Tasks Library + Add/Edit Form

**`Views/Tasks/TasksScreen.swift`** — ranked by 14-day rate, sort toggle, sparklines, tap → stats

**`Views/Tasks/TaskStatsView.swift`** — 30-day bar chart, type-specific stat tiles, hourly heatmap, recent entries

**`Views/Tasks/TaskFormView.swift`** — add/edit form: name, type radio, target/unit, day picker with presets (Daily/Weekdays/MWF/Weekends), times list with DatePicker, delete with confirmation

### Verification
- Create a new task → appears on Today in correct time block
- Edit task schedule → Today updates
- Delete task → task and entries removed

---

## Phase 5: Streak Screen + Day Detail

**`Views/Streak/StreakScreen.swift`** — hero card (streak + 30-day strip), stat tiles, paginated month calendar

**`Views/Streak/DayDetailView.swift`** — earned/missed/rest status, task list, full log

**`Views/Streak/MonthCalendarView.swift`** — reusable month grid, days color-coded, tap past day → detail

### Verification
- Streak count matches seed data (breaks at offset 16)
- Calendar colors match: earned/partial/missed/future
- Tap past day → correct task breakdown

---

## Phase 6: More Tab + Settings + Onboarding

**`Views/More/MoreScreen.swift`** — profile, appearance (dark/density/icons), links

**`Views/More/RemindersView.swift`** — quiet hours + per-task PING/NAG/SOUND chips

**`Views/More/ManageTasksView.swift`** — all tasks with Edit/Archive/Delete

**`Views/More/OnboardingView.swift`** — first-run: "One rule. 100% the day.", live 30-day strip, feature list, "Start tallying" CTA

### Verification
- Dark mode toggle works app-wide
- Archive/restore cycle works
- Onboarding shows on first launch, dismisses permanently

---

## Phase 7: Notifications + Midnight Rollover

**`Services/NotificationScheduler.swift`** — schedule `UNCalendarNotificationTrigger` per task time/day, optional +15min nag, respect quiet hours, reschedule on task save

**`Services/MidnightObserver.swift`** — detect day change via timer + `significantTimeChangeNotification`, refresh views

### Verification
- Notification fires at scheduled time
- Day rolls over while app is open → Today screen refreshes

---

## Phase 8: iCloud Sync

- Update `ModelConfiguration` with `cloudKitDatabase: .automatic`
- Add CloudKit capability in Signing & Capabilities
- Audit models: all properties need defaults for CloudKit compatibility

### Verification
- Two-device sync of tasks and log entries

---

## Phase 9: Widgets

New target: `TallyWidgets` (WidgetKit extension)

- **Lock screen:** streak number + day %
- **Home screen medium:** today's task checklist
- Shared data via App Group (`group.com.omarvelous.tally`)
- Reload timelines after every log entry insert/delete

---

## Phase 10: Siri Shortcuts

**`Intents/LogTaskIntent.swift`** — AppIntent: "Log 20 pushups"
**`Intents/TallyShortcuts.swift`** — AppShortcutsProvider with phrase templates

---

## Project Structure (after Phase 0)

```
tally/                              # repo root
  spec.md                           # source of truth (copied from _tally)
  CLAUDE.md                         # project conventions
  prototype/                        # reference (copied from _tally)
    tally.html, tally/*.jsx
  Tally/                            # main app target
    TallyApp.swift
    ContentView.swift               # TabView shell
    Assets.xcassets/
    Models/     TallyTask, LogEntry, TallySettings, TaskType
    Logic/      TaskState, DayCompletion, Streak, TaskHistory, TimeBlocks, DateHelpers
    Design/     TallyColors, TallyTypography
    Views/
      Components/  StatusPip, SparklineView, ProgressBarView, CircularRingView,
                   SegmentedDayBar, PresetChipGrid, TallyCard, StatTile, TaskRow
      Today/       TodayScreen, TaskDetailView
      Tasks/       TasksScreen, TaskStatsView, TaskFormView
      Streak/      StreakScreen, DayDetailView, MonthCalendarView
      More/        MoreScreen, RemindersView, ManageTasksView, OnboardingView
    Services/   SeedData, NotificationScheduler, MidnightObserver
    Intents/    LogTaskIntent, TallyShortcuts
  TallyTests/                       # unit tests
  TallyUITests/                     # UI tests
  Tally.xcodeproj/                  # Xcode project (committed)
```

## Key Source Files to Port From

- [tally-state.jsx](prototype/tally/tally-state.jsx) — all selector logic + seed data
- [tally-today.jsx](prototype/tally/tally-today.jsx) — Today screen + TaskDetail + log controls
- [tally-ui.jsx](prototype/tally/tally-ui.jsx) — color palette, typography, components
- [tally-tasks.jsx](prototype/tally/tally-tasks.jsx) — task form + stats
- [tally-streak.jsx](prototype/tally/tally-streak.jsx) — streak screen + calendar
- [tally-more.jsx](prototype/tally/tally-more.jsx) — settings, reminders, manage, onboarding

## Verification Summary

| Phase | Key Check |
|-------|-----------|
| 0 | App builds, 4 tabs render, git clean |
| 1 | All logic tests pass (`cmd+U`) |
| 2 | All components render in Previews (light + dark) |
| 3 | Full log→undo→complete cycle works on Today screen |
| 4 | Create/edit/delete task lifecycle works |
| 5 | Streak count correct, calendar colors match, day detail accurate |
| 6 | Dark mode, archive/restore, onboarding all functional |
| 7 | Notifications fire, midnight rollover refreshes views |
| 8 | Two-device iCloud sync |
| 9 | Widgets show correct data, refresh after logging |
| 10 | "Hey Siri, log 20 pushups" creates correct entry |
