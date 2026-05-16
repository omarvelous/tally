//
//  TallyShortcuts.swift
//  Tally
//
//  AppShortcutsProvider with suggested Siri phrases.

import AppIntents

struct TallyShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LogTaskIntent(),
            phrases: [
                "Log \(\.$task) in \(.applicationName)",
                "Add to \(\.$task) in \(.applicationName)",
                "Record \(\.$task) in \(.applicationName)",
            ],
            shortTitle: "Log Task",
            systemImageName: "plus.circle"
        )
    }
}
