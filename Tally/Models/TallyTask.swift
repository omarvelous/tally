//
//  TallyTask.swift
//  Tally
//

import Foundation
import SwiftData

@Model
final class TallyTask {
    @Attribute(.unique) var id: String
    var name: String
    var taskType: String          // TaskType raw value
    var target: Double?
    var unit: String?
    var days: [Int]               // 0=Mon..6=Sun, empty=daily
    var times: [String]           // ["HH:MM",...] or ["all-day"]
    var notifPing: Bool
    var notifNag: Bool
    var notifSound: Bool
    var archived: Bool
    var createdAt: Double          // unix ms

    var type: TaskType {
        get { TaskType(rawValue: taskType) ?? .check }
        set { taskType = newValue.rawValue }
    }

    /// True if this task is scheduled on the given day of week (0=Mon..6=Sun)
    var isDaily: Bool { days.isEmpty || days.count == 7 }

    func isScheduled(on dow: Int) -> Bool {
        days.isEmpty || days.contains(dow)
    }

    init(
        id: String = UUID().uuidString,
        name: String,
        type: TaskType,
        target: Double? = nil,
        unit: String? = nil,
        days: [Int] = [],
        times: [String] = ["all-day"],
        notifPing: Bool = true,
        notifNag: Bool = false,
        notifSound: Bool = true,
        archived: Bool = false,
        createdAt: Double = Date().timeIntervalSince1970 * 1000
    ) {
        self.id = id
        self.name = name
        self.taskType = type.rawValue
        self.target = target
        self.unit = unit
        self.days = days
        self.times = times
        self.notifPing = notifPing
        self.notifNag = notifNag
        self.notifSound = notifSound
        self.archived = archived
        self.createdAt = createdAt
    }
}
