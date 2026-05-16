//
//  LogEntry.swift
//  Tally
//

import Foundation
import SwiftData

@Model
final class LogEntry {
    var id: String = UUID().uuidString
    var taskId: String = ""
    var date: String = ""             // "YYYY-MM-DD"
    var time: String = ""             // "HH:MM"
    var value: Double = 0             // 1.0=true, 0.0=false for check/yesno; number for count/timer/numeric
    var ts: Double = 0                // unix ms, for sort order
    var tz: String = TimeZone.current.identifier  // timezone at time of logging, e.g. "America/New_York"
    var deleted: Bool = false          // soft delete — hidden from UI, data preserved

    init(
        id: String = UUID().uuidString,
        taskId: String,
        date: String,
        time: String,
        value: Double,
        ts: Double = Date().timeIntervalSince1970 * 1000,
        tz: String = TimeZone.current.identifier
    ) {
        self.id = id
        self.taskId = taskId
        self.date = date
        self.time = time
        self.value = value
        self.ts = ts
        self.tz = tz
    }
}
