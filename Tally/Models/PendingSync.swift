//
//  PendingSync.swift
//  Tally
//
//  Queued mutations waiting to be pushed to Supabase.
//  Persisted in SwiftData so they survive app kill.
//  The SyncEngine drains this queue on connectivity.

import Foundation
import SwiftData

@Model
final class PendingSync {
    var id: String = UUID().uuidString
    var table: String = ""           // "log_entries", "habit_days", "user_habits", etc.
    var operation: String = "insert" // "insert", "update"
    var payload: String = ""         // JSON-encoded push DTO
    var createdAt: Double = Date().timeIntervalSince1970 * 1000
    var retryCount: Int = 0

    init(
        id: String = UUID().uuidString,
        table: String,
        operation: String = "insert",
        payload: String,
        createdAt: Double = Date().timeIntervalSince1970 * 1000
    ) {
        self.id = id
        self.table = table
        self.operation = operation
        self.payload = payload
        self.createdAt = createdAt
    }
}
