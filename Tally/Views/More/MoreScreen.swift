//
//  MoreScreen.swift
//  Tally
//
//  Settings: profile, appearance, notifications, task management, data.

import Auth
import SwiftUI
import SwiftData

struct MoreScreen: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @Environment(AuthService.self) private var auth
    @Query private var userHabits: [UserHabit]
    @Query private var settings: [TallySettings]

    @State private var showProfile = false
    @State private var showReminders = false
    @State private var showResetConfirm = false
    @State private var showSignOutConfirm = false

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

                    // Profile card (tappable)
                    Button { showProfile = true } label: {
                        TallyCard {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(currentSettings.name.isEmpty ? "Tally" : currentSettings.name)
                                        .font(TallyFont.heading(16, weight: .medium))
                                        .foregroundStyle(c.text)
                                    let activeCount = userHabits.filter { $0.profileId == (auth.userId ?? "") && !$0.isArchived }.count
                                    Text(verbatim: "\(activeCount) ACTIVE HABITS")
                                        .font(TallyFont.mono(11))
                                        .foregroundStyle(c.dim)
                                }
                                Spacer()
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(c.accent)
                                    .frame(width: 44, height: 44)
                                    .overlay(
                                        Text(verbatim: currentSettings.derivedInitials)
                                            .font(TallyFont.heading(18, weight: .semibold))
                                            .foregroundStyle(.white)
                                    )
                            }
                        }
                    }
                    .buttonStyle(.plain)

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

                    // Account
                    settingsSection("ACCOUNT", c: c) {
                        if let email = auth.session?.user.email {
                            settingRow("Signed in as", c: c) {
                                Text(email)
                                    .font(TallyFont.mono(11))
                                    .foregroundStyle(c.dim)
                            }
                        }
                        navRow("Sign out", sub: "You can sign back in anytime", c: c, danger: true) {
                            showSignOutConfirm = true
                        }
                    }

                    // Data
                    settingsSection("DATA", c: c) {
                        navRow("Reset data", sub: "Wipe all tasks and entries", c: c, danger: true) {
                            showResetConfirm = true
                        }
                    }

                    Text("TALLY · v2.0")
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
        .sheet(isPresented: $showProfile) {
            ProfileEditorView()
        }
        .sheet(isPresented: $showReminders) {
            RemindersView()
        }
        .confirmationDialog("Reset all data?", isPresented: $showResetConfirm, titleVisibility: .visible) {
            Button("Reset everything", role: .destructive) { resetData() }
        } message: {
            Text("This will delete all tasks and log entries.")
        }
        .confirmationDialog("Sign out?", isPresented: $showSignOutConfirm, titleVisibility: .visible) {
            Button("Sign out", role: .destructive) {
                Task { try? await auth.signOut() }
            }
        } message: {
            Text("Your data is synced. You can sign back in anytime.")
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
        try? modelContext.delete(model: HabitDay.self)
        try? modelContext.delete(model: UserHabitSchedule.self)
        try? modelContext.delete(model: UserHabit.self)
        try? modelContext.delete(model: DaySummary.self)
        try? modelContext.delete(model: PendingSync.self)
    }
}
