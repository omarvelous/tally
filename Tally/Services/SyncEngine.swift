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
                    existing.archivedAt = ruh.archived_at
                    existing.updatedAt = ruh.updated_at
                } else {
                    context.insert(UserHabit(
                        id: ruh.id,
                        profileId: ruh.profile_id,
                        habitId: ruh.habit_id,
                        sortOrder: ruh.sort_order,
                        archivedAt: ruh.archived_at,
                        createdAt: ruh.created_at
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

            // 4. Pull log_entries
            if !hdIds.isEmpty {
                let remoteLogs: [RemoteLogEntry] = try await client
                    .from("log_entries")
                    .select()
                    .in("habit_day_id", values: hdIds)
                    .execute()
                    .value

                for rl in remoteLogs {
                    let rlId = rl.id
                    let descriptor = FetchDescriptor<LogEntry>(predicate: #Predicate { $0.id == rlId })
                    let existing = (try? context.fetch(descriptor))?.first
                    if existing == nil {
                        // Note: LogEntry V1 uses taskId/date. For new V2 log entries
                        // we store the habit_day_id in taskId as a bridge field.
                        // Full V2 LogEntry model will replace this in Phase 6.
                        let entry = LogEntry(
                            id: rl.id,
                            taskId: rl.habit_day_id,
                            date: "",
                            time: "",
                            value: rl.value,
                            ts: rl.logged_at
                        )
                        context.insert(entry)
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
                    existing.updatedAt = rs.updated_at
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

        // Push to Supabase
        try await client
            .from("user_habits")
            .insert(PushUserHabit(
                id: userHabit.id,
                profile_id: profileId,
                habit_id: habit.id,
                sort_order: 0
            ))
            .execute()

        try await client
            .from("user_habit_schedules")
            .insert(PushUserHabitSchedule(
                id: schedule.id,
                user_habit_id: userHabit.id,
                target: target,
                days: days,
                times: times,
                effective_from: today
            ))
            .execute()
    }

    /// Log a completion: insert log_entry, push to Supabase
    @MainActor
    func logCompletion(
        habitDayId: String,
        value: Double,
        timezone: String,
        context: ModelContext
    ) async throws {
        let logId = UUID().uuidString
        let now = Date().timeIntervalSince1970 * 1000

        // The V1 LogEntry model bridges via taskId field
        let entry = LogEntry(
            id: logId,
            taskId: habitDayId,
            date: "",
            time: "",
            value: value,
            ts: now
        )
        context.insert(entry)
        try context.save()

        // Push to Supabase
        try await client
            .from("log_entries")
            .insert(PushLogEntry(
                id: logId,
                habit_day_id: habitDayId,
                value: value,
                timezone: timezone
            ))
            .execute()
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
    let archived_at: Double?
    let created_at: Double
    let updated_at: Double
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
    let logged_at: Double
    let timezone: String
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
    let updated_at: Double
}

// MARK: - Push DTOs (Encodable — for pushing to Supabase)

struct PushUserHabit: Encodable {
    let id: String
    let profile_id: String
    let habit_id: String
    let sort_order: Int
}

struct PushUserHabitSchedule: Encodable {
    let id: String
    let user_habit_id: String
    let target: Double?
    let days: [Int]
    let times: [String]
    let effective_from: String
}

struct PushLogEntry: Encodable {
    let id: String
    let habit_day_id: String
    let value: Double
    let timezone: String
}
