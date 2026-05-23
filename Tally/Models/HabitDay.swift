//
//  HabitDay.swift
//  Tally
//
//  Materialized occurrence — one row per user-habit per active day.
//  THE source of truth for "was this habit due on date X?"
//  target_snap and unit_snap are frozen at generation time.

import Foundation
import SwiftData

@Model
final class HabitDay {
    var id: String = UUID().uuidString
    var userHabitId: String = ""
    var scheduleId: String = ""
    var date: String = ""                // "YYYY-MM-DD"
    var targetSnap: Double?              // frozen target at generation time
    var unitSnap: String?                // frozen unit from Habit.unit
    var status: String = "pending"       // pending, partial, done, skipped
    var pct: Double = 0                  // 0.0–1.0+
    var sum: Double = 0                  // running total of log entries
    var createdAt: Double = Date().timeIntervalSince1970 * 1000

    var isDone: Bool { status == "done" }
    var isPartial: Bool { status == "partial" }

    init(
        id: String = UUID().uuidString,
        userHabitId: String,
        scheduleId: String,
        date: String,
        targetSnap: Double? = nil,
        unitSnap: String? = nil,
        status: String = "pending",
        pct: Double = 0,
        sum: Double = 0,
        createdAt: Double = Date().timeIntervalSince1970 * 1000
    ) {
        self.id = id
        self.userHabitId = userHabitId
        self.scheduleId = scheduleId
        self.date = date
        self.targetSnap = targetSnap
        self.unitSnap = unitSnap
        self.status = status
        self.pct = pct
        self.sum = sum
        self.createdAt = createdAt
    }
}
