//
//  TasksScreen.swift
//  Tally
//
//  Tasks library: all tasks ranked by 14-day completion rate.

import SwiftUI
import SwiftData

struct TasksScreen: View {
    @Environment(\.colorScheme) private var colorScheme
    @Query(filter: #Predicate<TallyTask> { !$0.archived }) private var tasks: [TallyTask]
    @Query private var allEntries: [LogEntry]

    @State private var sortBy: SortOption = .rate
    @State private var showAddTask = false

    enum SortOption: String {
        case rate, name
    }

    var body: some View {
        let c = TallyColors.resolve(colorScheme)
        let now = Date()

        let rated = tasks.map { task -> (TallyTask, [Double], Int) in
            let hist = taskHistoryFor(task: task, entries: allEntries, now: now)
            let rate = hist.isEmpty ? 0 : Int((hist.reduce(0, +) / Double(hist.count) * 100).rounded())
            return (task, hist, rate)
        }

        let sorted = rated.sorted { a, b in
            switch sortBy {
            case .rate: return a.2 > b.2
            case .name: return a.0.name.localizedCompare(b.0.name) == .orderedAscending
            }
        }

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Header
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("LIBRARY · \(tasks.count) ACTIVE")
                                .font(TallyFont.label())
                                .textCase(.uppercase)
                                .tracking(1.2)
                                .foregroundStyle(c.dim)
                            Text("Tasks")
                                .font(TallyFont.heading(32, weight: .medium))
                                .foregroundStyle(c.text)
                        }
                        Spacer()
                        Button {
                            showAddTask = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "plus")
                                Text("NEW")
                            }
                            .font(TallyFont.mono(11, weight: .semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(c.accent)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                    .padding(.top, 8)

                    // Sort tabs
                    HStack(spacing: 4) {
                        sortButton("BY RATE", option: .rate, c: c)
                        sortButton("BY NAME", option: .name, c: c)
                    }

                    if sorted.isEmpty {
                        VStack(spacing: 6) {
                            Text("No tasks yet")
                                .font(TallyFont.heading(18, weight: .medium))
                                .foregroundStyle(c.text)
                            Text("Add your first task to start tracking.")
                                .font(TallyFont.body(13))
                                .foregroundStyle(c.dim)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                    } else {
                        // Task rows
                        ForEach(sorted, id: \.0.id) { task, hist, rate in
                            NavigationLink(value: task.id) {
                                taskRow(task: task, hist: hist, rate: rate, c: c)
                            }
                            .buttonStyle(.plain)
                        }

                        Text("TAP A TASK FOR FULL STATS")
                            .font(TallyFont.mono(10))
                            .tracking(1.4)
                            .foregroundStyle(c.dim)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 8)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .background(c.bg)
            .navigationDestination(for: String.self) { taskId in
                TaskStatsView(taskId: taskId)
            }
        }
        .sheet(isPresented: $showAddTask) {
            TaskFormView(taskId: nil)
        }
    }

    private func sortButton(_ label: String, option: SortOption, c: TallyColors) -> some View {
        Button {
            sortBy = option
        } label: {
            Text(label)
                .font(TallyFont.mono(10, weight: .semibold))
                .tracking(1.0)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(sortBy == option ? c.accentSoft : Color.clear)
                .foregroundStyle(sortBy == option ? c.accent : c.dim)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }

    private func taskRow(task: TallyTask, hist: [Double], rate: Int, c: TallyColors) -> some View {
        let sched = describeSchedule(task)
        let rateColor = rate >= 90 ? c.pos : rate >= 70 ? c.text : c.neg
        let dotColor = rate >= 90 ? c.pos : rate >= 70 ? c.accent : c.neg

        return HStack(spacing: 10) {
            Circle()
                .fill(dotColor)
                .frame(width: 6, height: 6)

            VStack(alignment: .leading, spacing: 2) {
                Text(task.name)
                    .font(TallyFont.heading(14, weight: .medium))
                    .foregroundStyle(c.text)
                Text("\(sched.days.uppercased()) · \(sched.times.uppercased()) · \(task.type.rawValue.uppercased())\(task.target != nil ? " · \(Int(task.target!)) \(task.unit ?? "")" : "")")
                    .font(TallyFont.mono(10))
                    .foregroundStyle(c.dim)
                    .lineLimit(1)
            }

            Spacer()

            SparklineView(values: hist, width: 48, height: 16)

            Text("\(rate)%")
                .font(TallyFont.mono(11, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(rateColor)
                .frame(width: 36, alignment: .trailing)
        }
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) {
            Rectangle().fill(c.rule).frame(height: 1)
        }
    }
}
