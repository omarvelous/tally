//
//  LogSheet.swift
//  Tally
//
//  Bottom-sheet modal logging surface. Replaces the v1 full-screen TaskDetailView.
//  Pinned footer keeps log controls at a fixed position.

import SwiftUI
import SwiftData
import WidgetKit

struct LogSheet: View {
    let taskId: String

    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @Query private var tasks: [TallyTask]
    @Query private var allEntries: [LogEntry]

    @State private var stagedValue: String = ""
    @State private var deleteTarget: LogEntry?

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

            NavigationStack {
                VStack(spacing: 0) {
                    // Scrollable content
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            // Schedule + status
                            VStack(alignment: .leading, spacing: 4) {
                                Text(verbatim: "\(sched.times.uppercased()) · \(sched.days.uppercased())")
                                    .font(TallyFont.label())
                                    .textCase(.uppercase)
                                    .tracking(1.2)
                                    .foregroundStyle(c.dim)
                                HStack {
                                    Text(task.name)
                                        .font(TallyFont.heading(24, weight: .medium))
                                        .foregroundStyle(c.text)
                                    Spacer()
                                    statusPill(state: state, c: c)
                                }
                            }

                            // Hero card
                            TaskHeroCard(task: task, state: state)

                            // Today's entries (swipe-to-delete)
                            if !todayEntries.isEmpty {
                                entriesList(task: task, entries: todayEntries, state: state, c: c)
                            }

                            // 14-day trend
                            miniTrend(task: task, now: now, c: c)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .padding(.bottom, 16)
                    }

                    // Pinned footer — log controls
                    Divider()
                    logFooter(task: task, state: state, todayKey: todayKey, now: now, c: c)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(c.bg)
                }
                .background(c.bg)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("CLOSE") { dismiss() }
                            .font(TallyFont.mono(11))
                            .foregroundStyle(c.dim)
                    }
                }
            }
            .confirmationDialog(
                deleteConfirmTitle,
                isPresented: Binding(get: { deleteTarget != nil }, set: { if !$0 { deleteTarget = nil } }),
                titleVisibility: .visible
            ) {
                Button("Delete entry", role: .destructive) {
                    if let entry = deleteTarget {
                        modelContext.delete(entry)
                        WidgetCenter.shared.reloadAllTimelines()
                        deleteTarget = nil
                    }
                }
            }
        } else {
            Text("Task not found")
                .foregroundStyle(TallyColors.resolve(colorScheme).dim)
        }
    }

    private var deleteConfirmTitle: String {
        guard let entry = deleteTarget, let task = tasks.first(where: { $0.id == taskId }) else { return "Delete this entry?" }
        let valueStr: String
        switch task.type {
        case .check, .yesno: valueStr = "✓"
        case .numeric: valueStr = String(format: "%.1f", entry.value)
        case .count, .timer: valueStr = "+\(Int(entry.value))"
        }
        return "Delete this entry? · \(entry.time) · \(valueStr) \(task.unit ?? "")"
    }

    // MARK: - Status pill

    private func statusPill(state: TaskStatus, c: TallyColors) -> some View {
        let color: Color = state.status == .done ? c.pos : state.status == .overdue ? c.neg : state.status == .partial ? c.accent : c.dim2
        return Text(verbatim: "\(Int(state.pct * 100))%")
            .font(TallyFont.mono(11, weight: .semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }

    // MARK: - Entries list with swipe-to-delete

    private func entriesList(task: TallyTask, entries: [LogEntry], state: TaskStatus, c: TallyColors) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(verbatim: "TODAY · \(entries.count) \(task.type == .count ? "SETS" : (entries.count == 1 ? "ENTRY" : "ENTRIES"))")
                .font(TallyFont.label())
                .textCase(.uppercase)
                .tracking(1.2)
                .foregroundStyle(c.dim)
                .padding(.bottom, 4)

            ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                SwipeableRow(pillLabel: "DELETE", pillColor: c.neg) {
                    deleteTarget = entry
                } content: {
                    HStack(spacing: 8) {
                        Text(verbatim: String(format: "%02d", index + 1))
                            .font(TallyFont.mono(11))
                            .foregroundStyle(c.dim)
                            .frame(width: 24)
                        Text(verbatim: entry.time)
                            .font(TallyFont.mono(11))
                            .foregroundStyle(c.dim)
                        Spacer()
                        Text(verbatim: entryValueText(task: task, entry: entry))
                            .font(TallyFont.mono(14, weight: .semibold))
                            .foregroundStyle(c.text)
                        Text(verbatim: (task.unit ?? "").uppercased())
                            .font(TallyFont.mono(10))
                            .foregroundStyle(c.dim)
                            .frame(width: 36, alignment: .trailing)
                    }
                    .padding(.vertical, 10)
                    .background(c.bg)
                }
                .overlay(alignment: .bottom) {
                    Rectangle().fill(c.rule).frame(height: 1)
                }
            }

            // Total for count/timer
            if task.type == .count || task.type == .timer {
                HStack(spacing: 8) {
                    Text("Σ")
                        .font(TallyFont.mono(11, weight: .semibold))
                        .frame(width: 24)
                    Text("TOTAL")
                        .font(TallyFont.mono(11))
                        .foregroundStyle(c.dim)
                    Spacer()
                    Text(verbatim: "\(Int((state.sum ?? 0).rounded()))")
                        .font(TallyFont.mono(15, weight: .semibold))
                        .foregroundStyle(state.status == .done ? c.pos : c.accent)
                    Text(verbatim: (task.unit ?? "").uppercased())
                        .font(TallyFont.mono(10))
                        .foregroundStyle(c.dim)
                        .frame(width: 36, alignment: .trailing)
                }
                .padding(.vertical, 12)
            }
        }
    }

    // MARK: - Pinned footer (log controls)

    @ViewBuilder
    private func logFooter(task: TallyTask, state: TaskStatus, todayKey: String, now: Date, c: TallyColors) -> some View {
        switch task.type {
        case .count, .timer:
            VStack(alignment: .leading, spacing: 8) {
                Text(task.type == .count ? "QUICK ADD" : "ADD MINUTES")
                    .font(TallyFont.label())
                    .textCase(.uppercase)
                    .tracking(1.2)
                    .foregroundStyle(c.dim)

                let presets = task.type == .count ? pickPresets(for: task) : [5, 10, 15, task.target ?? 20]
                PresetChipGrid(values: presets, unit: task.unit, selectedValue: Double(stagedValue)) { value in
                    stagedValue = "\(Int(value))"
                }

                // Editable input + LOG button
                HStack(spacing: 8) {
                    HStack(alignment: .firstTextBaseline) {
                        TextField("0", text: $stagedValue)
                            .keyboardType(.decimalPad)
                            .font(TallyFont.mono(18, weight: .semibold))
                            .foregroundStyle(c.text)
                        Text(verbatim: (task.unit ?? (task.type == .timer ? "min" : "")).uppercased())
                            .font(TallyFont.mono(11))
                            .foregroundStyle(c.dim)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(c.bg2)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(stagedValue.isEmpty ? c.rule : c.accent, lineWidth: 1))

                    Spacer()
                }

                Button {
                    if let v = Double(stagedValue), v > 0 {
                        logValue(v, taskId: task.id, date: todayKey, now: now)
                        stagedValue = ""
                    }
                } label: {
                    Text(verbatim: stagedValue.isEmpty ? "LOG" : "LOG +\(stagedValue)")
                        .font(TallyFont.heading(14, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background((Double(stagedValue) ?? 0) > 0 ? c.accent : c.dim3)
                        .foregroundStyle((Double(stagedValue) ?? 0) > 0 ? .white : c.dim)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .disabled((Double(stagedValue) ?? 0) <= 0)
            }

        case .check:
            Button {
                if state.status != .done {
                    logValue(1.0, taskId: task.id, date: todayKey, now: now)
                }
            } label: {
                HStack {
                    if state.status == .done {
                        Text("Already done")
                    } else {
                        Image(systemName: "checkmark")
                        Text("Mark complete")
                    }
                }
                .font(TallyFont.heading(14, weight: .medium))
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(state.status == .done ? c.bg3 : c.accent)
                .foregroundStyle(state.status == .done ? c.dim : .white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .disabled(state.status == .done)

        case .yesno:
            VStack(alignment: .leading, spacing: 8) {
                Text("TODAY'S ANSWER")
                    .font(TallyFont.label())
                    .textCase(.uppercase)
                    .tracking(1.2)
                    .foregroundStyle(c.dim)
                HStack(spacing: 8) {
                    yesNoButton(label: "Yes", isActive: state.label == "Yes", c: c) {
                        logValue(1.0, taskId: task.id, date: todayKey, now: now)
                    }
                    yesNoButton(label: "No", isActive: state.label == "No", c: c) {
                        logValue(0.0, taskId: task.id, date: todayKey, now: now)
                    }
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
                        TextField("0.0", text: $stagedValue)
                            .keyboardType(.decimalPad)
                            .font(TallyFont.mono(28, weight: .semibold))
                            .foregroundStyle(c.text)
                        Text(verbatim: (task.unit ?? "").uppercased())
                            .font(TallyFont.mono(13))
                            .foregroundStyle(c.dim)
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
                    .background(c.bg2)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(c.rule, lineWidth: 1))
                }
                Button {
                    if let v = Double(stagedValue) {
                        logValue(v, taskId: task.id, date: todayKey, now: now)
                        stagedValue = ""
                    }
                } label: {
                    Text("SAVE")
                        .font(TallyFont.heading(14, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Double(stagedValue) != nil ? c.accent : c.dim3)
                        .foregroundStyle(Double(stagedValue) != nil ? .white : c.dim)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .disabled(Double(stagedValue) == nil)
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
                    let s = taskStateFor(task: task, date: d, entries: allEntries, now: now)
                    VStack(spacing: 2) {
                        if i == 13 {
                            Text("TODAY")
                                .font(TallyFont.mono(8, weight: .semibold))
                                .foregroundStyle(c.dim)
                        }
                        RoundedRectangle(cornerRadius: 2)
                            .fill(s.pct >= 1 ? c.accent : s.pct > 0 ? c.accentSoft : c.dim3)
                            .frame(height: max(CGFloat(s.pct), 0.05) * 50)
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

    private func entryValueText(task: TallyTask, entry: LogEntry) -> String {
        switch task.type {
        case .check, .yesno: return "✓"
        case .numeric: return String(format: "%.1f", entry.value)
        case .count, .timer: return "+\(Int(entry.value))"
        }
    }

    private func yesNoButton(label: String, isActive: Bool, c: TallyColors, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(TallyFont.heading(14, weight: .medium))
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(isActive ? c.accent : c.bg2)
                .foregroundStyle(isActive ? .white : c.text)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isActive ? Color.clear : c.rule, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}
