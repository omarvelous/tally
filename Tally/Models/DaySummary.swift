//
//  DaySummary.swift
//  Tally
//
//  Cached daily rollup per user per day.
//  Avoids recomputing from raw data on every render.
//  Updated by Postgres triggers or recomputed by Edge Function.

import Foundation
import SwiftData

@Model
final class DaySummary {
    var id: String = UUID().uuidString
    var profileId: String = ""
    var date: String = ""                // "YYYY-MM-DD"
    var total: Int = 0                   // count of habit_days for this user+date
    var done: Int = 0                    // habit_days where status = 'done'
    var partial: Int = 0                 // habit_days where status = 'partial'
    var overdue: Int = 0                 // habit_days where status = 'pending' (past due)
    var pct: Double = 0                  // done / total
    var streakDay: Bool = false          // pct >= 1.0 AND total > 0
    var createdAt: Double = Date().timeIntervalSince1970 * 1000
    var updatedAt: Double = Date().timeIntervalSince1970 * 1000

    init(
        id: String = UUID().uuidString,
        profileId: String,
        date: String,
        total: Int = 0,
        done: Int = 0,
        partial: Int = 0,
        overdue: Int = 0,
        pct: Double = 0,
        streakDay: Bool = false,
        createdAt: Double = Date().timeIntervalSince1970 * 1000
    ) {
        self.id = id
        self.profileId = profileId
        self.date = date
        self.total = total
        self.done = done
        self.partial = partial
        self.overdue = overdue
        self.pct = pct
        self.streakDay = streakDay
        self.createdAt = createdAt
    }
}
