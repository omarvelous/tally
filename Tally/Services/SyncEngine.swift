//
//  SyncEngine.swift
//  Tally
//
//  Offline-first sync between local SwiftData and Supabase.
//  Write path: write to local SwiftData → push to Supabase in background.
//  Read path: always read from local SwiftData.
//  Sync: on app open + on auth state change + on-demand.

import Foundation
import SwiftData
import Supabase

@Observable
final class SyncEngine {
    var isSyncing = false
    var lastSyncedAt: Date?
    var syncError: String?

    private let client = SupabaseManager.client

    // MARK: - Pull: Supabase → Local

    /// Full pull of habits catalog (categories + habits). Called on app open.
    @MainActor
    func pullCatalog(context: ModelContext) async {
        do {
            // Pull categories
            let remoteCats: [RemoteCategory] = try await client
                .from("categories")
                .select()
                .execute()
                .value

            for rc in remoteCats {
                let rcId = rc.id
                let descriptor = FetchDescriptor<Category>(predicate: #Predicate { $0.id == rcId })
                let existing = (try? context.fetch(descriptor))?.first
                if let existing {
                    existing.name = rc.name
                    existing.sortOrder = rc.sort_order
                } else {
                    context.insert(Category(
                        id: rc.id,
                        name: rc.name,
                        sortOrder: rc.sort_order
                    ))
                }
            }

            // Pull habits
            let remoteHabits: [RemoteHabit] = try await client
                .from("habits")
                .select()
                .execute()
                .value

            for rh in remoteHabits {
                let rhId = rh.id
                let descriptor = FetchDescriptor<Habit>(predicate: #Predicate { $0.id == rhId })
                let existing = (try? context.fetch(descriptor))?.first
                if let existing {
                    existing.name = rh.name
                    existing.descriptionText = rh.description
                    existing.isPopular = rh.is_popular
                    existing.sortOrder = rh.sort_order
                    existing.defaultTarget = rh.default_target
                    existing.defaultDays = rh.default_days
                    existing.defaultTimes = rh.default_times
                } else {
                    context.insert(Habit(
                        id: rh.id,
                        categoryId: rh.category_id,
                        name: rh.name,
                        descriptionText: rh.description,
                        type: TaskType(rawValue: rh.type) ?? .check,
                        unit: rh.unit,
                        defaultTarget: rh.default_target,
                        defaultDays: rh.default_days,
                        defaultTimes: rh.default_times,
                        isPopular: rh.is_popular,
                        sortOrder: rh.sort_order
                    ))
                }
            }

            try context.save()
        } catch {
            syncError = "Catalog sync failed: \(error.localizedDescription)"
        }
    }

    /// Pull user-specific data (user_habits, schedules, habit_days, log_entries, day_summaries).
    @MainActor
    func pullUserData(context: ModelContext, profileId: String) async {
        isSyncing = true
        defer { isSyncing = false }

        do {
            // 1. Pull user_habits
            let remoteUH: [RemoteUserHabit] = try await client
                .from("user_habits")
                .select()
                .eq("profile_id", value: profileId)
                .execute()
                .value

            for ruh in remoteUH {
                let ruhId = ruh.id
                let descriptor = FetchDescriptor<UserHabit>(predicate: #Predicate { $0.id == ruhId })
                let existing = (try? context.fetch(descriptor))?.first
                if let existing {
                    existing.sortOrder = ruh.sort_order
                    existing.archivedAt = ruh.archivedAtMs
                    existing.updatedAt = ruh.updatedAtMs
                } else {
                    context.insert(UserHabit(
                        id: ruh.id,
                        profileId: ruh.profile_id,
                        habitId: ruh.habit_id,
                        sortOrder: ruh.sort_order,
                        archivedAt: ruh.archivedAtMs,
                        createdAt: ruh.createdAtMs
                    ))
                }
            }

            let uhIds = remoteUH.map(\.id)

            // 2. Pull schedules for those user_habits
            let remoteSchedules: [RemoteUserHabitSchedule] = try await client
                .from("user_habit_schedules")
                .select()
                .in("user_habit_id", values: uhIds)
                .execute()
                .value

            for rs in remoteSchedules {
                let rsId = rs.id
                let descriptor = FetchDescriptor<UserHabitSchedule>(predicate: #Predicate { $0.id == rsId })
                let existing = (try? context.fetch(descriptor))?.first
                if existing == nil {
                    context.insert(UserHabitSchedule(
                        id: rs.id,
                        userHabitId: rs.user_habit_id,
                        target: rs.target,
                        days: rs.days,
                        times: rs.times,
                        effectiveFrom: rs.effective_from,
                        effectiveTo: rs.effective_to
                    ))
                }
            }

            // 3. Pull habit_days
            let remoteHDs: [RemoteHabitDay] = try await client
                .from("habit_days")
                .select()
                .in("user_habit_id", values: uhIds)
                .execute()
                .value

            for rhd in remoteHDs {
                let rhdId = rhd.id
                let descriptor = FetchDescriptor<HabitDay>(predicate: #Predicate { $0.id == rhdId })
                let existing = (try? context.fetch(descriptor))?.first
                if let existing {
                    existing.status = rhd.status
                    existing.pct = rhd.pct
                    existing.sum = rhd.sum
                } else {
                    context.insert(HabitDay(
                        id: rhd.id,
                        userHabitId: rhd.user_habit_id,
                        scheduleId: rhd.schedule_id,
                        date: rhd.date,
                        targetSnap: rhd.target_snap,
                        unitSnap: rhd.unit_snap,
                        status: rhd.status,
                        pct: rhd.pct,
                        sum: rhd.sum
                    ))
                }
            }

            let hdIds = remoteHDs.map(\.id)

            // 4. Pull log_entries → HabitLogEntry (V2)
            if !hdIds.isEmpty {
                let remoteLogs: [RemoteLogEntry] = try await client
                    .from("log_entries")
                    .select()
                    .in("habit_day_id", values: hdIds)
                    .execute()
                    .value

                for rl in remoteLogs where rl.deleted_at == nil {
                    let rlId = rl.id
                    let descriptor = FetchDescriptor<HabitLogEntry>(predicate: #Predicate { $0.id == rlId })
                    let existing = (try? context.fetch(descriptor))?.first
                    if existing == nil {
                        context.insert(HabitLogEntry(
                            id: rl.id,
                            habitDayId: rl.habit_day_id,
                            value: rl.value,
                            loggedAt: rl.loggedAtMs,
                            time: rl.time,
                            timezone: rl.timezone
                        ))
                    }
                }
            }

            // 5. Pull day_summaries
            let remoteSummaries: [RemoteDaySummary] = try await client
                .from("day_summaries")
                .select()
                .eq("profile_id", value: profileId)
                .execute()
                .value

            for rs in remoteSummaries {
                let rsId = rs.id
                let descriptor = FetchDescriptor<DaySummary>(predicate: #Predicate { $0.id == rsId })
                let existing = (try? context.fetch(descriptor))?.first
                if let existing {
                    existing.total = rs.total
                    existing.done = rs.done
                    existing.partial = rs.partial
                    existing.overdue = rs.overdue
                    existing.pct = rs.pct
                    existing.streakDay = rs.streak_day
                    existing.updatedAt = rs.updatedAtMs
                } else {
                    context.insert(DaySummary(
                        id: rs.id,
                        profileId: rs.profile_id,
                        date: rs.date,
                        total: rs.total,
                        done: rs.done,
                        partial: rs.partial,
                        overdue: rs.overdue,
                        pct: rs.pct,
                        streakDay: rs.streak_day
                    ))
                }
            }

            try context.save()
            lastSyncedAt = Date()
            syncError = nil
        } catch {
            syncError = "User sync failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Push: Local → Supabase

    /// Adopt a habit: insert user_habit + initial schedule, push to Supabase
    @MainActor
    func adoptHabit(
        habit: Habit,
        profileId: String,
        target: Double?,
        days: [Int],
        times: [String],
        today: String,
        context: ModelContext
    ) async throws {
        let userHabit = UserHabit(
            profileId: profileId,
            habitId: habit.id,
            sortOrder: 0
        )
        context.insert(userHabit)

        let schedule = UserHabitSchedule(
            userHabitId: userHabit.id,
            target: target,
            days: days,
            times: times,
            effectiveFrom: today
        )
        context.insert(schedule)
        try context.save()

        // Generate today's habit_day locally if scheduled
        let dow = dayOfWeek(Date())
        let isScheduledToday = days.isEmpty || days.contains(dow)
        var habitDay: HabitDay?
        if isScheduledToday {
            let hd = HabitDay(
                userHabitId: userHabit.id,
                scheduleId: schedule.id,
                date: today,
                targetSnap: target,
                unitSnap: habit.unit
            )
            context.insert(hd)
            habitDay = hd
        }

        // Enqueue all pushes
        let encoder = JSONEncoder()

        let uhDTO = PushUserHabit(id: userHabit.id, profile_id: profileId, habit_id: habit.id, sort_order: 0)
        let schedDTO = PushUserHabitSchedule(id: schedule.id, user_habit_id: userHabit.id, target: target, days: days, times: times, effective_from: today)

        let uhPending = PendingSync(table: "user_habits", payload: String(data: try encoder.encode(uhDTO), encoding: .utf8) ?? "")
        let schedPending = PendingSync(table: "user_habit_schedules", payload: String(data: try encoder.encode(schedDTO), encoding: .utf8) ?? "")
        context.insert(uhPending)
        context.insert(schedPending)

        var hdPending: PendingSync?
        if let hd = habitDay {
            let hdDTO = PushHabitDay(id: hd.id, user_habit_id: hd.userHabitId, schedule_id: hd.scheduleId, date: hd.date, target_snap: hd.targetSnap, unit_snap: hd.unitSnap, status: hd.status, pct: hd.pct, sum: hd.sum)
            let p = PendingSync(table: "habit_days", payload: String(data: try encoder.encode(hdDTO), encoding: .utf8) ?? "")
            context.insert(p)
            hdPending = p
        }

        try context.save()

        // Attempt immediate push — failures stay in queue for drainPendingSync
        do {
            try await client.from("user_habits").insert(uhDTO).execute()
            context.delete(uhPending)
        } catch { print("[SyncEngine] user_habit push queued: \(error.localizedDescription)") }

        do {
            try await client.from("user_habit_schedules").insert(schedDTO).execute()
            context.delete(schedPending)
        } catch { print("[SyncEngine] schedule push queued: \(error.localizedDescription)") }

        if let hd = habitDay, let p = hdPending {
            do {
                try await pushHabitDay(hd)
                context.delete(p)
            } catch { print("[SyncEngine] habit_day push queued: \(error.localizedDescription)") }
        }

        try context.save()
    }

    // MARK: - Pending Sync Queue

    /// Drain all pending sync items. Call on app launch and on connectivity restore.
    @MainActor
    func drainPendingSync(context: ModelContext) async {
        let pending = (try? context.fetch(
            FetchDescriptor<PendingSync>(sortBy: [SortDescriptor(\.createdAt)])
        )) ?? []

        guard !pending.isEmpty else { return }
        print("[SyncEngine] draining \(pending.count) pending sync items")

        for item in pending {
            guard let data = item.payload.data(using: .utf8) else {
                context.delete(item)
                continue
            }

            do {
                switch item.table {
                case "log_entries":
                    let dto = try JSONDecoder().decode(PushLogEntry.self, from: data)
                    try await client.from("log_entries").insert(dto).execute()
                case "user_habits":
                    let dto = try JSONDecoder().decode(PushUserHabit.self, from: data)
                    try await client.from("user_habits").insert(dto).execute()
                case "user_habit_schedules":
                    let dto = try JSONDecoder().decode(PushUserHabitSchedule.self, from: data)
                    try await client.from("user_habit_schedules").insert(dto).execute()
                case "habit_days":
                    let dto = try JSONDecoder().decode(PushHabitDay.self, from: data)
                    try await client.from("habit_days").insert(dto).execute()
                default:
                    print("[SyncEngine] unknown table: \(item.table)")
                }
                // Success — remove from queue
                context.delete(item)
                try context.save()
            } catch {
                item.retryCount += 1
                print("[SyncEngine] retry \(item.retryCount) failed for \(item.table): \(error.localizedDescription)")
                // Leave in queue for next drain cycle
            }
        }
    }

    /// Push a single HabitDay to Supabase
    func pushHabitDay(_ hd: HabitDay) async throws {
        try await client
            .from("habit_days")
            .insert(PushHabitDay(
                id: hd.id,
                user_habit_id: hd.userHabitId,
                schedule_id: hd.scheduleId,
                date: hd.date,
                target_snap: hd.targetSnap,
                unit_snap: hd.unitSnap,
                status: hd.status,
                pct: hd.pct,
                sum: hd.sum
            ))
            .execute()
    }

    /// Push all locally-generated habit_days for a date to Supabase
    @MainActor
    func pushHabitDaysForDate(_ date: Date, profileId: String, context: ModelContext) async {
        let dateKey = localDateKey(date)
        let pid = profileId

        let userHabits = (try? context.fetch(
            FetchDescriptor<UserHabit>(predicate: #Predicate { $0.profileId == pid })
        )) ?? []
        let uhIds = Set(userHabits.map(\.id))

        let allHDs = (try? context.fetch(FetchDescriptor<HabitDay>())) ?? []
        let todayHDs = allHDs.filter { $0.date == dateKey && uhIds.contains($0.userHabitId) }

        for hd in todayHDs {
            do {
                try await pushHabitDay(hd)
            } catch {
                // Might already exist on server — that's fine (unique constraint)
                print("[SyncEngine] pushHabitDay failed for \(hd.id): \(error.localizedDescription)")
            }
        }
    }

    /// Log a completion: update local HabitDay, push log_entry to Supabase
    @MainActor
    func logCompletion(
        habitDayId: String,
        value: Double,
        timezone: String,
        context: ModelContext
    ) async throws {
        // 1. Update local HabitDay immediately (mirrors the Postgres trigger)
        let hdId = habitDayId
        let descriptor = FetchDescriptor<HabitDay>(predicate: #Predicate { $0.id == hdId })
        guard let habitDay = (try? context.fetch(descriptor))?.first else { return }

        let newSum = habitDay.sum + value
        habitDay.sum = newSum

        let target = habitDay.targetSnap
        let newPct: Double
        if target == nil || target == 0 {
            // check/yesno: any value >= 1 = done
            newPct = newSum >= 1 ? 1.0 : 0.0
        } else {
            newPct = newSum / target!
        }
        habitDay.pct = newPct

        if newPct >= 1.0 {
            habitDay.status = "done"
        } else if newPct > 0 {
            habitDay.status = "partial"
        } else {
            habitDay.status = "pending"
        }

        // 2. Store local log entry
        let logId = UUID().uuidString
        let logEntry = HabitLogEntry(
            id: logId,
            habitDayId: habitDayId,
            value: value
        )
        context.insert(logEntry)

        // 3. Update local DaySummary
        recomputeLocalDaySummary(date: habitDay.date, userHabitId: habitDay.userHabitId, context: context)

        try context.save()

        // 4. Enqueue + attempt push to Supabase
        let pushDTO = PushLogEntry(
            id: logId,
            habit_day_id: habitDayId,
            value: value,
            timezone: timezone
        )

        let payload = try JSONEncoder().encode(pushDTO)
        let pending = PendingSync(
            table: "log_entries",
            payload: String(data: payload, encoding: .utf8) ?? ""
        )
        context.insert(pending)
        try context.save()

        // Attempt immediate push — if it fails, drainPendingSync will retry
        do {
            try await client.from("log_entries").insert(pushDTO).execute()
            context.delete(pending)
            try context.save()
        } catch {
            print("[SyncEngine] log push queued for retry: \(error.localizedDescription)")
        }
    }

    /// Recompute the local DaySummary for a given date after a HabitDay change.
    @MainActor
    private func recomputeLocalDaySummary(date: String, userHabitId: String, context: ModelContext) {
        // Find the profile_id from the user_habit
        let uhId = userHabitId
        guard let uh = (try? context.fetch(
            FetchDescriptor<UserHabit>(predicate: #Predicate { $0.id == uhId })
        ))?.first else { return }

        let profileId = uh.profileId
        let dateKey = date

        // Aggregate all habit_days for this profile + date
        let allHDs = (try? context.fetch(FetchDescriptor<HabitDay>())) ?? []
        let allUHs = (try? context.fetch(
            FetchDescriptor<UserHabit>(predicate: #Predicate { $0.profileId == profileId })
        )) ?? []
        let uhIds = Set(allUHs.map(\.id))

        let todayHDs = allHDs.filter { $0.date == dateKey && uhIds.contains($0.userHabitId) }
        let total = todayHDs.count
        let done = todayHDs.filter { $0.status == "done" }.count
        let partial = todayHDs.filter { $0.status == "partial" }.count
        let pending = todayHDs.filter { $0.status == "pending" }.count
        let pct = total > 0 ? Double(done) / Double(total) : 0
        let streakDay = total > 0 && done == total

        // Upsert DaySummary
        let pid = profileId
        let existingDesc = FetchDescriptor<DaySummary>(
            predicate: #Predicate { $0.profileId == pid && $0.date == dateKey }
        )
        if let existing = (try? context.fetch(existingDesc))?.first {
            existing.total = total
            existing.done = done
            existing.partial = partial
            existing.overdue = pending
            existing.pct = pct
            existing.streakDay = streakDay
            existing.updatedAt = Date().timeIntervalSince1970 * 1000
        } else {
            context.insert(DaySummary(
                profileId: profileId,
                date: dateKey,
                total: total,
                done: done,
                partial: partial,
                overdue: pending,
                pct: pct,
                streakDay: streakDay
            ))
        }
    }

    /// Update a user_habit's schedule (target/days/times change)
    @MainActor
    func updateSchedule(
        userHabitId: String,
        currentScheduleId: String,
        newTarget: Double?,
        newDays: [Int],
        newTimes: [String],
        today: String,
        context: ModelContext
    ) async throws {
        // Close current schedule locally
        let schedId = currentScheduleId
        let descriptor = FetchDescriptor<UserHabitSchedule>(
            predicate: #Predicate { $0.id == schedId }
        )
        if let current = (try? context.fetch(descriptor))?.first {
            current.effectiveTo = today
        }

        // Insert new schedule locally
        let newSchedule = UserHabitSchedule(
            userHabitId: userHabitId,
            target: newTarget,
            days: newDays,
            times: newTimes,
            effectiveFrom: today
        )
        context.insert(newSchedule)
        try context.save()

        // Push to Supabase: close old schedule
        try await client
            .from("user_habit_schedules")
            .update(["effective_to": today])
            .eq("id", value: currentScheduleId)
            .execute()

        // Push to Supabase: insert new schedule
        try await client
            .from("user_habit_schedules")
            .insert(PushUserHabitSchedule(
                id: newSchedule.id,
                user_habit_id: userHabitId,
                target: newTarget,
                days: newDays,
                times: newTimes,
                effective_from: today
            ))
            .execute()
    }
}

// MARK: - Remote DTOs (Decodable — for pulling from Supabase)

struct RemoteCategory: Decodable {
    let id: String
    let name: String
    let sort_order: Int
}

struct RemoteHabit: Decodable {
    let id: String
    let category_id: String
    let name: String
    let description: String
    let type: String
    let unit: String?
    let default_target: Double?
    let default_days: [Int]
    let default_times: [String]
    let is_popular: Bool
    let sort_order: Int
}

struct RemoteUserHabit: Decodable {
    let id: String
    let profile_id: String
    let habit_id: String
    let sort_order: Int
    let archived_at: String?   // ISO 8601 timestamptz, nil = active
    let created_at: String
    let updated_at: String

    var archivedAtMs: Double? { archived_at.map { parseISO($0) } }
    var createdAtMs: Double { parseISO(created_at) }
    var updatedAtMs: Double { parseISO(updated_at) }
}

struct RemoteUserHabitSchedule: Decodable {
    let id: String
    let user_habit_id: String
    let target: Double?
    let days: [Int]
    let times: [String]
    let effective_from: String
    let effective_to: String?
}

struct RemoteHabitDay: Decodable {
    let id: String
    let user_habit_id: String
    let schedule_id: String
    let date: String
    let target_snap: Double?
    let unit_snap: String?
    let status: String
    let pct: Double
    let sum: Double
}

struct RemoteLogEntry: Decodable {
    let id: String
    let habit_day_id: String
    let value: Double
    let logged_at: String    // ISO 8601 timestamptz from Supabase
    let timezone: String
    let deleted_at: String?  // nil = active
    let created_at: String

    var loggedAtMs: Double { parseISO(logged_at) }

    /// Derive "HH:MM" from logged_at timestamp
    var time: String {
        let date = Date(timeIntervalSince1970: loggedAtMs / 1000)
        return localTimeKey(date)
    }
}

struct RemoteDaySummary: Decodable {
    let id: String
    let profile_id: String
    let date: String
    let total: Int
    let done: Int
    let partial: Int
    let overdue: Int
    let pct: Double
    let streak_day: Bool
    let updated_at: String

    var updatedAtMs: Double { parseISO(updated_at) }
}

// MARK: - ISO 8601 timestamp parser

private func parseISO(_ s: String) -> Double {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = formatter.date(from: s) {
        return date.timeIntervalSince1970 * 1000
    }
    // Fallback without fractional seconds
    formatter.formatOptions = [.withInternetDateTime]
    if let date = formatter.date(from: s) {
        return date.timeIntervalSince1970 * 1000
    }
    return Date().timeIntervalSince1970 * 1000
}

// MARK: - Push DTOs (Encodable — for pushing to Supabase)

struct PushUserHabit: Codable {
    let id: String
    let profile_id: String
    let habit_id: String
    let sort_order: Int
}

struct PushUserHabitSchedule: Codable {
    let id: String
    let user_habit_id: String
    let target: Double?
    let days: [Int]
    let times: [String]
    let effective_from: String
}

struct PushLogEntry: Codable {
    let id: String
    let habit_day_id: String
    let value: Double
    let timezone: String
}

struct PushHabitDay: Codable {
    let id: String
    let user_habit_id: String
    let schedule_id: String
    let date: String
    let target_snap: Double?
    let unit_snap: String?
    let status: String
    let pct: Double
    let sum: Double
}
