# Tally — Relational Data Model & PaaS Migration

## Context

Tally's current SwiftData model embeds schedule configuration directly in the task, has no temporal versioning, and computes all derived state (streaks, completion, history) at read time from raw data. This causes retroactive corruption — adding or editing a task rewrites history. The app needs a proper relational model designed from the app's purpose, backed by a PaaS, with offline-first sync. The UI/UX stays the same; only the data layer changes.

---

## PaaS Evaluation

### Supabase (Recommended)

| Dimension | Rating | Notes |
|-----------|--------|-------|
| Relational fit | ★★★★★ | Postgres underneath — true SQL, joins, constraints, indexes, triggers |
| Swift SDK | ★★★★☆ | `supabase-swift` actively maintained, covers auth + DB + real-time + storage |
| Auth | ★★★★★ | Email/password, Apple Sign-In, Google, magic links, MFA |
| Real-time | ★★★★☆ | Postgres LISTEN/NOTIFY via websockets; subscribe to table changes |
| Offline-first | ★★★☆☆ | No built-in offline sync — requires local DB + manual sync layer (SwiftData stays as local cache) |
| Edge Functions | ★★★★☆ | Deno-based; can run cron jobs (e.g., generate habit_days at midnight) |
| Row-Level Security | ★★★★★ | Policy-based per-user data isolation at the DB level |
| Pricing | ★★★★★ | Free: 500MB DB, 50K MAU, 1GB storage. Pro: $25/mo |
| Open source | ✅ | Self-hostable if needed |

### Firebase

| Dimension | Rating | Notes |
|-----------|--------|-------|
| Relational fit | ★★☆☆☆ | Firestore is NoSQL/document — no joins, denormalization required. Recreates the exact problems we're solving |
| Swift SDK | ★★★★★ | Most mature mobile SDK in the industry |
| Auth | ★★★★★ | Best-in-class mobile auth |
| Real-time | ★★★★★ | Built into the SDK, automatic |
| Offline-first | ★★★★★ | Built-in local persistence + automatic conflict resolution |
| Cloud Functions | ★★★★☆ | Node.js, well-documented |
| Security Rules | ★★★★☆ | Document-path-based, less expressive than SQL RLS |
| Pricing | ★★★★☆ | Generous free tier but read/write ops pricing can spike |

**Disqualified:** NoSQL forces denormalization. Computing "what was due on May 3rd" across documents without joins leads back to the same retroactive-corruption patterns. Wrong tool for relational data.

### Appwrite

| Dimension | Rating | Notes |
|-----------|--------|-------|
| Relational fit | ★★★☆☆ | MariaDB underneath but exposed as document collections — no raw SQL, limited query operators |
| Swift SDK | ★★★☆☆ | Exists but less mature, smaller community |
| Auth | ★★★★☆ | Good coverage, similar to Supabase |
| Real-time | ★★★☆☆ | Exists but less robust than Supabase/Firebase |
| Offline-first | ★★☆☆☆ | No built-in offline support |
| Functions | ★★★☆☆ | Multiple runtimes, but less ecosystem |
| Pricing | ★★★★★ | Generous free tier, open source |

**Not recommended:** Middle ground that doesn't excel at relational modeling or offline-first. Less ecosystem support.

### Verdict: Supabase

Supabase gives us real Postgres — the model we design *is* the schema. RLS handles multi-user isolation. Edge Functions handle server-side jobs. The offline-first gap is solved by keeping SwiftData as the local store and syncing to Supabase.

---

## Relational Data Model

Designed from the app's purpose: **a daily habit tracker where history is immutable, habits are shared across users for social features, and new/edited habits never corrupt past data.**

### Core Design Decision: Shared Habits

Habits are **global entities** — "Drink Water", "Meditate", "Exercise" exist once in the system and are shared across all users. A **join table** (`user_habits`) connects users to habits they've adopted, storing their personalized target and schedule. This enables:

- **Leaderboards** — compare activity on the same habit across users
- **Social proof** — "12,847 people also track this habit"
- **Aggregate insights** — "users who drink water also tend to meditate"

Users can modify their **target** (how much) and **schedule** (which days/times), but **not the unit** — if "Drink Water" is measured in oz, everyone measures in oz. This keeps cross-user comparisons meaningful.

