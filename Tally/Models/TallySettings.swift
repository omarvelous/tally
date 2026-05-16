//
//  TallySettings.swift
//  Tally
//

import Foundation
import SwiftData

@Model
final class TallySettings {
    var dark: Bool
    var density: String           // "regular" or "compact"
    var showIcons: Bool
    var quietHoursEnabled: Bool
    var quietHoursStart: String   // "HH:MM"
    var quietHoursEnd: String     // "HH:MM"
    var hasOnboarded: Bool

    init(
        dark: Bool = false,
        density: String = "regular",
        showIcons: Bool = true,
        quietHoursEnabled: Bool = false,
        quietHoursStart: String = "22:00",
        quietHoursEnd: String = "06:30",
        hasOnboarded: Bool = false
    ) {
        self.dark = dark
        self.density = density
        self.showIcons = showIcons
        self.quietHoursEnabled = quietHoursEnabled
        self.quietHoursStart = quietHoursStart
        self.quietHoursEnd = quietHoursEnd
        self.hasOnboarded = hasOnboarded
    }
}
