//
//  DayDetailView.swift
//  Tally
//
//  Review a past day: reads from materialized HabitDay + DaySummary (V2).

import SwiftUI
import SwiftData

struct DayDetailView: View {
    let dateString: String  // "YYYY-MM-DD"

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @Environment(AuthService.self) private var auth

    var body: some View {
        let c = TallyColors.resolve(colorScheme)
        let profileId = auth.userId ?? ""
        let resolved = resolveHabitDays(for: dateString, profileId: profileId, context: modelContext)
        let dateObj = dateFromKey(dateString)
        let dow = dayOfWeek(dateObj)

        let total = resolved.count
        let doneCount = resolved.filter { $0.isDone }.count
        let partialCount = resolved.filter { $0.status == "partial" }.count
        let overdueCount = resolved.filter { $0.status == "pending" }.count
        let pct = total > 0 ? Double(doneCount) / Double(total) : 0

        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("DAY REVIEW")
                        .font(TallyFont.label())
                        .textCase(.uppercase)
                        .tracking(1.2)
                        .foregroundStyle(c.dim)

                    if pct >= 1 {
                        Text("Day earned ✓")
                            .font(TallyFont.heading(32, weight: .medium))
                            .foregroundStyle(c.pos)
                    } else if total == 0 {
                        Text("Rest day")
                            .font(TallyFont.heading(32, weight: .medium))
                            .foregroundStyle(c.text)
                    } else {
                        HStack(spacing: 4) {
                            Text("\(doneCount) of \(total) ·")
                                .font(TallyFont.heading(32, weight: .medium))
                                .foregroundStyle(c.text)
                            Text("missed")
                                .font(TallyFont.heading(32, weight: .medium))
                                .foregroundStyle(c.neg)
                        }
                    }

                    Text("\(Int(pct * 100))% COMPLETION · \(doneCount) DONE · \(partialCount) PARTIAL · \(overdueCount) PENDING")
                        .font(TallyFont.mono(11))
                        .foregroundStyle(c.dim)
                }

                // Habit list
                if !resolved.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("HABITS · \(resolved.count)")
                            .font(TallyFont.label())
                            .textCase(.uppercase)
                            .tracking(1.2)
                            .foregroundStyle(c.dim)
                            .padding(.bottom, 4)

                        ForEach(resolved) { habit in
                            HStack(spacing: 10) {
                                StatusPip(status: habit.statusKind)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(habit.name)
                                        .font(TallyFont.heading(14, weight: .medium))
                                        .foregroundStyle(c.text)
                                    Text("\(habit.firstTime.uppercased()) · \(habit.label.uppercased())")
                                        .font(TallyFont.mono(10))
                                        .foregroundStyle(c.dim)
                                }
                                Spacer()
                                Text("\(Int(habit.pct * 100))%")
                                    .font(TallyFont.mono(11, weight: .semibold))
                                    .monospacedDigit()
                                    .foregroundStyle(habit.isDone ? c.pos : c.text)
                            }
                            .padding(.vertical, 12)
                            .overlay(alignment: .bottom) {
                                Rectangle().fill(c.rule).frame(height: 1)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .background(c.bg)
        .navigationTitle("\(dayNames[dow]) · \(monthNamesShort[Calendar.current.component(.month, from: dateObj) - 1]) \(Calendar.current.component(.day, from: dateObj))")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func dateFromKey(_ key: String) -> Date {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return Date() }
        return Calendar.current.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2])) ?? Date()
    }
}