**Custom habits are v2.** For launch, users pick from predefined habits only.

### Entity Relationship Diagram

```
┌──────────────┐
│   profiles   │
│──────────────│
│ id (PK/FK)   │──── Supabase Auth user
│ display_name │
│ initials     │
│ timezone     │
│ created_at   │
└──────┬───────┘
       │ 1
       │
       │ ∞
┌──────┴───────────┐       ┌──────────────────┐
│   user_habits    │       │  user_habit_     │
│──────────────────│       │  schedules       │
│ id (PK)          │◄─ 1:∞─│──────────────────│
│ profile_id (FK)  │       │ id (PK)          │
│ habit_id (FK) ───┼──┐    │ user_habit_id FK │
│ sort_order       │  │    │ target           │
│ archived_at      │  │    │ days     int[]   │
│ created_at       │  │    │ times    text[]  │
│ updated_at       │  │    │ effective_from   │
└──────┬───────────┘  │    │ effective_to     │
       │              │    │ created_at       │
       │ 1            │    └──────────────────┘
       │              │
       │ ∞            │ ∞
┌──────┴───────┐      │    ┌──────────────────┐
│  habit_days  │──1:∞─┼───>│   log_entries    │
│──────────────│      │    │──────────────────│
│ id (PK)      │      │    │ id (PK)          │
│ user_habit_id│      │    │ habit_day_id (FK)│
│ schedule_id  │      │    │ value            │
│ date         │      │    │ logged_at  ts    │
│ target_snap  │      │    │ timezone         │
│ unit_snap    │      │    │ deleted_at       │
│ status       │      │    │ created_at       │
│ pct          │      │    └──────────────────┘
│ sum          │      │
│ created_at   │      │
└──────────────┘      │
                      │
               ┌──────┴───────┐
               │    habits    │ ◄── GLOBAL, shared across all users
               │──────────────│
               │ id (PK)      │
               │ category_id  │──> categories
               │ name         │
               │ description  │
               │ type         │     check, count, timer, numeric, yesno
               │ unit         │     locked — users cannot change
               │ default_target│    suggested starting target
               │ default_days │     suggested schedule
               │ default_times│     suggested times
               │ is_popular   │
               │ sort_order   │
               │ created_at   │
               └──────────────┘

┌──────────────┐       ┌──────────────────┐
│day_summaries │       │   preferences    │
│──────────────│       │──────────────────│
│ id (PK)      │       │ id (PK)          │
│ profile_id   │       │ profile_id (FK)  │
│ date         │       │ theme            │
│ total        │       │ density          │
│ done         │       │ quiet_start      │
│ partial      │       │ quiet_end        │
│ overdue      │       │ notif_enabled    │
│ pct          │       │ updated_at       │
│ streak_day   │       └──────────────────┘
│ created_at   │
│ updated_at   │
└──────────────┘

┌───────────────────┐
│   categories      │
│───────────────────│
│ id (PK)           │
│ name              │    "Health & Fitness", "Productivity", etc.
│ sort_order        │
└───────────────────┘
```

### Table Definitions

#### `profiles`
Extends Supabase Auth. One row per user.

| Column | Type | Notes |
|--------|------|-------|
| id | uuid PK | References `auth.users.id` |
| display_name | text | |
| initials | text | Empty = auto-derived from name |
| timezone | text | IANA timezone (e.g., "America/New_York") |
| created_at | timestamptz | |

#### `habits` (GLOBAL — shared across all users)
The canonical habit catalog. Server-managed. No `profile_id`. Think of these as the "things humans track" — they exist independent of any user.

| Column | Type | Notes |
|--------|------|-------|
| id | uuid PK | Stable identity — never changes |
| category_id | uuid FK | → categories.id |
| name | text NOT NULL | "Drink Water", "Meditate", "Exercise" |
| description | text | Short explanation shown during onboarding |
| type | text NOT NULL | check, count, timer, numeric, yesno — immutable |
| unit | text | "oz", "min", "reps" — immutable, locked for all users |
| default_target | numeric | Suggested starting target (user can override) |
| default_days | int[] | Suggested schedule, e.g., {0,1,2,3,4,5,6} for daily |
| default_times | text[] | {"all-day"} or {"08:00"} |
| is_popular | boolean DEFAULT false | Featured in onboarding / browse |
| sort_order | int | Display order within category |
| created_at | timestamptz | |

