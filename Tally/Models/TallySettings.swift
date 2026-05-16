//
//  TallySettings.swift
//  Tally
//

import Foundation
import SwiftData

@Model
final class TallySettings {
    var dark: Bool = false
    var density: String = "regular"    // "regular" or "compact"
    var showIcons: Bool = true
    var quietHoursEnabled: Bool = false
    var quietHoursStart: String = "22:00"
    var quietHoursEnd: String = "06:30"
    var hasOnboarded: Bool = false
    var name: String = ""
    var email: String = ""
    var initials: String = ""          // manual override; empty = auto-derive from name

    /// Auto-derived initials from name, unless manually overridden.
    var derivedInitials: String {
        if !initials.isEmpty { return initials }
        let parts = name.split(separator: " ")
        let derived = parts.prefix(2).map { String($0.prefix(1)).uppercased() }.joined()
        return derived.isEmpty ? "T" : derived
    }

    init(
        dark: Bool = false,
        density: String = "regular",
        showIcons: Bool = true,
        quietHoursEnabled: Bool = false,
        quietHoursStart: String = "22:00",
        quietHoursEnd: String = "06:30",
        hasOnboarded: Bool = false,
        name: String = "",
        email: String = "",
        initials: String = ""
    ) {
        self.dark = dark
        self.density = density
        self.showIcons = showIcons
        self.quietHoursEnabled = quietHoursEnabled
        self.quietHoursStart = quietHoursStart
        self.quietHoursEnd = quietHoursEnd
        self.hasOnboarded = hasOnboarded
        self.name = name
        self.email = email
        self.initials = initials
    }
}
