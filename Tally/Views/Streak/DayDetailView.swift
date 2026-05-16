//
//  DayDetailView.swift
//  Tally
//
//  Review a past day: earned/missed status, task list, full log entries.

import SwiftUI
import SwiftData

struct DayDetailView: View {
    let dateString: String  // "YYYY-MM-DD"

    @Environment(\.colorScheme) private var colorScheme
    @Query(filter: #Predicate<TallyTask> { !$0.archived }) private var tasks: [TallyTask]
    @Query private var allEntries: [LogEntry]

    var body: some View {
        let c = TallyColors.resolve(colorScheme)
        let now = Date()
        let dateObj = dateFromKey(dateString)
        let dow = dayOfWeek(dateObj)
        let day = dayCompletionFor(date: dateObj, tasks: tasks, entries: allEntries, now: now)
        let scheduled = tasks.filter { $0.isScheduled(on: dow) }
        let dayLog = allEntries.filter { $0.date == dateString }.sorted { $0.time < $1.time }

        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("DAY REVIEW")
                        .font(TallyFont.label())
                        .textCase(.uppercase)
                        .tracking(1.2)
                        .foregroundStyle(c.dim)

                    if day.pct >= 1 {
                        Text("Day earned ✓")
                            .font(TallyFont.heading(32, weight: .medium))
                            .foregroundStyle(c.pos)
                    } else if day.total == 0 {
                        Text("Rest day")
                            .font(TallyFont.heading(32, weight: .medium))
                            .foregroundStyle(c.text)
                    } else {
                        HStack(spacing: 4) {
                            Text("\(day.done) of \(day.total) ·")
                                .font(TallyFont.heading(32, weight: .medium))
                                .foregroundStyle(c.text)
                            Text("missed")
                                .font(TallyFont.heading(32, weight: .medium))
                                .foregroundStyle(c.neg)
                        }
                    }

                    Text("\(Int(day.pct * 100))% COMPLETION · \(day.done) DONE · \(day.partial) PARTIAL · \(day.overdue) OVERDUE")
                        .font(TallyFont.mono(11))
                        .foregroundStyle(c.dim)
                }

                // Task list
                if !scheduled.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("TASKS · \(scheduled.count)")
                            .font(TallyFont.label())
                            .textCase(.uppercase)
                            .tracking(1.2)
                            .foregroundStyle(c.dim)
                            .padding(.bottom, 4)

                        ForEach(scheduled, id: \.id) { task in
                            let state = taskStateFor(task: task, date: dateObj, entries: allEntries, now: now)
                            HStack(spacing: 10) {
                                StatusPip(status: state.status)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(task.name)
                                        .font(TallyFont.heading(14, weight: .medium))
                                        .foregroundStyle(c.text)
                                    Text("\(task.times.joined(separator: " · ").uppercased()) · \(state.label.uppercased())")
                                        .font(TallyFont.mono(10))
                                        .foregroundStyle(c.dim)
                                }
                                Spacer()
                                Text("\(Int(state.pct * 100))%")
                                    .font(TallyFont.mono(11, weight: .semibold))
                                    .monospacedDigit()
                                    .foregroundStyle(state.status == .done ? c.pos : state.status == .overdue ? c.neg : c.text)
                            }
                            .padding(.vertical, 12)
                            .overlay(alignment: .bottom) {
                                Rectangle().fill(c.rule).frame(height: 1)
                            }
                        }
                    }
                }

                // Log entries
                if !dayLog.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("\(dayLog.count) ENTRIES")
                            .font(TallyFont.label())
                            .textCase(.uppercase)
                            .tracking(1.2)
                            .foregroundStyle(c.dim)
                            .padding(.bottom, 4)

                        ForEach(dayLog, id: \.id) { entry in
                            let task = tasks.first { $0.id == entry.taskId }
                            HStack(spacing: 10) {
                                Text(entry.time)
                                    .font(TallyFont.mono(11))
                                    .foregroundStyle(c.dim)
                                    .frame(width: 40)
                                Text(task?.name ?? "—")
                                    .font(TallyFont.body(13, weight: .medium))
                                    .foregroundStyle(c.text)
                                Spacer()
                                Text(entryValueText(task: task, entry: entry))
                                    .font(TallyFont.mono(13, weight: .semibold))
                                    .foregroundStyle(c.text)
                                if let unit = task?.unit {
                                    Text(unit)
                                        .font(TallyFont.mono(10))
                                        .foregroundStyle(c.dim)
                                }
                            }
                            .padding(.vertical, 10)
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

    private func entryValueText(task: TallyTask?, entry: LogEntry) -> String {
        guard let task = task else { return String(format: "%.1f", entry.value) }
        switch task.type {
        case .check, .yesno: return entry.value >= 1 ? "✓" : "✗"
        case .numeric: return String(format: "%.1f", entry.value)
        case .count, .timer: return "+\(Int(entry.value))"
        }
    }

    private func dateFromKey(_ key: String) -> Date {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return Date() }
        return Calendar.current.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2])) ?? Date()
    }
}