**Design notes:**
- `type` and `unit` are immutable. Every user tracking "Drink Water" uses the same unit (oz). This is what makes leaderboards and comparison meaningful.
- `default_target`, `default_days`, `default_times` are suggestions — copied into `user_habit_schedules` when a user adopts the habit, then independently editable.
- Admins add/edit habits via Supabase dashboard. No app deploy required.
- **Custom habits (user-created) are v2.** When added, a `created_by` column + RLS policy will scope visibility (creator-only unless promoted to global).

#### `categories`
Server-managed groupings for browsing habits.

| Column | Type | Notes |
|--------|------|-------|
| id | uuid PK | |
| name | text NOT NULL | "Health & Fitness", "Productivity", etc. |
| sort_order | int | Display order |

#### `user_habits` (JOIN TABLE — user ↔ habit)
One row per user per adopted habit. This is the user's "my habits" list.

| Column | Type | Notes |
|--------|------|-------|
| id | uuid PK | |
| profile_id | uuid FK | → profiles.id |
| habit_id | uuid FK | → habits.id |
| sort_order | int | User-defined ordering in their list |
| archived_at | timestamptz | NULL = active |
| created_at | timestamptz | When user adopted the habit |
| updated_at | timestamptz | |

**UNIQUE constraint:** `(profile_id, habit_id)` — a user can only adopt a habit once.

**Design notes:**
- Adopting a habit = INSERT into `user_habits` + INSERT into `user_habit_schedules` (seeded from habit defaults).
- Archiving = set `archived_at`. Data preserved, habit hidden from daily view.
- This table is what makes social features possible: `SELECT COUNT(*) FROM user_habits WHERE habit_id = $1` = "how many people track this."

#### `user_habit_schedules`
Temporal versioning of a user's configuration for an adopted habit. New row on every edit.

| Column | Type | Notes |
|--------|------|-------|
| id | uuid PK | |
| user_habit_id | uuid FK | → user_habits.id |
| target | numeric | User's personal target. NULL for check/yesno |
| days | int[] | {0,1,2,3,4,5,6} = daily; {0,2,4} = MWF. Empty = daily |
| times | text[] | {"all-day"} or {"08:00","12:00"} |
| effective_from | date NOT NULL | Inclusive start |
| effective_to | date | NULL = currently active |
| created_at | timestamptz | |

**No `unit` column** — unit is inherited from `habits.unit` and cannot be overridden.

**Key behavior:**
- Adopting a habit inserts a schedule with `target = habits.default_target`, `days = habits.default_days`, `times = habits.default_times`, `effective_from = today`, `effective_to = NULL`
- Editing target/days/times: set `effective_to = today` on current, insert new with `effective_from = today`
- To find "what was my schedule on May 3rd?": `WHERE effective_from <= '2024-05-03' AND (effective_to IS NULL OR effective_to > '2024-05-03')`

#### `habit_days`
Materialized occurrence — one row per user-habit per active day. THE source of truth for "was this habit due for this user on date X?"

| Column | Type | Notes |
|--------|------|-------|
| id | uuid PK | |
| user_habit_id | uuid FK | → user_habits.id |
| schedule_id | uuid FK | → user_habit_schedules.id (which schedule generated this) |
| date | date NOT NULL | |
| target_snap | numeric | Snapshot of target at generation time |
| unit_snap | text | Snapshot of unit at generation time (from habits.unit) |
| status | text NOT NULL | pending, partial, done, skipped |
| pct | numeric DEFAULT 0 | 0.0–1.0+ |
| sum | numeric | For count/timer: running total of log_entries |
| created_at | timestamptz | |

**UNIQUE constraint:** `(user_habit_id, date)` — one occurrence per user-habit per day.

