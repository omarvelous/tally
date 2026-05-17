# Architecture

## Design Principles

1. **Log entries are the source of truth.** All derived state (streaks, completion %, task status) is computed from `LogEntry` records. There is no denormalized cache.
2. **Selectors are pure functions.** The `Logic/` layer takes data in, returns computed state out. No side effects, no model mutations, no environment access.
3. **Models are dumb containers.** `@Model` classes hold data and nothing else — no computed properties, no business logic methods.
4. **Views compose selectors.** SwiftUI views call selector functions directly with queried data. No intermediate view model layer.

## Data Flow

```
SwiftData Query → [LogEntry], [TallyTask]
       ↓
Pure Selectors (TaskState, DayCompletion, Streak)
       ↓
Computed State (TaskStatus, DaySnapshot, StreakResult)
       ↓
SwiftUI View
```

## Models

### TallyTask

The task definition — what to do, when, and how much.

| Field | Type | Purpose |
|-------|------|---------|
| `id` | String | UUID |
| `name` | String | Display name |
| `type` | TaskType | check, count, timer, numeric, yesno |
| `target` | Double? | Goal value (count/timer) |
| `unit` | String? | Display unit ("reps", "oz", "min") |
| `days` | [Int] | Scheduled days (0=Mon..6=Sun, empty=daily) |
| `times` | [String] | Scheduled times ("HH:MM" or "all-day") |
| `archived` | Bool | Hidden from daily view |
| `updatedAt` | Double | Unix ms, for conflict visibility |

### LogEntry

An immutable event record — one per logging action.

| Field | Type | Purpose |
|-------|------|---------|
| `id` | String | UUID |
| `taskId` | String | FK to TallyTask |
| `date` | String | "YYYY-MM-DD" (local) |
| `time` | String | "HH:MM" (local) |
| `value` | Double | 1.0/0.0 for booleans, numeric for others |
| `ts` | Double | Unix ms, for sort order |
| `tz` | String | Timezone at time of logging |
| `deleted` | Bool | Soft delete flag |

### TallySettings

Singleton app preferences (onboarding state, profile).

## Logic Layer

All files in `Logic/` export pure functions:

| File | Function | Purpose |
|------|----------|---------|
| `TaskState.swift` | `taskStateFor(task:date:entries:now:)` | Single task status for a given day |
| `DayCompletion.swift` | `dayCompletionFor(date:tasks:entries:now:)` | Aggregate day stats (done/partial/overdue/total) |
| `Streak.swift` | `streakFor(tasks:entries:now:)` | Current streak, best streak, 60-day history |
| `TaskHistory.swift` | `taskHistoryFor(task:entries:now:days:)` | Per-task sparkline data |
| `TaskMutations.swift` | `deleteTaskAndEntries(taskId:context:)` | Cascade delete (the one place mutations are centralized) |

## Views

Organized by screen, not by component type:

```
Views/
├── Today/        Daily dashboard + LogSheet
├── Tasks/        Task list, form, stats
├── Streak/       Streak hero, calendar, day detail
├── More/         Settings, onboarding, reminders
└── Components/   Shared UI primitives
```

## Services

| File | Purpose |
|------|---------|
| `ModelContainerFactory.swift` | Shared container config for app, widget, and intent targets |
| `NotificationScheduler.swift` | Schedules/cancels per-task local notifications |
| `MidnightObserver.swift` | Detects day flip for live UI refresh |
| `SeedData.swift` | Demo tasks for onboarding |

## Schema & Migrations

`TallySchema.swift` declares `TallySchemaV1` using SwiftData's `VersionedSchema` protocol. The `TallyMigrationPlan` is wired into the shared model container. Future schema changes add a V2 with a migration stage.

## Widget Architecture

Both widgets (`StreakWidget`, `TodayChecklistWidget`) use the shared `ModelContainerFactory` to read from the same SwiftData store. Timelines refresh at midnight. The widgets are read-only — all logging happens in the main app or via App Intents.

## Sync

CloudKit sync is handled transparently by SwiftData's `.cloudKitDatabase(.automatic)` configuration. The app is single-user, so last-write-wins conflict resolution is adequate. The `updatedAt` field provides visibility into when records were last modified.
