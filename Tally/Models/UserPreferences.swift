//
//  UserPreferences.swift
//  Tally
//
//  Per-user settings synced with Supabase `preferences` table.
//  Singleton per profile.

import Foundation
import SwiftData

@Model
final class UserPreferences {
    var id: String = UUID().uuidString
    var profileId: String = ""
    var theme: String = "system"         // system, light, dark
    var density: String = "regular"      // regular, compact
    var quietStart: String?              // "HH:MM" or nil
    var quietEnd: String?                // "HH:MM" or nil
    var notifEnabled: Bool = true
    var updatedAt: Double = Date().timeIntervalSince1970 * 1000

    init(
        id: String = UUID().uuidString,
        profileId: String,
        theme: String = "system",
        density: String = "regular",
        quietStart: String? = nil,
        quietEnd: String? = nil,
        notifEnabled: Bool = true,
        updatedAt: Double = Date().timeIntervalSince1970 * 1000
    ) {
        self.id = id
        self.profileId = profileId
        self.theme = theme
        self.density = density
        self.quietStart = quietStart
        self.quietEnd = quietEnd
        self.notifEnabled = notifEnabled
        self.updatedAt = updatedAt
    }
}
