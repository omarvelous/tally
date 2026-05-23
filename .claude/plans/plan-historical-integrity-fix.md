# Fix Historical Integrity — Tasks Must Not Retroactively Affect Past Days

## Context

Adding a new task breaks all previous streaks. If a user has a 14-day streak and adds a new daily task, the streak drops to 0 because every past day now has an "incomplete" task that didn't exist yet. The root cause: none of the calculation functions filter by `task.createdAt`. The app treats every task as if it existed since the beginning of time.

## Current Entity Relationship Diagram

```
┌──────────────────────┐         ┌──────────────────────┐
│      TallyTask       │         │      LogEntry        │
│──────────────────────│         │──────────────────────│
│ id: String (PK)      │◄─ FK ── │ id: String (PK)      │
│ name: String         │         │ taskId: String (FK)  │
│ taskType: String     │         │ date: String         │
│ target: Double?      │         │ time: String         │
│ unit: String?        │         │ value: Double        │
│ days: [Int]          │         │ ts: Double           │
│ times: [String]      │         │ tz: String           │
│ notifPing: Bool      │         │ deleted: Bool        │
│ notifNag: Bool       │         └──────────────────────┘
│ notifSound: Bool     │
│ archived: Bool       │         ┌──────────────────────┐
│ createdAt: Double    │         │   TallySettings      │
│ updatedAt: Double    │         │──────────────────────│
└──────────────────────┘         │ dark: Bool           │
                                 │ density: String      │
  FK = LogEntry.taskId           │ showIcons: Bool      │
       references                │ quietHours*: ...     │
       TallyTask.id              │ hasOnboarded: Bool   │
  (string match, no              │ name/email/initials  │
   @Relationship)                └──────────────────────┘
```

**Key problems with current model:**
1. `createdAt` exists on TallyTask but is **never used** in any calculation
2. No formal `@Relationship` — just string FK matching
3. No concept of "task was active on date X" beyond the `days` schedule array

## The Fix — No Schema Change Required

The good news: the current schema already has everything needed. `TallyTask.createdAt` (Unix milliseconds) is the "effective from" date. **No new models, no migration, no schema version bump.**

The fix is purely in the selector functions (Logic layer).

### Core Rule

> A task should only be counted in day completion, streaks, and history for dates **on or after** the start-of-day of its `createdAt` timestamp.

### Helper function — `Tally/Logic/DateHelpers.swift`

Add one new function:

```swift
/// True if the task existed (was created on or before) the given date.
func taskExistedOn(_ task: TallyTask, date: Date) -> Bool {
    let taskCreatedDay = startOfDay(Date(timeIntervalSince1970: task.createdAt / 1000))
    return startOfDay(date) >= taskCreatedDay
}
```

### Fix 1 — `dayCompletionFor()` in `Tally/Logic/DayCompletion.swift`

**Current (line 20):**
```swift
let scheduled = tasks.filter { !$0.archived && $0.isScheduled(on: dow) }
```

**Fixed:**
```swift
let scheduled = tasks.filter { !$0.archived && taskExistedOn($0, date: date) && $0.isScheduled(on: dow) }
```

This is the single most critical fix. Every consumer of `dayCompletionFor()` — streaks, calendar, day cards — immediately gets correct behavior.

### Fix 2 — `streakFor()` in `Tally/Logic/Streak.swift`

No direct change needed. It calls `dayCompletionFor()` which will now filter correctly. But we should also handle the edge case where `total == 0` for a historical day (no tasks existed yet):

**Current (line 48):**
```swift
if h.total > 0 && h.pct >= 1.0 {
```

This already skips days with 0 tasks — so a day before any tasks were created won't break the streak (it'll be `total: 0`, skipped). But it also won't *count* toward the streak. That's correct behavior: days with no tasks are neither earned nor breaking.

**However**, the current streak walk-back (line 46-52) will `break` on a `total == 0` day, treating it as a streak-breaker. We need to decide: should "no tasks existed" days be streak-neutral (skip over them) or streak-breaking?

**Recommendation: skip over them** — the streak should only break on days where the user had active tasks and didn't complete them.

**Fixed streak walk-back:**
```swift
// Current streak: walk back from yesterday, skip days with no tasks
for i in stride(from: history.count - 2, through: 0, by: -1) {
    let h = history[i]
    if h.total == 0 { continue }  // no tasks existed yet — neutral
    if h.pct >= 1.0 {
        current += 1
    } else {
        break
    }
}
```

Same pattern for best streak calculation.

### Fix 3 — `taskStateFor()` in `Tally/Logic/TaskState.swift`

Add an early return for dates before the task existed:

```swift
func taskStateFor(task: TallyTask, date: Date, entries: [LogEntry], now: Date) -> TaskStatus {
    // Task didn't exist on this date — not applicable
    if !taskExistedOn(task, date: date) {
        return TaskStatus(status: .off, pct: 0, sum: nil, label: "Not created", count: 0, value: nil)
    }
    // ... rest of existing logic unchanged
}
```

This fixes sparklines and individual task history views.

### Fix 4 — `taskHistoryFor()` in `Tally/Logic/TaskHistory.swift`

No change needed — it calls `taskStateFor()` which will now return `.off` for pre-creation dates. The sparkline will show 0% for those days, which is correct (the task didn't exist).

### Fix 5 — Widget timeline providers in `TallyWidgets/TallyWidgets.swift`

No change needed — they call `dayCompletionFor()` and `streakFor()` which are being fixed. The widget inherits correct behavior.

## Files to Modify

| File | Change |
|------|--------|
| `Tally/Logic/DateHelpers.swift` | Add `taskExistedOn(_:date:)` helper |
| `Tally/Logic/DayCompletion.swift` | Filter `scheduled` tasks by `taskExistedOn` |
| `Tally/Logic/TaskState.swift` | Early return `.off` for pre-creation dates |
| `Tally/Logic/Streak.swift` | Skip `total == 0` days in streak walk-back (don't break streak) |

**No new files. No schema change. No migration.**

## Test Cases

1. **Core case — new task doesn't break existing streak:**
   - Create task A on day 1, log it daily for 5 days (streak = 5)
   - Create task B on day 6
   - Streak should still be 5 (task B not counted for days 1-5)

2. **Day completion for historical date:**
   - Day 3 has 1 task (A), completed → 100%
   - Add task B on day 6
   - Day 3 should still show 100% (only task A counted)

3. **Sparkline for new task:**
   - Task created today → sparkline shows 0% for all 13 prior days (`.off`), only today is meaningful

4. **Streak with zero-task days:**
   - User creates first task on day 5
   - Days 1-4 have no tasks → streak walks through them (neutral, not breaking)
   - Day 5 completed → streak = 1

5. **Archived task:**
   - Archived tasks are already excluded by `!$0.archived` filter — no change needed

## Verification

1. `xcodebuild -scheme Tally -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`
2. `xcodebuild -scheme Tally -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test`
3. Manual: add a new task → verify streak count on TodayScreen doesn't change
4. Manual: check historical calendar dates → new task not reflected on past days
5. Manual: widget updates correctly without retroactive impact
