//
//  UserHabitSchedule.swift
//  Tally
//
//  Temporal versioning of a user's schedule for an adopted habit.
//  New row on every edit. No unit column — inherited from Habit.unit.

import Foundation
import SwiftData

@Model
final class UserHabitSchedule {
    var id: String = UUID().uuidString
    var userHabitId: String = ""
    var target: Double?                  // user's personal target; nil for check/yesno
    var days: [Int] = [0,1,2,3,4,5,6]   // 0=Mon..6=Sun; empty = daily
    var times: [String] = ["all-day"]
    var effectiveFrom: String = ""       // "YYYY-MM-DD"
    var effectiveTo: String?             // nil = currently active
    var createdAt: Double = Date().timeIntervalSince1970 * 1000

    /// True if this schedule is currently active (no end date)
    var isCurrent: Bool { effectiveTo == nil }

    init(
        id: String = UUID().uuidString,
        userHabitId: String,
        target: Double? = nil,
        days: [Int] = [0,1,2,3,4,5,6],
        times: [String] = ["all-day"],
        effectiveFrom: String,
        effectiveTo: String? = nil,
        createdAt: Double = Date().timeIntervalSince1970 * 1000
    ) {
        self.id = id
        self.userHabitId = userHabitId
        self.target = target
        self.days = days
        self.times = times
        self.effectiveFrom = effectiveFrom
        self.effectiveTo = effectiveTo
        self.createdAt = createdAt
    }
}
