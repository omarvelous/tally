//
//  TasksScreen.swift
//  Tally
//
//  Tasks library: active + archived views, swipe-to-log, sort toggle.

import SwiftUI
import SwiftData

struct TasksScreen: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(LogSheetCoordinator.self) private var logCoordinator
    @Query private var allTasks: [TallyTask]
    @Query private var allEntries: [LogEntry]

    @State private var sortBy: SortOption = .rate
    @State private var viewFilter: ViewFilter = .active
    @State private var showTemplatePicker = false
    @State private var showCustomForm = false
    @State private var templateToCustomize: TaskTemplate?
    @State private var quickAddedTaskName: String?
    @State private var quickAddedTaskId: String?
    @State private var selectedTaskId: String?

    enum SortOption: String { case rate, name }
    enum ViewFilter: String { case active, archived }

    private var activeTasks: [TallyTask] { allTasks.filter { !$0.archived } }
    private var archivedTasks: [TallyTask] { allTasks.filter { $0.archived } }

    var body: some View {
        let c = TallyColors.resolve(colorScheme)
        let now = Date()
        let visibleTasks = viewFilter == .active ? activeTasks : archivedTasks

        let rated = visibleTasks.map { task -> (TallyTask, [Double], Int) in
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
                            Text(verbatim: "LIBRARY · \(activeTasks.count) ACTIVE · \(archivedTasks.count) ARCHIVED")
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
                            showTemplatePicker = true
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

                    // Filter + Sort chips
                    HStack(spacing: 4) {
                        filterChip("ACTIVE · \(activeTasks.count)", filter: .active, c: c)
                        filterChip("ARCHIVED · \(archivedTasks.count)", filter: .archived, c: c)
                        Spacer()
                        sortButton("BY RATE", option: .rate, c: c)
                        sortButton("BY NAME", option: .name, c: c)
                    }

                    if sorted.isEmpty {
                        VStack(spacing: 6) {
                            Text(viewFilter == .active ? "No tasks yet" : "No archived tasks")
                                .font(TallyFont.heading(18, weight: .medium))
                                .foregroundStyle(c.text)
                            Text(viewFilter == .active ? "Add your first task to start tracking." : "Archived tasks will appear here.")
                                .font(TallyFont.body(13))
                                .foregroundStyle(c.dim)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                    } else {
                        // Task rows
                        ForEach(sorted, id: \.0.id) { task, hist, rate in
                            if viewFilter == .active {
                                SwipeableRow(pillLabel: "LOG →", pillColor: c.pos) {
                                    logCoordinator.open(task.id)
                                } content: {
                                    taskRow(task: task, hist: hist, rate: rate, isArchived: false, c: c)
                                        .contentShape(Rectangle())
                                        .onTapGesture { selectedTaskId = task.id }
                                }
                            } else {
                                // Archived: tap only, no swipe
                                taskRow(task: task, hist: hist, rate: rate, isArchived: true, c: c)
                                    .contentShape(Rectangle())
                                    .onTapGesture { selectedTaskId = task.id }
                                    .opacity(0.6)
                            }
                        }

                        // Footer hint
                        Text(viewFilter == .active ? "TAP TO VIEW · SWIPE LEFT TO LOG" : "TAP TO REVIEW + RESTORE")
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
            .navigationDestination(item: $selectedTaskId) { taskId in
                TaskStatsView(taskId: taskId)
            }
        }
        .sheet(isPresented: $showTemplatePicker) {
            TaskTemplatePicker { result in
                switch result {
                case .custom:
                    showCustomForm = true
                case .quickAdded(let task):
                    quickAddedTaskName = task.name
                    quickAddedTaskId = task.id
                case .customize(let template):
                    templateToCustomize = template
                }
            }
        }
        .sheet(isPresented: $showCustomForm) {
            TaskFormView(taskId: nil)
        }
        .sheet(item: $templateToCustomize) { template in
            TaskFormView(taskId: nil, template: template)
        }
        .overlay(alignment: .bottom) {
            if let name = quickAddedTaskName {
                QuickAddToast(
                    taskName: name,
                    onEdit: {
                        if let id = quickAddedTaskId {
                            quickAddedTaskName = nil
                            quickAddedTaskId = nil
                            selectedTaskId = id
                        }
                    },
                    onDismiss: {
                        quickAddedTaskName = nil
                        quickAddedTaskId = nil
                    }
                )
            }
        }
    }

    // MARK: - Chips

    private func filterChip(_ label: String, filter: ViewFilter, c: TallyColors) -> some View {
        Button {
            viewFilter = filter
        } label: {
            Text(verbatim: label)
                .font(TallyFont.mono(10, weight: .semibold))
                .tracking(1.0)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(viewFilter == filter ? c.accentSoft : Color.clear)
                .foregroundStyle(viewFilter == filter ? c.accent : c.dim)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
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

    // MARK: - Task row

    private func taskRow(task: TallyTask, hist: [Double], rate: Int, isArchived: Bool, c: TallyColors) -> some View {
        let sched = describeSchedule(task)
        let daysCompact = compactDays(task)
        let rateColor = isArchived ? c.dim : (rate >= 90 ? c.pos : rate >= 70 ? c.text : c.neg)
        let dotColor = isArchived ? c.dim3 : (rate >= 90 ? c.pos : rate >= 70 ? c.accent : c.neg)

        return HStack(spacing: 10) {
            Circle()
                .fill(dotColor)
                .frame(width: 6, height: 6)

            VStack(alignment: .leading, spacing: 2) {
                Text(task.name)
                    .font(TallyFont.heading(14, weight: .medium))
                    .foregroundStyle(isArchived ? c.dim : c.text)
                Text(verbatim: "\(daysCompact) · \(sched.times.uppercased()) · \(task.type.rawValue.uppercased())\(task.target != nil ? " · \(Int(task.target!)) \(task.unit ?? "")" : "")")
                    .font(TallyFont.mono(10))
                    .foregroundStyle(c.dim)
                    .lineLimit(1)
            }

            Spacer()

            SparklineView(values: hist, width: 48, height: 16)

            Text(verbatim: "\(rate)%")
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

    private func compactDays(_ task: TallyTask) -> String {
        if task.days.isEmpty || task.days.count == 7 {
            return "DAILY"
        } else if task.days.count == 5 && task.days.sorted() == [0, 1, 2, 3, 4] {
            return "WKDAYS"
        } else if task.days.count == 2 && task.days.contains(5) && task.days.contains(6) {
            return "WKENDS"
        } else {
            return task.days.sorted().map { dayLabels[$0] }.joined(separator: "/")
        }
    }
}