**Key behavior:**
- Generated by an Edge Function cron at midnight (user's timezone) or on-demand when the app opens
- Only generated for days where the active schedule includes that day-of-week
- Once created, `target_snap` and `unit_snap` are frozen — editing the schedule doesn't change past habit_days
- `unit_snap` is always copied from `habits.unit` (not user-editable)
- `status` and `pct` updated when log_entries are inserted
- A habit adopted on May 17 simply has no `habit_days` rows before May 17

**This single table eliminates the retroactive corruption problem entirely.**

#### `log_entries`
Immutable event log. What the user actually did.

| Column | Type | Notes |
|--------|------|-------|
| id | uuid PK | |
| habit_day_id | uuid FK | → habit_days.id |
| value | numeric NOT NULL | 1.0 for check/yesno, amount for count/timer/numeric |
| logged_at | timestamptz | When the user tapped "log" |
| timezone | text | User's timezone at log time |
| deleted_at | timestamptz | Soft delete |
| created_at | timestamptz | |

**Design note:** References `habit_day_id` (not `user_habit_id` + `date`). This guarantees every log entry is tied to a specific materialized occurrence. You can't log against a day that doesn't exist.

#### `day_summaries`
Cached daily rollup. Avoids recomputing from raw data on every render.

| Column | Type | Notes |
|--------|------|-------|
| id | uuid PK | |
| profile_id | uuid FK | → profiles.id |
| date | date NOT NULL | |
| total | int | Count of habit_days for this user+date |
| done | int | habit_days where status = 'done' |
| partial | int | habit_days where status = 'partial' |
| overdue | int | habit_days where status = 'overdue' |
| pct | numeric | done / total (0 if total = 0) |
| streak_day | boolean | pct >= 1.0 AND total > 0 |
| created_at | timestamptz | |
| updated_at | timestamptz | |

**UNIQUE constraint:** `(profile_id, date)`

**Updated via:** Postgres trigger on `habit_days` status changes, or recomputed by Edge Function.

#### `preferences`
Per-user settings. Singleton per profile.

| Column | Type | Notes |
|--------|------|-------|
| id | uuid PK | |
| profile_id | uuid FK UNIQUE | → profiles.id |
| theme | text DEFAULT 'system' | system, light, dark |
| density | text DEFAULT 'regular' | regular, compact |
| quiet_start | time | Notification quiet hours start |
| quiet_end | time | Notification quiet hours end |
| notif_enabled | boolean DEFAULT true | |
| updated_at | timestamptz | |

### How Key Operations Work

**Adopting a habit (onboarding / browse):**
1. User picks "Drink Water" from the catalog
2. INSERT into `user_habits` → `profile_id`, `habit_id`
3. INSERT into `user_habit_schedules` → seeded from `habits.default_target`, `habits.default_days`, `habits.default_times`, `effective_from = today`
4. INSERT into `habit_days` → row for today (if scheduled today)
5. No other users affected. No past days touched.

**Editing a habit's schedule (target or days/times):**
1. UPDATE current `user_habit_schedules` → set `effective_to = today`
2. INSERT new `user_habit_schedules` → `effective_from = today`, new target/days/times
3. Future `habit_days` generated from new schedule
4. Past `habit_days` are frozen with their `target_snap`/`unit_snap`. History is immutable.
5. Unit cannot be changed — inherited from `habits.unit`.

**Logging a completion:**
1. INSERT into `log_entries` → value, linked to habit_day_id
2. UPDATE `habit_days` → recompute status, pct, sum from its log_entries
3. UPDATE `day_summaries` → recompute from habit_days for that date
4. Widget reload triggered

**Computing streak:**
```sql
SELECT date, streak_day FROM day_summaries
WHERE profile_id = $1
ORDER BY date DESC LIMIT 61;
```
Walk backward from today — count consecutive `streak_day = true`, skip `total = 0` days (neutral).

**Sparkline (14-day task history):**
```sql
SELECT date, pct FROM habit_days
WHERE user_habit_id = $1 AND date >= current_date - 13
ORDER BY date;
```
No computation needed — the answer is already materialized.

**Leaderboard (top users for a habit, last 7 days):**
```sql
SELECT p.display_name, p.initials,
       COUNT(*) FILTER (WHERE hd.status = 'done') AS days_done,
       AVG(hd.pct) AS avg_pct
FROM habit_days hd
JOIN user_habits uh ON uh.id = hd.user_habit_id
JOIN profiles p ON p.id = uh.profile_id
WHERE uh.habit_id = $1
  AND hd.date >= current_date - 6
GROUP BY p.id, p.display_name, p.initials
ORDER BY days_done DESC, avg_pct DESC
LIMIT 20;
```

**How many people track this habit?**
```sql
SELECT COUNT(*) FROM user_habits
WHERE habit_id = $1 AND archived_at IS NULL;
```

---

## Offline-First Architecture

```
┌─────────────────────────────────────────────┐
│                  iOS App                      │
│                                               │
│  ┌─────────────┐    ┌──────────────────────┐ │
│  │  SwiftUI     │◄──│  Local SwiftData      │ │
│  │  Views       │   │  (mirrors Supabase    │ │
│  │              │   │   schema)             │ │
│  └─────────────┘   └──────────┬─────────────┘ │
│                               │               │
│                     ┌─────────┴─────────┐     │
│                     │   Sync Engine      │     │
│                     │  (write local,     │     │
│                     │   push to cloud,   │     │
│                     │   pull changes)    │     │
│                     └─────────┬─────────┘     │
└───────────────────────────────┼───────────────┘
                                │
                    ┌───────────┴───────────┐
                    │    Supabase Cloud      │
                    │  ┌─────────────────┐  │
                    │  │   Postgres DB    │  │
                    │  │   (source of     │  │
                    │  │    truth)        │  │
                    │  └─────────────────┘  │
                    │  ┌─────────────────┐  │
                    │  │  Edge Functions  │  │
                    │  │  (cron: generate │  │
                    │  │   habit_days)    │  │
                    │  └─────────────────┘  │
                    │  ┌─────────────────┐  │
                    │  │  Auth            │  │
                    │  └─────────────────┘  │
                    │  ┌─────────────────┐  │
                    │  │  Real-time       │  │
                    │  │  (multi-device)  │  │
                    │  └─────────────────┘  │
                    └───────────────────────┘
```

**Write path:** Write to local SwiftData → UI updates immediately → Sync engine pushes to Supabase in background
**Read path:** Always read from local SwiftData (instant, works offline)
**Sync:** On app open + on connectivity change + periodic background sync
**Conflict resolution:** Last-write-wins with `updated_at` timestamps (habit tracker data is rarely conflicting)

The local SwiftData models mirror the Supabase schema. The Sync Engine handles:
- Pending writes queue (persisted, survives app kill)
- Pull remote changes since last sync timestamp
- Reconcile conflicts

---

## What Changes vs. What Stays

| Layer | Changes? | Notes |
|-------|----------|-------|
| SwiftUI Views | Minimal | Same screens, same components. Data layer is abstracted |
| Logic/Selectors | Simplified | Most computation moves to materialized `habit_days` + `day_summaries`. Selectors become simple reads |
| Models | Replaced | SwiftData models mirror new Supabase schema |
| Services | New | Sync engine, Supabase client, auth flow |
| Widget | Simplified | Reads from local SwiftData (same App Group). No computation |
| Habit catalog | Server-managed | `habits` + `categories` tables in Supabase. Cached locally. Replaces JSON templates |

---

## Migration Path

1. **Phase 1:** Set up Supabase project, create schema (tables + RLS policies + Edge Functions)
2. **Phase 2:** Seed `habits` + `categories` tables with predefined habit catalog (from current `task_templates.json`)
3. **Phase 3:** Create new SwiftData models mirroring Supabase schema
4. **Phase 4:** Build Sync Engine (write-local-first, push/pull)
5. **Phase 5:** Add auth flow (Supabase Auth + Apple Sign-In)
6. **Phase 6:** Migrate existing local data to new schema (map current tasks → `user_habits` pointing to matching global habits)
7. **Phase 7:** Update Views to use new models (same UI, new data source)
8. **Phase 8:** Widget reads from new local schema

### V2: Custom Habits
When users can create their own habits:
- Add `created_by uuid FK → profiles.id` to `habits` (NULL = system-defined)
- RLS: system habits visible to all; user-created habits visible only to creator
- Custom habits won't appear in leaderboards unless promoted to global by admin
