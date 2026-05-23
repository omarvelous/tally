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

            Tab("Habits", systemImage: "list.bullet", value: 1) {
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
        .sheet(item: $logCoordinator.logTaskId) { (habitDayId: String) in
            LogSheet(habitDayId: habitDayId)
                .presentationDetents([.fraction(0.95)])
                .presentationDragIndicator(.visible)
        }
    }
}

// MARK: - Live Preview (connects to Supabase)

#Preview {
    LivePreview()
}

/// Preview wrapper that uses the real persistent store, restores auth,
/// and syncs from Supabase so previews show actual data.
private struct LivePreview: View {
    @State private var auth = AuthService()
    @State private var sync = SyncEngine()
    @State private var ready = false

    var body: some View {
        Group {
            if ready {
                ContentView()
                    .environment(NotificationScheduler())
                    .environment(MidnightObserver())
                    .environment(auth)
                    .environment(sync)
            } else {
                ProgressView("Syncing...")
                    .task { await load() }
            }
        }
        .modelContainer(previewContainer)
    }

    private var previewContainer: ModelContainer {
        try! ModelContainerFactory.create()
    }

    @MainActor
    private func load() async {
        await auth.initialize()
        if let userId = auth.userId {
            let context = previewContainer.mainContext
            await sync.pullCatalog(context: context)
            await sync.pullUserData(context: context, profileId: userId)
            HabitDayGenerator.generateForDate(Date(), profileId: userId, context: context)
        }
        ready = true
    }
}
