//
//  TaskDetailView.swift
//  Tally
//
//  Task detail: type-specific hero + log controls + today's entries with undo.
//  Ported from tally-today.jsx TaskDetail + TaskLogUI.

import SwiftUI
import SwiftData
import WidgetKit

struct TaskDetailView: View {
    let taskId: String

    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Query private var allEntries: [LogEntry]
    @Query private var tasks: [TallyTask]

    @State private var customValue: String = ""

    var body: some View {
        let c = TallyColors.resolve(colorScheme)
        let now = Date()
        let todayKey = localDateKey(now)

        if let task = tasks.first(where: { $0.id == taskId }) {
            let state = taskStateFor(task: task, date: startOfDay(now), entries: allEntries, now: now)
            let todayEntries = allEntries
                .filter { $0.taskId == taskId && $0.date == todayKey }
                .sorted { $0.time < $1.time }
            let sched = describeSchedule(task)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header info
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(sched.times.uppercased()) · \(sched.days.uppercased())")
                            .font(TallyFont.label())
                            .textCase(.uppercase)
                            .tracking(1.2)
                            .foregroundStyle(c.dim)
                        Text(task.name)
                            .font(TallyFont.heading(28, weight: .medium))
                            .foregroundStyle(c.text)
                    }

                    // Hero card
                    heroCard(task: task, state: state, c: c)

                    // Log controls
                    logControls(task: task, state: state, c: c, todayKey: todayKey, now: now)

                    // Today's entries
                    if !todayEntries.isEmpty {
                        todayEntriesList(task: task, entries: todayEntries, state: state, c: c)
                    }

                    // 14-day trend
                    miniTrend(task: task, now: now, c: c)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .background(c.bg)
            .navigationTitle(task.name)
            .navigationBarTitleDisplayMode(.inline)
        } else {
            Text("Task not found")
                .foregroundStyle(c.dim)
        }
    }

    // MARK: - Hero card

    @ViewBuilder
    private func heroCard(task: TallyTask, state: TaskStatus, c: TallyColors) -> some View {
        switch task.type {
        case .count, .timer:
            let sum = state.sum ?? 0
            let target = task.target ?? 1
            TallyCard {
                VStack(spacing: 4) {
                    Text(task.type == .timer ? "MINUTES TODAY" : "LOGGED TODAY")
                        .font(TallyFont.label())
                        .textCase(.uppercase)
                        .tracking(1.2)
                        .foregroundStyle(c.dim)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Spacer()
                        Text("\(Int(sum.rounded()))")
                            .font(TallyFont.heading(72, weight: .medium))
                            .monospacedDigit()
                            .foregroundStyle(state.status == .done ? c.pos : c.text)
                        Text("/ \(Int(target))")
                            .font(TallyFont.heading(24, weight: .medium))
                            .foregroundStyle(c.dim)
                        Spacer()
                    }

                    Text("\((task.unit ?? "").uppercased()) · \(Int(state.pct * 100))% COMPLETE")
                        .font(TallyFont.mono(11))
                        .foregroundStyle(c.dim)

                    ProgressBarView(pct: state.pct, height: 8, color: state.status == .done ? c.pos : c.accent)
                        .padding(.top, 8)
                }
            }

        case .check:
            TallyCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text("STATUS")
                        .font(TallyFont.label())
                        .textCase(.uppercase)
                        .tracking(1.2)
                        .foregroundStyle(c.dim)
                    Text(state.status == .done ? "Done ✓" : state.status == .overdue ? "Overdue" : "Pending")
                        .font(TallyFont.heading(40, weight: .medium))
                        .foregroundStyle(state.status == .done ? c.pos : c.text)
                }
            }

        case .yesno:
            TallyCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text("TODAY'S ANSWER")
                        .font(TallyFont.label())
                        .textCase(.uppercase)
                        .tracking(1.2)
                        .foregroundStyle(c.dim)
                    Text(state.label == "—" ? "—" : state.label)
                        .font(TallyFont.heading(40, weight: .medium))
                        .foregroundStyle(state.status == .done ? c.pos : c.text)
                }
            }

        case .numeric:
            TallyCard {
                VStack(alignment: .leading, spacing: 10) {
                    Text("LATEST READING")
                        .font(TallyFont.label())
                        .textCase(.uppercase)
                        .tracking(1.2)
                        .foregroundStyle(c.dim)
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(state.value != nil ? String(format: "%.1f", state.value!) : "—")
                            .font(TallyFont.heading(56, weight: .medium))
                            .monospacedDigit()
                            .foregroundStyle(state.status == .done ? c.pos : c.text)
                        Text(task.unit ?? "")
                            .font(TallyFont.heading(20, weight: .medium))
                            .foregroundStyle(c.dim)
                    }
                }
            }
        }
    }

    // MARK: - Log controls

    @ViewBuilder
    private func logControls(task: TallyTask, state: TaskStatus, c: TallyColors, todayKey: String, now: Date) -> some View {
        switch task.type {
        case .count:
            VStack(alignment: .leading, spacing: 8) {
                Text("QUICK LOG · TAP TO ADD")
                    .font(TallyFont.label())
                    .textCase(.uppercase)
                    .tracking(1.2)
                    .foregroundStyle(c.dim)
                PresetChipGrid(values: pickPresets(for: task), unit: task.unit) { value in
                    logValue(value, taskId: task.id, date: todayKey, now: now)
                }
                customInput(unit: task.unit ?? "", c: c) { value in
                    logValue(value, taskId: task.id, date: todayKey, now: now)
                }
            }

        case .timer:
            VStack(alignment: .leading, spacing: 8) {
                Text("ADD MINUTES")
                    .font(TallyFont.label())
                    .textCase(.uppercase)
                    .tracking(1.2)
                    .foregroundStyle(c.dim)
                PresetChipGrid(values: [5, 10, 15, task.target ?? 20], unit: "min") { value in
                    logValue(value, taskId: task.id, date: todayKey, now: now)
                }
                customInput(unit: "min", c: c) { value in
                    logValue(value, taskId: task.id, date: todayKey, now: now)
                }
            }

        case .check:
            Button {
                if state.status != .done {
                    logValue(1.0, taskId: task.id, date: todayKey, now: now)
                }
            } label: {
                HStack {
                    if state.status == .done {
                        Text("Already done · tap log to undo")
                    } else {
                        Image(systemName: "checkmark")
                        Text("Mark complete")
                    }
                }
                .font(TallyFont.heading(14, weight: .medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(state.status == .done ? c.bg2 : c.accent)
                .foregroundStyle(state.status == .done ? c.text : .white)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(state.status == .done ? c.rule : Color.clear, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

        case .yesno:
            HStack(spacing: 8) {
                yesNoButton(label: "Yes", isActive: state.label == "Yes", c: c) {
                    logValue(1.0, taskId: task.id, date: todayKey, now: now)
                }
                yesNoButton(label: "No", isActive: state.label == "No", c: c) {
                    logValue(0.0, taskId: task.id, date: todayKey, now: now)
                }
            }

        case .numeric:
            VStack(alignment: .leading, spacing: 8) {
                Text("ENTER READING")
                    .font(TallyFont.label())
                    .textCase(.uppercase)
                    .tracking(1.2)
                    .foregroundStyle(c.dim)
                HStack(spacing: 8) {
                    HStack(alignment: .firstTextBaseline) {
                        TextField("0.0", text: $customValue)
                            .keyboardType(.decimalPad)
                            .font(TallyFont.mono(28, weight: .semibold))
                            .foregroundStyle(c.text)
                        Text((task.unit ?? "").uppercased())
                            .font(TallyFont.mono(13))
                            .foregroundStyle(c.dim)
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
                    .background(c.bg2)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(c.rule, lineWidth: 1))

                    Button("SAVE") {
                        if let v = Double(customValue) {
                            logValue(v, taskId: task.id, date: todayKey, now: now)
                            customValue = ""
                        }
                    }
                    .font(TallyFont.heading(14, weight: .medium))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 16)
                    .background(c.accent)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .disabled(Double(customValue) == nil)
                }
            }
        }
    }

    // MARK: - Today's entries list

    private func todayEntriesList(task: TallyTask, entries: [LogEntry], state: TaskStatus, c: TallyColors) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("TODAY · \(entries.count) \(task.type == .count ? "SETS" : (entries.count == 1 ? "ENTRY" : "ENTRIES"))")
                    .font(TallyFont.label())
                    .textCase(.uppercase)
                    .tracking(1.2)
                    .foregroundStyle(c.dim)
                Spacer()
                Text("TAP TO UNDO")
                    .font(TallyFont.mono(10))
                    .foregroundStyle(c.dim)
            }
            .padding(.bottom, 4)

            ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                Button {
                    undoEntry(entry)
                } label: {
                    HStack(spacing: 8) {
                        Text(String(format: "%02d", index + 1))
                            .font(TallyFont.mono(11))
                            .foregroundStyle(c.dim)
                            .frame(width: 24)
                        Text(entry.time)
                            .font(TallyFont.mono(11))
                            .foregroundStyle(c.dim)
                        Spacer()
                        Text(entryValueText(task: task, entry: entry))
                            .font(TallyFont.mono(14, weight: .semibold))
                            .foregroundStyle(c.text)
                        Text((task.unit ?? "").uppercased())
                            .font(TallyFont.mono(10))
                            .foregroundStyle(c.dim)
                            .frame(width: 36, alignment: .trailing)
                    }
                    .padding(.vertical, 10)
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(c.rule).frame(height: 1)
                    }
                }
                .buttonStyle(.plain)
            }

            // Total row for count/timer
            if task.type == .count || task.type == .timer {
                HStack(spacing: 8) {
                    Text("Σ")
                        .font(TallyFont.mono(11, weight: .semibold))
                        .frame(width: 24)
                    Text("TOTAL")
                        .font(TallyFont.mono(11))
                        .foregroundStyle(c.dim)
                    Spacer()
                    Text("\(Int((state.sum ?? 0).rounded()))")
                        .font(TallyFont.mono(15, weight: .semibold))
                        .foregroundStyle(state.status == .done ? c.pos : c.accent)
                    Text((task.unit ?? "").uppercased())
                        .font(TallyFont.mono(10))
                        .foregroundStyle(c.dim)
                        .frame(width: 36, alignment: .trailing)
                }
                .padding(.vertical, 12)
            }
        }
    }

    // MARK: - 14-day mini trend

    private func miniTrend(task: TallyTask, now: Date, c: TallyColors) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("LAST 14 DAYS")
                .font(TallyFont.label())
                .textCase(.uppercase)
                .tracking(1.2)
                .foregroundStyle(c.dim)

            HStack(alignment: .bottom, spacing: 3) {
                ForEach(0..<14, id: \.self) { i in
                    let d = addDays(now, -(13 - i))
                    let state = taskStateFor(task: task, date: d, entries: allEntries, now: now)
                    VStack(spacing: 2) {
                        if i == 13 {
                            Text("TODAY")
                                .font(TallyFont.mono(8, weight: .semibold))
                                .foregroundStyle(c.dim)
                        }
                        RoundedRectangle(cornerRadius: 2)
                            .fill(state.pct >= 1 ? c.accent : state.pct > 0 ? c.accentSoft : c.dim3)
                            .frame(height: max(CGFloat(state.pct), 0.05) * 50)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 64)
        }
    }

    // MARK: - Helpers

    private func logValue(_ value: Double, taskId: String, date: String, now: Date) {
        let entry = LogEntry(taskId: taskId, date: date, time: localTimeKey(now), value: value)
        modelContext.insert(entry)
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func undoEntry(_ entry: LogEntry) {
        modelContext.delete(entry)
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func entryValueText(task: TallyTask, entry: LogEntry) -> String {
        switch task.type {
        case .check, .yesno:
            return "✓"
        case .numeric:
            return String(format: "%.1f", entry.value)
        case .count, .timer:
            return "+\(Int(entry.value))"
        }
    }

    private func customInput(unit: String, c: TallyColors, onLog: @escaping (Double) -> Void) -> some View {
        HStack(spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                TextField("0", text: $customValue)
                    .keyboardType(.decimalPad)
                    .font(TallyFont.mono(18, weight: .semibold))
                    .foregroundStyle(c.text)
                Text(unit.uppercased())
                    .font(TallyFont.mono(11))
                    .foregroundStyle(c.dim)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(c.bg2)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(c.rule, lineWidth: 1))

            Button {
                if let v = Double(customValue), v > 0 {
                    onLog(v)
                    customValue = ""
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                    Text("LOG")
                }
                .font(TallyFont.heading(14, weight: .medium))
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(c.accent)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .disabled(Double(customValue) == nil || (Double(customValue) ?? 0) <= 0)
        }
    }

    private func yesNoButton(label: String, isActive: Bool, c: TallyColors, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(TallyFont.heading(14, weight: .medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(isActive ? c.accent : c.bg2)
                .foregroundStyle(isActive ? .white : c.text)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isActive ? Color.clear : c.rule, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}
