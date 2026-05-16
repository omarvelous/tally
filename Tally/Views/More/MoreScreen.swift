//
//  MoreScreen.swift
//  Tally
//
//  Settings: profile, appearance, notifications, task management, data.

import SwiftUI
import SwiftData

struct MoreScreen: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<TallyTask> { !$0.archived }) private var activeTasks: [TallyTask]
    @Query private var allTasks: [TallyTask]
    @Query private var settings: [TallySettings]

    @State private var showOnboarding = false
    @State private var showManage = false
    @State private var showReminders = false
    @State private var showAddTask = false
    @State private var showResetConfirm = false

    private var currentSettings: TallySettings {
        settings.first ?? TallySettings()
    }

    var body: some View {
        let c = TallyColors.resolve(colorScheme)

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 4) {
                        Text("SETTINGS")
                            .font(TallyFont.label())
                            .textCase(.uppercase)
                            .tracking(1.2)
                            .foregroundStyle(c.dim)
                        Text("More")
                            .font(TallyFont.heading(32, weight: .medium))
                            .foregroundStyle(c.text)
                    }
                    .padding(.top, 8)

                    // Profile card
                    TallyCard {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Tally")
                                    .font(TallyFont.heading(16, weight: .medium))
                                    .foregroundStyle(c.text)
                                Text(verbatim: "\(activeTasks.count) ACTIVE TASKS")
                                    .font(TallyFont.mono(11))
                                    .foregroundStyle(c.dim)
                            }
                            Spacer()
                            RoundedRectangle(cornerRadius: 12)
                                .fill(c.accent)
                                .frame(width: 44, height: 44)
                                .overlay(
                                    Text("T")
                                        .font(TallyFont.heading(18, weight: .semibold))
                                        .foregroundStyle(.white)
                                )
                        }
                    }

                    // Appearance
                    settingsSection("APPEARANCE", c: c) {
                        settingRow("Dark mode", c: c) {
                            Toggle("", isOn: Binding(
                                get: { currentSettings.dark },
                                set: { ensureSettings().dark = $0 }
                            ))
                            .labelsHidden()
                        }
                        settingRow("Density", c: c) {
                            HStack(spacing: 4) {
                                densityButton("REGULAR", value: "regular", c: c)
                                densityButton("COMPACT", value: "compact", c: c)
                            }
                        }
                        settingRow("Show icons", c: c) {
                            Toggle("", isOn: Binding(
                                get: { currentSettings.showIcons },
                                set: { ensureSettings().showIcons = $0 }
                            ))
                            .labelsHidden()
                        }
                    }

                    // Notifications
                    settingsSection("NOTIFICATIONS", c: c) {
                        navRow("Reminders", sub: "Per-task notifications · quiet hours", c: c) {
                            showReminders = true
                        }
                    }

                    // Tasks
                    settingsSection("TASKS", c: c) {
                        navRow("Manage tasks (\(allTasks.count))", sub: "Edit · archive · delete", c: c) {
                            showManage = true
                        }
                        navRow("Add task", sub: "New scheduled task", c: c) {
                            showAddTask = true
                        }
                    }

                    // Data
                    settingsSection("DATA", c: c) {
                        navRow("View onboarding", sub: "Replay the welcome screen", c: c) {
                            showOnboarding = true
                        }
                        navRow("Reset data", sub: "Wipe all tasks and entries", c: c, danger: true) {
                            showResetConfirm = true
                        }
                    }

                    Text("TALLY · v1.0")
                        .font(TallyFont.mono(10))
                        .tracking(1.4)
                        .foregroundStyle(c.dim)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 8)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .background(c.bg)
        }
        .sheet(isPresented: $showOnboarding) {
            OnboardingView()
        }
        .sheet(isPresented: $showManage) {
            ManageTasksView()
        }
        .sheet(isPresented: $showReminders) {
            RemindersView()
        }
        .sheet(isPresented: $showAddTask) {
            TaskFormView(taskId: nil)
        }
        .confirmationDialog("Reset all data?", isPresented: $showResetConfirm, titleVisibility: .visible) {
            Button("Reset everything", role: .destructive) { resetData() }
        } message: {
            Text("This will delete all tasks and log entries.")
        }
    }

    // MARK: - Setting rows

    private func settingsSection(_ title: String, c: TallyColors, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(verbatim: title)
                .font(TallyFont.label())
                .textCase(.uppercase)
                .tracking(1.2)
                .foregroundStyle(c.dim)
                .padding(.bottom, 4)
            content()
        }
    }

    private func settingRow(_ label: String, c: TallyColors, @ViewBuilder right: () -> some View) -> some View {
        HStack {
            Text(label)
                .font(TallyFont.heading(14, weight: .medium))
                .foregroundStyle(c.text)
            Spacer()
            right()
        }
        .padding(.vertical, 13)
        .overlay(alignment: .bottom) {
            Rectangle().fill(c.rule).frame(height: 1)
        }
    }

    private func navRow(_ label: String, sub: String, c: TallyColors, danger: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(TallyFont.heading(14, weight: .medium))
                        .foregroundStyle(danger ? c.neg : c.text)
                    Text(sub.uppercased())
                        .font(TallyFont.mono(10))
                        .foregroundStyle(c.dim)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(c.dim)
            }
            .padding(.vertical, 13)
            .overlay(alignment: .bottom) {
                Rectangle().fill(c.rule).frame(height: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private func densityButton(_ label: String, value: String, c: TallyColors) -> some View {
        let active = currentSettings.density == value
        return Button {
            ensureSettings().density = value
        } label: {
            Text(verbatim: label)
                .font(TallyFont.mono(10, weight: .semibold))
                .tracking(0.8)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(active ? c.accent : Color.clear)
                .foregroundStyle(active ? .white : c.dim)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(c.rule, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    @discardableResult
    private func ensureSettings() -> TallySettings {
        if let existing = settings.first { return existing }
        let s = TallySettings()
        modelContext.insert(s)
        return s
    }

    private func resetData() {
        // Delete all entries and tasks
        try? modelContext.delete(model: LogEntry.self)
        try? modelContext.delete(model: TallyTask.self)
        try? modelContext.delete(model: TallySettings.self)
        #if DEBUG
        SeedData.seedIfNeeded(context: modelContext)
        #endif
    }
}
