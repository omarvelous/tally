//
//  Category.swift
//  Tally
//
//  Server-managed grouping for browsing habits.
//  Synced from Supabase `categories` table. Read-only locally.

import Foundation
import SwiftData

@Model
final class Category {
    var id: String = UUID().uuidString
    var name: String = ""
    var sortOrder: Int = 0
    var createdAt: Double = Date().timeIntervalSince1970 * 1000

    init(
        id: String = UUID().uuidString,
        name: String,
        sortOrder: Int = 0,
        createdAt: Double = Date().timeIntervalSince1970 * 1000
    ) {
        self.id = id
        self.name = name
        self.sortOrder = sortOrder
        self.createdAt = createdAt
    }
}
