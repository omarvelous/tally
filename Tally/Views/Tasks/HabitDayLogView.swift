//
//  HabitDayLogView.swift
//  Tally
//
//  Shows all log entries for a specific HabitDay (one habit on one date).
//  Navigated to from HabitDetailView's day history list.

import SwiftUI
import SwiftData

struct HabitDayLogView: View {
    let habitDayId: String

    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Query private var allLogEntries: [HabitLogEntry]

    var body: some View {
        let c = TallyColors.resolve(colorScheme)

        if let resolved = resolveHabitDay(id: habitDayId, context: modelContext) {
            let hdId = habitDayId
            let entries = allLogEntries
                .filter { $0.habitDayId == hdId && !$0.deleted }
                .sorted { $0.loggedAt > $1.loggedAt }

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 4) {
                        Text(resolved.name.uppercased())
                            .font(TallyFont.label())
                            .textCase(.uppercase)
                            .tracking(1.2)
                            .foregroundStyle(c.dim)

                        HStack {
                            Text(formatDateHeading(resolved.date))
                                .font(TallyFont.heading(24, weight: .medium))
                                .foregroundStyle(c.text)
                            Spacer()
                            statusBadge(resolved: resolved, c: c)
                        }
                    }
                    .padding(.top, 8)

                    // Summary card
                    TallyCard {
                        HStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("STATUS")
                                    .font(TallyFont.mono(10))
                                    .foregroundStyle(c.dim)
                                Text(resolved.isDone ? "Done" : resolved.status == "partial" ? "Partial" : "Pending")
                                    .font(TallyFont.heading(16, weight: .medium))
                                    .foregroundStyle(resolved.isDone ? c.pos : c.text)
                            }
                            if resolved.type == .count || resolved.type == .timer {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("TOTAL")
                                        .font(TallyFont.mono(10))
                                        .foregroundStyle(c.dim)
                                    Text("\(Int(resolved.sum.rounded())) / \(Int(resolved.targetSnap ?? 0)) \(resolved.unitSnap ?? "")")
                                        .font(TallyFont.heading(16, weight: .medium))
                                        .foregroundStyle(c.text)
                                }
                            }
                            Spacer()
                            Text("\(Int(resolved.pct * 100))%")
                                .font(TallyFont.heading(32, weight: .medium))
                                .monospacedDigit()
                                .foregroundStyle(resolved.isDone ? c.pos : c.accent)
                        }
                    }

                    // Entries
                    if entries.isEmpty {
                        VStack(spacing: 8) {
                            Text("No entries")
                                .font(TallyFont.heading(16, weight: .medium))
                                .foregroundStyle(c.text)
                            Text("Log entries will appear here when synced.")
                                .font(TallyFont.body(13))
                                .foregroundStyle(c.dim)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 20)
                    } else {
                        VStack(alignment: .leading, spacing: 0) {
                            Text("\(entries.count) \(entries.count == 1 ? "ENTRY" : "ENTRIES")")
                                .font(TallyFont.label())
                                .textCase(.uppercase)
                                .tracking(1.2)
                                .foregroundStyle(c.dim)
                                .padding(.bottom, 4)

                            ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                                HStack(spacing: 8) {
                                    Text(verbatim: String(format: "%02d", entries.count - index))
                                        .font(TallyFont.mono(11))
                                        .foregroundStyle(c.dim)
                                        .frame(width: 24)
                                    Text(verbatim: entry.time)
                                        .font(TallyFont.mono(11))
                                        .foregroundStyle(c.dim)
                                    Spacer()
                                    Text(verbatim: entryValueText(resolved: resolved, entry: entry))
                                        .font(TallyFont.mono(14, weight: .semibold))
                                        .foregroundStyle(c.text)
                                    Text(verbatim: (resolved.unitSnap ?? "").uppercased())
                                        .font(TallyFont.mono(10))
                                        .foregroundStyle(c.dim)
                                        .frame(width: 36, alignment: .trailing)
                                }
                                .padding(.vertical, 10)
                                .overlay(alignment: .bottom) {
                                    Rectangle().fill(c.rule).frame(height: 1)
                                }
                            }

                            // Total for count/timer
                            if resolved.type == .count || resolved.type == .timer {
                                HStack(spacing: 8) {
                                    Text("Σ")
                                        .font(TallyFont.mono(11, weight: .semibold))
                                        .frame(width: 24)
                                    Text("TOTAL")
                                        .font(TallyFont.mono(11))
                                        .foregroundStyle(c.dim)
                                    Spacer()
                                    Text(verbatim: "\(Int(resolved.sum.rounded()))")
                                        .font(TallyFont.mono(15, weight: .semibold))
                                        .foregroundStyle(resolved.isDone ? c.pos : c.accent)
                                    Text(verbatim: (resolved.unitSnap ?? "").uppercased())
                                        .font(TallyFont.mono(10))
                                        .foregroundStyle(c.dim)
                                        .frame(width: 36, alignment: .trailing)
                                }
                                .padding(.vertical, 12)
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .background(c.bg)
            .navigationBarTitleDisplayMode(.inline)
        } else {
            Text("Day not found")
                .foregroundStyle(TallyColors.resolve(colorScheme).dim)
        }
    }

    // MARK: - Helpers

    private func statusBadge(resolved: ResolvedHabitDay, c: TallyColors) -> some View {
        let color: Color = resolved.isDone ? c.pos : resolved.status == "partial" ? c.accent : c.dim2
        return Text(verbatim: "\(Int(resolved.pct * 100))%")
            .font(TallyFont.mono(11, weight: .semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }

    private func entryValueText(resolved: ResolvedHabitDay, entry: HabitLogEntry) -> String {
        switch resolved.type {
        case .check, .yesno: return "✓"
        case .numeric: return String(format: "%.1f", entry.value)
        case .count, .timer: return "+\(Int(entry.value))"
        }
    }

    private func formatDateHeading(_ dateKey: String) -> String {
        let parts = dateKey.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return dateKey }
        let date = Calendar.current.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2])) ?? Date()
        let dow = dayOfWeek(date)
        return "\(dayNames[dow]), \(monthNamesShort[parts[1] - 1]) \(parts[2])"
    }
}
