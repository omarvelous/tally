//
//  Habit.swift
//  Tally
//
//  Global habit definition shared across all users.
//  Synced from Supabase `habits` table. Read-only locally.
//  Type and unit are immutable — users cannot change them.

import Foundation
import SwiftData

@Model
final class Habit {
    var id: String = UUID().uuidString
    var categoryId: String = ""
    var name: String = ""
    var descriptionText: String = ""
    var habitType: String = "check"      // TaskType raw value
    var unit: String?                    // locked for all users; nil for check/yesno
    var defaultTarget: Double?           // suggested starting target
    var defaultDays: [Int] = [0,1,2,3,4,5,6]  // 0=Mon..6=Sun
    var defaultTimes: [String] = ["all-day"]
    var isPopular: Bool = false
    var sortOrder: Int = 0
    var createdAt: Double = Date().timeIntervalSince1970 * 1000

    var type: TaskType {
        get { TaskType(rawValue: habitType) ?? .check }
        set { habitType = newValue.rawValue }
    }

    init(
        id: String = UUID().uuidString,
        categoryId: String,
        name: String,
        descriptionText: String = "",
        type: TaskType,
        unit: String? = nil,
        defaultTarget: Double? = nil,
        defaultDays: [Int] = [0,1,2,3,4,5,6],
        defaultTimes: [String] = ["all-day"],
        isPopular: Bool = false,
        sortOrder: Int = 0,
        createdAt: Double = Date().timeIntervalSince1970 * 1000
    ) {
        self.id = id
        self.categoryId = categoryId
        self.name = name
        self.descriptionText = descriptionText
        self.habitType = type.rawValue
        self.unit = unit
        self.defaultTarget = defaultTarget
        self.defaultDays = defaultDays
        self.defaultTimes = defaultTimes
        self.isPopular = isPopular
        self.sortOrder = sortOrder
        self.createdAt = createdAt
    }
}
