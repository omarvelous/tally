//
//  HabitDayResolver.swift
//  Tally
//
//  Joins HabitDay + UserHabit + Habit + UserHabitSchedule into a single
//  view-ready struct. Since we use string IDs (not @Relationship), this
//  resolver does the manual lookups.

import Foundation
import SwiftData

/// Everything a view needs to render a single habit occurrence.
struct ResolvedHabitDay: Identifiable, Sendable {
    let id: String              // HabitDay.id
    let habitDayId: String
    let userHabitId: String
    let habitId: String

    // From Habit (global)
    let name: String
    let type: TaskType
    let unit: String?

    // From HabitDay (materialized)
    let date: String
    let targetSnap: Double?
    let unitSnap: String?
    let status: String          // pending, partial, done, skipped
    let pct: Double
    let sum: Double

    // From UserHabitSchedule
    let times: [String]
    let days: [Int]

    // Derived
    var statusKind: TaskStatusKind {
        switch status {
        case "done": return .done
        case "partial": return .partial
        case "skipped": return .off
        default: return .due
        }
    }

    var isDone: Bool { status == "done" }

    var label: String {
        switch type {
        case .check:
            return isDone ? "Done" : "—"
        case .yesno:
            return isDone ? "Yes" : "—"
        case .numeric:
            if sum > 0 {
                let formatted = unit != nil ? "\(formatNum(sum)) \(unit!)" : formatNum(sum)
                return formatted
            }
            return "—"
        case .count, .timer:
            let target = targetSnap ?? 1
            let unitStr = unitSnap ?? unit ?? ""
            return "\(Int(sum.rounded())) / \(Int(target)) \(unitStr)".trimmingCharacters(in: .whitespaces)
        }
    }

    var firstTime: String { times.first ?? "all-day" }

    var sortMinutes: Int {
        let ft = firstTime
        if ft == "all-day" { return 9999 }
        return parseHHMM(ft).mins
    }

    var timeLabel: String? {
        let ft = firstTime
        return ft == "all-day" ? nil : ft
    }

    private func formatNum(_ n: Double) -> String {
        n == n.rounded() ? String(Int(n)) : String(format: "%.1f", n)
    }
}

/// Resolve all habit_days for a given date into view-ready structs.
@MainActor
func resolveHabitDays(
    for dateKey: String,
    profileId: String,
    context: ModelContext
) -> [ResolvedHabitDay] {
    // Fetch habit_days for this date
    let habitDays = (try? context.fetch(
        FetchDescriptor<HabitDay>(predicate: #Predicate { $0.date == dateKey })
    )) ?? []

    guard !habitDays.isEmpty else { return [] }

    // Batch fetch user_habits for this profile
    let pid = profileId
    let userHabits = (try? context.fetch(
        FetchDescriptor<UserHabit>(predicate: #Predicate { $0.profileId == pid })
    )) ?? []
    let uhMap = Dictionary(userHabits.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })

    // Batch fetch all habits
    let habits = (try? context.fetch(FetchDescriptor<Habit>())) ?? []
    let habitMap = Dictionary(habits.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })

    // Batch fetch all active schedules
    let schedules = (try? context.fetch(
        FetchDescriptor<UserHabitSchedule>(predicate: #Predicate { $0.effectiveTo == nil })
    )) ?? []
    let schedMap = Dictionary(schedules.map { ($0.userHabitId, $0) }, uniquingKeysWith: { a, _ in a })

    return habitDays.compactMap { hd -> ResolvedHabitDay? in
        guard let uh = uhMap[hd.userHabitId],
              let habit = habitMap[uh.habitId] else { return nil }
        // Filter to this profile's habits only
        guard uh.profileId == profileId else { return nil }

        let sched = schedMap[uh.id]

        return ResolvedHabitDay(
            id: hd.id,
            habitDayId: hd.id,
            userHabitId: uh.id,
            habitId: habit.id,
            name: habit.name,
            type: habit.type,
            unit: habit.unit,
            date: hd.date,
            targetSnap: hd.targetSnap,
            unitSnap: hd.unitSnap,
            status: hd.status,
            pct: hd.pct,
            sum: hd.sum,
            times: sched?.times ?? ["all-day"],
            days: sched?.days ?? []
        )
    }
}

/// Resolve a single habit_day by ID.
@MainActor
func resolveHabitDay(id: String, context: ModelContext) -> ResolvedHabitDay? {
    let hdId = id
    guard let hd = (try? context.fetch(
        FetchDescriptor<HabitDay>(predicate: #Predicate { $0.id == hdId })
    ))?.first else { return nil }

    let uhId = hd.userHabitId
    guard let uh = (try? context.fetch(
        FetchDescriptor<UserHabit>(predicate: #Predicate { $0.id == uhId })
    ))?.first else { return nil }

    let habitId = uh.habitId
    guard let habit = (try? context.fetch(
        FetchDescriptor<Habit>(predicate: #Predicate { $0.id == habitId })
    ))?.first else { return nil }

    let sched = (try? context.fetch(
        FetchDescriptor<UserHabitSchedule>(predicate: #Predicate { $0.userHabitId == uhId && $0.effectiveTo == nil })
    ))?.first

    return ResolvedHabitDay(
        id: hd.id,
        habitDayId: hd.id,
        userHabitId: uh.id,
        habitId: habit.id,
        name: habit.name,
        type: habit.type,
        unit: habit.unit,
        date: hd.date,
        targetSnap: hd.targetSnap,
        unitSnap: hd.unitSnap,
        status: hd.status,
        pct: hd.pct,
        sum: hd.sum,
        times: sched?.times ?? ["all-day"],
        days: sched?.days ?? []
    )
}

/// Get sparkline data (last 14 days of pct) for a user_habit.
@MainActor
func habitSparkline(userHabitId: String, now: Date, context: ModelContext) -> [Double] {
    let uhId = userHabitId
    let habitDays = (try? context.fetch(
        FetchDescriptor<HabitDay>(predicate: #Predicate { $0.userHabitId == uhId })
    )) ?? []

    let byDate = Dictionary(habitDays.map { ($0.date, $0) }, uniquingKeysWith: { a, _ in a })

    return (0..<14).map { i in
        let d = addDays(now, -(13 - i))
        let key = localDateKey(d)
        return byDate[key]?.pct ?? 0
    }
}
