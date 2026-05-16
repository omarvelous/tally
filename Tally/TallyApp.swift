//
//  TallyApp.swift
//  Tally
//
//  Created by Omar Johnson on 5/15/26.
//

import SwiftUI
import SwiftData

@main
struct TallyApp: App {
    @State private var notificationScheduler = NotificationScheduler()
    @State private var midnightObserver = MidnightObserver()

    var sharedModelContainer: ModelContainer = {
        do {
            return try ModelContainerFactory.create()
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(notificationScheduler)
                .environment(midnightObserver)
                .task {
                    await notificationScheduler.requestPermission()
                    scheduleNotifications()
                }
        }
        .modelContainer(sharedModelContainer)
    }

    @MainActor
    private func scheduleNotifications() {
        let context = sharedModelContainer.mainContext
        let tasks = (try? context.fetch(FetchDescriptor<TallyTask>())) ?? []
        let settings = (try? context.fetch(FetchDescriptor<TallySettings>()))?.first

        notificationScheduler.rescheduleAll(
            tasks: tasks,
            quietHoursEnabled: settings?.quietHoursEnabled ?? false,
            quietStart: settings?.quietHoursStart ?? "22:00",
            quietEnd: settings?.quietHoursEnd ?? "06:30"
        )
    }
}
