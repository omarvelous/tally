//
//  ContentView.swift
//  Tally
//
//  Created by Omar Johnson on 5/15/26.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selectedTab = 0
    @State private var logCoordinator = LogSheetCoordinator()

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Today", systemImage: "calendar", value: 0) {
                TodayScreen()
            }

            Tab("Tasks", systemImage: "list.bullet", value: 1) {
                TasksScreen()
            }

            Tab("Streak", systemImage: "flame", value: 2) {
                StreakScreen()
            }

            Tab("More", systemImage: "ellipsis", value: 3) {
                MoreScreen()
            }
        }
        .environment(logCoordinator)
        .sheet(item: $logCoordinator.logTaskId) { habitDayId in
            LogSheet(habitDayId: habitDayId)
                .presentationDetents([.fraction(0.95)])
                .presentationDragIndicator(.visible)
        }
        .onAppear {
            #if DEBUG
            SeedData.seedIfNeeded(context: modelContext)
            #endif
        }
    }
}

#Preview {
    ContentView()
        .environment(NotificationScheduler())
        .environment(MidnightObserver())
        .modelContainer(for: [TallyTask.self, LogEntry.self, TallySettings.self], inMemory: true)
}
