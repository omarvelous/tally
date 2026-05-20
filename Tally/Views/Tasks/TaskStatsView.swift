//
//  TaskStatsView.swift
//  Tally
//
//  Per-task stats: 30-day bar chart, stat tiles, hourly heatmap, recent entries.

import SwiftUI
import SwiftData

struct TaskStatsView: View {
    let taskId: String

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(LogSheetCoordinator.self) private var logCoordinator
    @Query private var tasks: [TallyTask]
    @Query private var allEntries: [LogEntry]

    @State private var showEditSheet = false
    @State private var showDeleteConfirm = false

    var body: some View {
        let c = TallyColors.resolve(colorScheme)
        let now = Date()

        if let task = tasks.first(where: { $0.id == taskId }) {
            let sched = describeSchedule(task)
            let stats = computeStats(task: task, now: now)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(task.name.uppercased()) · 30 DAYS")
                            .font(TallyFont.label())
                            .textCase(.uppercase)
                            .tracking(1.2)
                            .foregroundStyle(c.dim)
                        Text(task.name)
                            .font(TallyFont.heading(28, weight: .medium))
                            .foregroundStyle(c.text)
                        Text("\(sched.days.uppercased()) · \(task.type.rawValue.uppercased())\(task.target != nil ? " · TARGET \(Int(task.target!)) \(task.unit ?? "")" : "")")
                            .font(TallyFont.mono(11))
                            .foregroundStyle(c.dim)
                    }

                    // 30-day bar chart
                    barChart(task: task, series: stats.series, best: stats.best, c: c)

                    // Stat tiles
                    statTiles(task: task, stats: stats, c: c)

                    // Hourly heatmap (count/timer only)
                    if task.type == .count || task.type == .timer {
                        hourlyHeatmap(taskId: task.id, c: c)
                    }

                    // Recent entries
                    recentEntries(task: task, c: c)

                    // MANAGE section
                    manageSection(task: task, c: c)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .background(c.bg)
            .navigationTitle(task.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        logCoordinator.open(task.id)
                    } label: {
                        Text("+ LOG")
                            .font(TallyFont.mono(11, weight: .semibold))
                            .foregroundStyle(c.accent)
                    }
                }
            }
            .sheet(isPresented: $showEditSheet) {
                TaskFormView(taskId: task.id)
            }
            .confirmationDialog("Delete \"\(task.name)\"?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button("Delete task & all history", role: .destructive) {
                    deleteTask(task)
                }
            } message: {
                Text("All log entries for this task will be permanently removed.")
            }
        } else {
            Text("Task not found")
        }
    }

    // MARK: - Stats computation

    private struct Stats {
        let series: [(Date, TaskStatus)]
        let scheduled: Int
        let onTarget: Int
        let rate: Int
        let avg: Double
        let best: Double
        let total: Double
        let sumValues: [Double]
    }

    private func computeStats(task: TallyTask, now: Date) -> Stats {
        var series: [(Date, TaskStatus)] = []
        for i in stride(from: 29, through: 0, by: -1) {
            let d = addDays(now, -i)
            let s = taskStateFor(task: task, date: d, entries: allEntries, now: now)
            series.append((d, s))
        }
        let scheduled = series.filter { $0.1.status != .off }
        let onTarget = scheduled.filter { $0.1.status == .done }.count
        let sumValues = scheduled.compactMap { s -> Double? in
            s.1.sum ?? s.1.value ?? (s.1.status == .done ? 1 : nil)
        }
        let total = sumValues.reduce(0, +)
        let avg = sumValues.isEmpty ? 0 : total / Double(sumValues.count)
        let best = sumValues.max() ?? 0
        let rate = scheduled.isEmpty ? 0 : Int((Double(onTarget) / Double(scheduled.count) * 100).rounded())

        return Stats(series: series, scheduled: scheduled.count, onTarget: onTarget, rate: rate, avg: avg, best: best, total: total, sumValues: sumValues)
    }

    // MARK: - Bar chart

    private func barChart(task: TallyTask, series: [(Date, TaskStatus)], best: Double, c: TallyColors) -> some View {
        TallyCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(task.type == .count || task.type == .timer ? "DAILY TOTAL" : task.type == .numeric ? "DAILY VALUE" : "DAILY COMPLETION")
                        .font(TallyFont.label())
                        .textCase(.uppercase)
                        .tracking(1.2)
                        .foregroundStyle(c.dim)
                    Spacer()
                    if let target = task.target {
                        Text("GOAL · \(Int(target))")
                            .font(TallyFont.mono(11))
                            .foregroundStyle(c.dim)
                    }
                }

                HStack(alignment: .bottom, spacing: 2) {
                    ForEach(Array(series.enumerated()), id: \.offset) { i, item in
                        let (_, state) = item
                        let isToday = i == series.count - 1
                        let off = state.status == .off
                        let h = barHeight(task: task, state: state, off: off, best: best)
                        let color = off ? c.dim3 : state.status == .done ? c.accent : state.status == .partial ? c.accentSoft : state.status == .overdue ? c.neg : c.dim3

                        VStack(spacing: 0) {
                            if isToday {
                                Text("NOW")
                                    .font(TallyFont.mono(8, weight: .semibold))
                                    .foregroundStyle(c.text)
                            }
                            Spacer()
                            RoundedRectangle(cornerRadius: 2)
                                .fill(color)
                                .frame(height: max(h, 4))
                                .opacity(isToday ? 1 : 0.85)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 140)

                HStack {
                    Text("−30D").font(TallyFont.mono(10)).foregroundStyle(c.dim)
                    Spacer()
                    Text("−15D").font(TallyFont.mono(10)).foregroundStyle(c.dim)
                    Spacer()
                    Text("TODAY").font(TallyFont.mono(10)).foregroundStyle(c.dim)
                }
            }
        }
    }

    private func barHeight(task: TallyTask, state: TaskStatus, off: Bool, best: Double) -> CGFloat {
        if off { return 6 }
        switch task.type {
        case .count, .timer:
            return min(CGFloat(state.pct), 1.0) * 130
        case .numeric:
            if let v = state.value, best > 0 {
                return CGFloat(v / best) * 100 + 14
            }
            return 6
        default:
            return state.status == .done ? 130 : state.pct > 0 ? 65 : 6
        }
    }

    // MARK: - Stat tiles

    @ViewBuilder
    private func statTiles(task: TallyTask, stats: Stats, c: TallyColors) -> some View {
        let columns = [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]
        LazyVGrid(columns: columns, spacing: 8) {
            switch task.type {
            case .count, .timer:
                StatTile(label: "AVERAGE / DAY", value: "\(Int(stats.avg.rounded())) \(task.unit ?? "")")
                StatTile(label: "BEST DAY", value: "\(Int(stats.best.rounded())) \(task.unit ?? "")")
                StatTile(label: "TOTAL · 30D", value: "\(Int(stats.total.rounded()))\(task.unit != nil ? " \(task.unit!)" : "")")
                StatTile(label: "ON TARGET", value: "\(stats.onTarget) / \(stats.scheduled) days")
            case .numeric:
                StatTile(label: "LATEST", value: "\(stats.sumValues.last != nil ? String(format: "%.1f", stats.sumValues.last!) : "—") \(task.unit ?? "")")
                StatTile(label: "AVERAGE", value: "\(String(format: "%.1f", stats.avg)) \(task.unit ?? "")")
                StatTile(label: "LOG RATE", value: "\(stats.rate)%")
                StatTile(label: "ENTRIES", value: "\(stats.sumValues.count)")
            default:
                StatTile(label: "COMPLETION", value: "\(stats.rate)%")
                StatTile(label: "DONE", value: "\(stats.onTarget) / \(stats.scheduled)")
            }
        }
    }

    // MARK: - Hourly heatmap

    private func hourlyHeatmap(taskId: String, c: TallyColors) -> some View {
        let entries = allEntries.filter { $0.taskId == taskId && !$0.deleted }
        var byHour = Array(repeating: 0, count: 24)
        for e in entries {
            let h = parseHHMM(e.time).h
            if h >= 0 && h < 24 { byHour[h] += 1 }
        }
        let maxHour = max(byHour.max() ?? 1, 1)

        return VStack(alignment: .leading, spacing: 8) {
            Text("WHEN YOU LOG · HOUR DENSITY")
                .font(TallyFont.label())
                .textCase(.uppercase)
                .tracking(1.2)
                .foregroundStyle(c.dim)

            HStack(spacing: 1) {
                ForEach(0..<24, id: \.self) { h in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(byHour[h] == 0 ? c.dim3 : c.accent)
                        .opacity(byHour[h] == 0 ? 1 : 0.3 + Double(byHour[h]) / Double(maxHour) * 0.7)
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 28)

            HStack {
                Text("00").font(TallyFont.mono(9)).foregroundStyle(c.dim)
                Spacer()
                Text("06").font(TallyFont.mono(9)).foregroundStyle(c.dim)
                Spacer()
                Text("12").font(TallyFont.mono(9)).foregroundStyle(c.dim)
                Spacer()
                Text("18").font(TallyFont.mono(9)).foregroundStyle(c.dim)
                Spacer()
                Text("24").font(TallyFont.mono(9)).foregroundStyle(c.dim)
            }
        }
    }

    // MARK: - Recent entries

    private func recentEntries(task: TallyTask, c: TallyColors) -> some View {
        let recent = allEntries
            .filter { $0.taskId == task.id && !$0.deleted }
            .sorted { $0.ts > $1.ts }
            .prefix(8)

        return VStack(alignment: .leading, spacing: 4) {
            Text("RECENT ENTRIES")
                .font(TallyFont.label())
                .textCase(.uppercase)
                .tracking(1.2)
                .foregroundStyle(c.dim)

            if recent.isEmpty {
                Text("No entries yet.")
                    .font(TallyFont.body(13))
                    .foregroundStyle(c.dim)
                    .padding(.vertical, 12)
            } else {
                ForEach(Array(recent), id: \.id) { entry in
                    HStack(spacing: 8) {
                        Text(entry.date)
                            .font(TallyFont.mono(10))
                            .foregroundStyle(c.dim)
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
            }
        }
    }

    private func entryValueText(task: TallyTask, entry: LogEntry) -> String {
        switch task.type {
        case .check, .yesno: return entry.value >= 1 ? "✓" : "✗"
        case .numeric: return String(format: "%.1f", entry.value)
        case .count, .timer: return "+\(Int(entry.value))"
        }
    }

    // MARK: - Manage section

    private func manageSection(task: TallyTask, c: TallyColors) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("MANAGE")
                .font(TallyFont.label())
                .textCase(.uppercase)
                .tracking(1.2)
                .foregroundStyle(c.dim)
                .padding(.bottom, 8)

            manageRow("Edit task", icon: "pencil", c: c) {
                showEditSheet = true
            }
            manageRow(task.archived ? "Restore task" : "Archive task", icon: "archivebox", c: c) {
                task.archived.toggle()
                task.updatedAt = Date().timeIntervalSince1970 * 1000
                try? modelContext.save()
                reloadWidgets()
                dismiss()
            }
            manageRow("Delete task", icon: "trash", c: c, danger: true) {
                showDeleteConfirm = true
            }
        }
    }

    private func manageRow(_ label: String, icon: String, c: TallyColors, danger: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(danger ? c.neg : c.dim)
                    .frame(width: 20)
                Text(label)
                    .font(TallyFont.heading(14, weight: .medium))
                    .foregroundStyle(danger ? c.neg : c.text)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundStyle(c.dim)
            }
            .padding(.vertical, 13)
            .overlay(alignment: .bottom) {
                Rectangle().fill(c.rule).frame(height: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private func deleteTask(_ task: TallyTask) {
        deleteTaskAndEntries(taskId: task.id, context: modelContext)
        dismiss()
    }
}
