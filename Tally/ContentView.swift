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
    @State private var showAddTask = false

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Today", systemImage: "calendar", value: 0) {
                TodayScreen()
            }

            Tab("Tasks", systemImage: "list.bullet", value: 1) {
                TasksScreen()
            }

            Tab("Add", systemImage: "plus.circle.fill", value: 2) {
                Color.clear
            }

            Tab("Streak", systemImage: "flame", value: 3) {
                StreakScreen()
            }

            Tab("More", systemImage: "ellipsis", value: 4) {
                MoreScreen()
            }
        }
        .onChange(of: selectedTab) { oldValue, newValue in
            if newValue == 2 {
                selectedTab = oldValue
                showAddTask = true
            }
        }
        .sheet(isPresented: $showAddTask) {
            TaskFormView(taskId: nil)
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
        .modelContainer(for: [TallyTask.self, LogEntry.self, TallySettings.self], inMemory: true)
}
