//
//  UserHabit.swift
//  Tally
//
//  Join table linking a user to a global habit they adopted.
//  One row per user per habit. Owns sort_order and archive state.

import Foundation
import SwiftData

@Model
final class UserHabit {
    var id: String = UUID().uuidString
    var profileId: String = ""
    var habitId: String = ""
    var sortOrder: Int = 0
    var archivedAt: Double?              // nil = active; unix ms timestamp
    var createdAt: Double = Date().timeIntervalSince1970 * 1000
    var updatedAt: Double = Date().timeIntervalSince1970 * 1000

    var isArchived: Bool { archivedAt != nil }

    init(
        id: String = UUID().uuidString,
        profileId: String,
        habitId: String,
        sortOrder: Int = 0,
        archivedAt: Double? = nil,
        createdAt: Double = Date().timeIntervalSince1970 * 1000
    ) {
        self.id = id
        self.profileId = profileId
        self.habitId = habitId
        self.sortOrder = sortOrder
        self.archivedAt = archivedAt
        self.createdAt = createdAt
    }
}
