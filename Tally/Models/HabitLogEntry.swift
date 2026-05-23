//
//  HabitLogEntry.swift
//  Tally
//
//  V2 log entry — one row per user action (tap "log", "mark complete", etc).
//  References a HabitDay by ID. Stored locally + pushed to Supabase log_entries.

import Foundation
import SwiftData

@Model
final class HabitLogEntry {
    var id: String = UUID().uuidString
    var habitDayId: String = ""
    var value: Double = 0              // 1.0 for check/yesno, amount for count/timer/numeric
    var loggedAt: Double = Date().timeIntervalSince1970 * 1000  // unix ms
    var time: String = ""              // "HH:MM" display string
    var timezone: String = TimeZone.current.identifier
    var deleted: Bool = false          // soft delete

    init(
        id: String = UUID().uuidString,
        habitDayId: String,
        value: Double,
        loggedAt: Double = Date().timeIntervalSince1970 * 1000,
        time: String = "",
        timezone: String = TimeZone.current.identifier
    ) {
        self.id = id
        self.habitDayId = habitDayId
        self.value = value
        self.loggedAt = loggedAt
        self.time = time.isEmpty ? localTimeKey(Date()) : time
        self.timezone = timezone
    }
}
