//
//  ContentView.swift
//  Tally
//
//  Created by Omar Johnson on 5/15/26.
//

import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    @State private var showAddTask = false

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Today", systemImage: "calendar", value: 0) {
                NavigationStack {
                    Text("Today")
                        .navigationTitle("Today")
                }
            }

            Tab("Tasks", systemImage: "list.bullet", value: 1) {
                NavigationStack {
                    Text("Tasks")
                        .navigationTitle("Tasks")
                }
            }

            Tab("Add", systemImage: "plus.circle.fill", value: 2) {
                // Placeholder — replaced by sheet presentation
                Color.clear
            }

            Tab("Streak", systemImage: "flame", value: 3) {
                NavigationStack {
                    Text("Streak")
                        .navigationTitle("Streak")
                }
            }

            Tab("More", systemImage: "ellipsis", value: 4) {
                NavigationStack {
                    Text("More")
                        .navigationTitle("More")
                }
            }
        }
        .onChange(of: selectedTab) { oldValue, newValue in
            if newValue == 2 {
                selectedTab = oldValue
                showAddTask = true
            }
        }
        .sheet(isPresented: $showAddTask) {
            Text("Add Task")
                .presentationDetents([.large])
        }
    }
}

#Preview {
    ContentView()
}
