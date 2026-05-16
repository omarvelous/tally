//
//  RemindersView.swift
//  Tally
//
//  Per-task notification config: quiet hours + PING/NAG/SOUND chips.

import SwiftUI
import SwiftData

struct RemindersView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<TallyTask> { !$0.archived }) private var tasks: [TallyTask]
    @Query private var settings: [TallySettings]

    var body: some View {
        let c = TallyColors.resolve(colorScheme)
        let s = settings.first ?? TallySettings()

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("SETTINGS")
                            .font(TallyFont.label())
                            .textCase(.uppercase)
                            .tracking(1.2)
                            .foregroundStyle(c.dim)
                        Text("Reminders")
                            .font(TallyFont.heading(28, weight: .medium))
                            .foregroundStyle(c.text)
                    }

                    // Quiet hours
                    TallyCard {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Quiet hours")
                                    .font(TallyFont.heading(15, weight: .medium))
                                    .foregroundStyle(c.text)
                                Text(verbatim: "\(s.quietHoursStart) — \(s.quietHoursEnd) · NO PINGS")
                                    .font(TallyFont.mono(11))
                                    .foregroundStyle(c.dim)
                            }
                            Spacer()
                            Toggle("", isOn: Binding(
                                get: { s.quietHoursEnabled },
                                set: { newVal in
                                    let settings = ensureSettings()
                                    settings.quietHoursEnabled = newVal
                                }
                            ))
                            .labelsHidden()
                        }
                    }

                    // Per-task
                    VStack(alignment: .leading, spacing: 0) {
                        Text("PER TASK")
                            .font(TallyFont.label())
                            .textCase(.uppercase)
                            .tracking(1.2)
                            .foregroundStyle(c.dim)
                            .padding(.bottom, 8)

                        ForEach(tasks, id: \.id) { task in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(task.name)
                                        .font(TallyFont.heading(14, weight: .medium))
                                        .foregroundStyle(c.text)
                                    Spacer()
                                    Text(task.times.joined(separator: " · ").uppercased())
                                        .font(TallyFont.mono(10))
                                        .foregroundStyle(c.dim)
                                }

                                HStack(spacing: 6) {
                                    notifChip("PING", active: task.notifPing, c: c) {
                                        task.notifPing.toggle()
                                    }
                                    notifChip("NAG +15", active: task.notifNag, c: c) {
                                        task.notifNag.toggle()
                                    }
                                    notifChip("SOUND", active: task.notifSound, c: c) {
                                        task.notifSound.toggle()
                                    }
                                }
                            }
                            .padding(.vertical, 14)
                            .overlay(alignment: .bottom) {
                                Rectangle().fill(c.rule).frame(height: 1)
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .background(c.bg)
            .navigationTitle("Reminders")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func notifChip(_ label: String, active: Bool, c: TallyColors, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(verbatim: label)
                .font(TallyFont.mono(10, weight: .bold))
                .tracking(1.0)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(active ? c.accent : Color.clear)
                .foregroundStyle(active ? .white : c.dim)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(active ? c.accent : c.rule, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    @discardableResult
    private func ensureSettings() -> TallySettings {
        if let existing = settings.first { return existing }
        let s = TallySettings()
        modelContext.insert(s)
        return s
    }
}
