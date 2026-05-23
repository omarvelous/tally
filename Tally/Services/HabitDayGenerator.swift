//
//  HabitDayGenerator.swift
//  Tally
//
//  Local habit_day generation. Creates today's habit_day rows for active
//  user_habits whose schedule includes today's day-of-week.
//  Idempotent — skips if a habit_day already exists for (user_habit_id, date).
//
//  This runs client-side so the app works offline. The Edge Function
//  does the same thing server-side for multi-device consistency.

import Foundation
import SwiftData

enum HabitDayGenerator {

    /// Generate habit_days for the given date for all active user_habits.
    @MainActor
    static func generateForDate(_ date: Date, profileId: String, context: ModelContext) {
        let dateKey = localDateKey(date)
        let dow = dayOfWeek(date)
        let pid = profileId

        // Fetch all active user_habits for this profile
        let uhDescriptor = FetchDescriptor<UserHabit>(
            predicate: #Predicate { $0.profileId == pid && $0.archivedAt == nil }
        )
        guard let userHabits = try? context.fetch(uhDescriptor) else { return }

        for uh in userHabits {
            let uhId = uh.id

            // Check if habit_day already exists
            let existsDescriptor = FetchDescriptor<HabitDay>(
                predicate: #Predicate { $0.userHabitId == uhId && $0.date == dateKey }
            )
            if let existing = try? context.fetch(existsDescriptor), !existing.isEmpty {
                continue
            }

            // Find the currently active schedule
            let schedDescriptor = FetchDescriptor<UserHabitSchedule>(
                predicate: #Predicate { $0.userHabitId == uhId && $0.effectiveTo == nil }
            )
            guard let schedule = (try? context.fetch(schedDescriptor))?.first else { continue }

            // Check if today's DOW is in the schedule
            let days = schedule.days
            let isScheduled = days.isEmpty || days.contains(dow)
            guard isScheduled else { continue }

            // Check effective_from — don't generate before the schedule started
            if dateKey < schedule.effectiveFrom { continue }

            // Look up the global habit to get the unit
            let habitId = uh.habitId
            let habitDescriptor = FetchDescriptor<Habit>(predicate: #Predicate { $0.id == habitId })
            let unit = (try? context.fetch(habitDescriptor))?.first?.unit

            // Create the habit_day
            let habitDay = HabitDay(
                userHabitId: uh.id,
                scheduleId: schedule.id,
                date: dateKey,
                targetSnap: schedule.target,
                unitSnap: unit
            )
            context.insert(habitDay)
        }

        try? context.save()
    }
}
