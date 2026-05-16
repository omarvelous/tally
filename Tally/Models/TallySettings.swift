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
