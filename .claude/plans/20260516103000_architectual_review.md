# Tally — Architectural Hardening Plan

## Context

The v2 UI is complete. Before TestFlight/shipping, the data architecture needs hardening across timezone safety, migration safety, container consistency, and mutation hygiene. These are "cheap now, expensive later" changes — small additions that prevent data-loss scenarios and costly rewrites.

Priority: **schema safety net > container unification > timezone capture > mutation cleanup**.

---

## Architectural Review Summary

### Critical (must fix before shipping)

1. **No VersionedSchema** — without snapshotting V1, you lose safe migration ability after users have data. ~15 min fix, impossible to retrofit.

2. **No timezone on LogEntry** — `date` is a local-time string ("YYYY-MM-DD") with no timezone qualifier. Timezone changes (travel, DST) silently corrupt streak calculations. Adding `tz: String` is a 5-min fix that prevents data loss.

3. **Widget/Intent container mismatch** — `LogTaskIntent` and widget providers create their own `ModelContainer` without `cloudKitDatabase: .automatic`. Entries logged via Siri may not sync. Widgets may read from a different store.

### Important (should fix before wider release)

4. **No updatedAt on TallyTask** — needed for sync debugging and future API compat. 2-min fix.

5. **Duplicate cascade delete** — same logic in `TaskFormView.deleteTask()` and `TaskStatsView.deleteTask()`. Will drift. Extract to shared function.

6. **No soft-delete on LogEntry** — swipe-to-delete is permanent. Accidental delete breaks streak with no recovery path. Adding `deleted: Bool` + filtering in selectors is the right fix.

### Acceptable for MVP (defer)

7. **@Query loads all entries** — every screen fetches the full LogEntry table. Fine for <10K entries (~6 months). Replace with parameterized FetchDescriptors when needed.

8. **TallySettings singleton + CloudKit** — two devices editing settings simultaneously lose one write. Acceptable for single-user MVP.

9. **No event sourcing** — LogEntry IS the event log. Task property edits have no audit trail, but this is fine for single-user.

10. **No SwiftData relationships** — string FKs are more CloudKit-safe and API-portable. Keep them.

---

## Phase 1: Schema Safety Net + Timezone Capture

**Goal:** Snapshot V1 schema. Capture timezone on entries. Add updatedAt to tasks.

### New: `Tally/Models/TallySchema.swift`
- `TallySchemaV1` — `VersionedSchema` with current model definitions
- `TallyMigrationPlan` — `SchemaMigrationPlan` with V1 as sole version

### Modify: `Tally/Models/LogEntry.swift`
Add: `var tz: String = TimeZone.current.identifier`

### Modify: `Tally/Models/TallyTask.swift`
Add: `var updatedAt: Double = Date().timeIntervalSince1970 * 1000`

### Modify: `Tally/TallyApp.swift`
Wire `TallyMigrationPlan` into `ModelContainer`.

### Verification
- Build passes, tests pass, new entries have `tz` populated

---

## Phase 2: Container Unification

**Goal:** Single ModelContainer config shared by app, widgets, intents.

### New: `Tally/Services/ModelContainerFactory.swift`
Static factory returning configured `ModelContainer` with CloudKit + migration plan. Added to all target memberships.

### Modify: `TallyApp.swift`, `LogTaskIntent.swift`, `TallyWidgets.swift`
Replace inline container creation with shared factory.

### Verification
- Siri-logged entries appear in the app and sync via CloudKit

---

## Phase 3: Mutation Hygiene

**Goal:** Consolidate cascade delete, set updatedAt on mutations.

### New: `Tally/Logic/TaskMutations.swift`
`deleteTaskAndEntries(taskId:context:)` — single cascade delete source of truth.

### Modify: `TaskFormView.swift`, `TaskStatsView.swift`
Replace inline delete with shared function. Set `task.updatedAt` on save/archive.

### Modify: `LogSheet.swift`
Explicitly set `tz` on LogEntry creation.

### Verification
- Cascade delete works from both screens using same codepath

---

## Phase 4: Soft Delete for LogEntry

**Goal:** Protect streak integrity from accidental deletes.

### Modify: `LogEntry.swift`
Add: `var deleted: Bool = false`

### Modify: All selectors (`TaskState.swift`, `DayCompletion.swift`, `Streak.swift`, `TaskHistory.swift`)
Filter `!$0.deleted` on entry lookups.

### Modify: `LogSheet.swift`
Set `entry.deleted = true` instead of `modelContext.delete(entry)`.

### Verification
- Deleted entries hidden from UI, streak unaffected, data preserved

---

## Files Summary

| Action | File | Phase |
|--------|------|-------|
| **New** | `Models/TallySchema.swift` | 1 |
| **New** | `Services/ModelContainerFactory.swift` | 2 |
| **New** | `Logic/TaskMutations.swift` | 3 |
| **Modify** | `Models/LogEntry.swift` | 1, 4 |
| **Modify** | `Models/TallyTask.swift` | 1 |
| **Modify** | `TallyApp.swift` | 1, 2 |
| **Modify** | `Intents/LogTaskIntent.swift` | 2 |
| **Modify** | `TallyWidgets/TallyWidgets.swift` | 2 |
| **Modify** | `Views/Tasks/TaskFormView.swift` | 3 |
| **Modify** | `Views/Tasks/TaskStatsView.swift` | 3 |
| **Modify** | `Views/Today/LogSheet.swift` | 3, 4 |
| **Modify** | `Logic/TaskState.swift` | 4 |
| **Modify** | `Logic/DayCompletion.swift` | 4 |
| **Modify** | `Logic/Streak.swift` | 4 |
| **Modify** | `Logic/TaskHistory.swift` | 4 |

## What We're NOT Doing (and why)

| Deferred | Reason |
|----------|--------|
| Event sourcing | LogEntry IS the event log for what matters |
| App-level conflict resolution | CloudKit LWW adequate; entries are append-only |
| Device identity | No multi-device debugging use case yet |
| Denormalized streak cache | Performance fine at <10K entries |
| SwiftData relationships | CloudKit schema complications, string FKs more portable |
| Full query optimization | Defer until entry count >5K justifies it |
