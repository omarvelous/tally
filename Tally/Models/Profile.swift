//
//  Profile.swift
//  Tally
//
//  User profile synced with Supabase `profiles` table.
//  One row per user. ID matches Supabase Auth user ID.

import Foundation
import SwiftData

@Model
final class Profile {
    var id: String = UUID().uuidString   // matches Supabase Auth user ID
    var displayName: String = ""
    var initials: String = ""            // manual override; empty = auto-derive
    var timezone: String = TimeZone.current.identifier
    var createdAt: Double = Date().timeIntervalSince1970 * 1000

    /// Auto-derived initials from name, unless manually overridden.
    var derivedInitials: String {
        if !initials.isEmpty { return initials }
        let parts = displayName.split(separator: " ")
        let derived = parts.prefix(2).map { String($0.prefix(1)).uppercased() }.joined()
        return derived.isEmpty ? "T" : derived
    }

    init(
        id: String = UUID().uuidString,
        displayName: String = "",
        initials: String = "",
        timezone: String = TimeZone.current.identifier,
        createdAt: Double = Date().timeIntervalSince1970 * 1000
    ) {
        self.id = id
        self.displayName = displayName
        self.initials = initials
        self.timezone = timezone
        self.createdAt = createdAt
    }
}
