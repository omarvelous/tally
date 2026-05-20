//
//  TodayScreen.swift
//  Tally
//
//  The daily dashboard. Flat task list ordered by time, completed pushed to bottom.

import SwiftUI
import SwiftData
import Combine

struct TodayScreen: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Environment(MidnightObserver.self) private var midnightObserver
    @Environment(LogSheetCoordinator.self) private var logCoordinator
    @Query(filter: #Predicate<TallyTask> { !$0.archived }) private var tasks: [TallyTask]
    @Query private var allEntries: [LogEntry]

    @State private var tick = Date()
    @State private var showTemplatePicker = false
    @State private var showCustomForm = false
    @State private var templateToCustomize: TaskTemplate?
    @State private var quickAddedTaskName: String?
    @State private var quickAddedTaskId: String?
    private let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var body: some View {
        let c = TallyColors.resolve(colorScheme)
        let now = tick
        let today = startOfDay(now)
        let dow = dayOfWeek(today)
        let day = dayCompletionFor(date: today, tasks: tasks, entries: allEntries, now: now)
        let streak = streakFor(tasks: tasks, entries: allEntries, now: now)

        let scheduled = tasks.filter { $0.isScheduled(on: dow) }
        let unscheduled = tasks.filter { !$0.isScheduled(on: dow) }
        let withState = scheduled.map { task -> (TallyTask, TaskStatus) in
            (task, taskStateFor(task: task, date: today, entries: allEntries, now: now))
        }

        // Sort: uncompleted first (by time), then completed (by time)
        let pending = withState
            .filter { $0.1.status != .done }
            .sorted { taskSortTime($0.0) < taskSortTime($1.0) }
        let done = withState
            .filter { $0.1.status == .done }
            .sorted { taskSortTime($0.0) < taskSortTime($1.0) }

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    header(now: now, streak: streak, c: c)

                    if tasks.isEmpty {
                        // Zero active tasks: show batch onboarding
                        OnboardingTemplateView(
                            onBrowseAll: { showTemplatePicker = true },
                            onCreateCustom: { showCustomForm = true }
                        )
                    } else if scheduled.isEmpty && unscheduled.isEmpty {
                        emptyState(c: c)
                    } else {
                        // Day completion card
                        if !scheduled.isEmpty {
                            dayCompletionCard(day: day, scheduled: scheduled, now: now, c: c)
                        }

                        // Pending tasks
                        if !pending.isEmpty {
                            taskSection(label: "\(pending.count) REMAINING", tasks: pending, now: now, c: c)
                        }

                        // Completed tasks
                        if !done.isEmpty {
                            taskSection(label: "\(done.count) DONE", tasks: done, now: now, c: c, dimmed: true)
                        }

                        // Bonus: not scheduled today but available to log
                        if !unscheduled.isEmpty {
                            bonusSection(tasks: unscheduled, now: now, c: c)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .background(c.bg)
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
                        quickAddedTaskName = nil
                        quickAddedTaskId = nil
                    },
                    onDismiss: {
                        quickAddedTaskName = nil
                        quickAddedTaskId = nil
                    }
                )
            }
        }
        .onReceive(timer) { tick = $0 }
        .onChange(of: midnightObserver.currentDateKey) { _, _ in tick = Date() }
    }

    // MARK: - Header

    private func header(now: Date, streak: StreakResult, c: TallyColors) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(dateKicker(now))
                    .font(TallyFont.label())
                    .textCase(.uppercase)
                    .tracking(1.2)
                    .foregroundStyle(c.dim)
                Text("Today")
                    .font(TallyFont.heading(32, weight: .medium))
                    .foregroundStyle(c.text)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text("STREAK")
                    .font(TallyFont.label())
                    .textCase(.uppercase)
                    .tracking(1.2)
                    .foregroundStyle(c.dim)
                Text("\(streak.current)d")
                    .font(TallyFont.mono(22, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(c.accent)
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Day completion card

    private func dayCompletionCard(day: DayCompletion, scheduled: [TallyTask], now: Date, c: TallyColors) -> some View {
        TallyCard {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("DAY COMPLETION")
                        .font(TallyFont.label())
                        .textCase(.uppercase)
                        .tracking(1.2)
                        .foregroundStyle(c.dim)
                    Spacer()
                    Text("\(day.done)/\(day.total) TASKS")
                        .font(TallyFont.mono(11))
                        .foregroundStyle(c.dim)
                }

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(Int(day.pct * 100))")
                        .font(TallyFont.heading(56, weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle(c.text)
                    Text("%")
                        .font(TallyFont.heading(20, weight: .medium))
                        .foregroundStyle(c.dim)
                    Spacer()
                    Text(day.pct >= 1.0 ? "DAY EARNED" : "NEED 100% TO EARN")
                        .font(TallyFont.mono(10))
                        .foregroundStyle(day.pct >= 1.0 ? c.pos : c.dim)
                }

                // Segmented bar
                SegmentedDayBar(
                    statuses: scheduled.map { taskStateFor(task: $0, date: startOfDay(now), entries: allEntries, now: now).status }
                )
                .padding(.top, 6)

                // Summary
                HStack {
                    Text("\(day.done) done")
                        .font(TallyFont.mono(10))
                        .foregroundStyle(c.dim)
                    Spacer()
                    if day.partial > 0 {
                        Text("\(day.partial) in progress")
                            .font(TallyFont.mono(10))
                            .foregroundStyle(c.accent)
                    }
                    if day.overdue > 0 {
                        Text("\(day.overdue) overdue")
                            .font(TallyFont.mono(10))
                            .foregroundStyle(c.neg)
                    }
                }
                .padding(.top, 2)
            }
        }
    }

    // MARK: - Task section

    private func taskSection(label: String, tasks: [(TallyTask, TaskStatus)], now: Date, c: TallyColors, dimmed: Bool = false, bonus: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(TallyFont.label())
                .textCase(.uppercase)
                .tracking(1.2)
                .foregroundStyle(c.dim)

            ForEach(tasks, id: \.0.id) { task, state in
                let history = taskHistoryFor(task: task, entries: allEntries, now: now)
                let timeLabel = taskTimeLabel(task)
                let overTarget = state.pct > 1.0
                let isBinary = task.type == .check || task.type == .yesno
                let shouldDim = dimmed && isBinary
                Button {
                    logCoordinator.open(task.id)
                } label: {
                    HStack(spacing: 10) {
                        if overTarget {
                            Image(systemName: "star.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(c.warn)
                        } else {
                            StatusPip(status: state.status)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(task.name)
                                .font(TallyFont.heading(14, weight: .medium))
                                .foregroundStyle(c.text)
                            HStack(spacing: 0) {
                                Text(state.label)
                                    .font(TallyFont.mono(11))
                                    .foregroundStyle(c.dim)
                                if let time = timeLabel {
                                    Text(" · ")
                                        .font(TallyFont.mono(11))
                                        .foregroundStyle(c.dim)
                                    Text(time)
                                        .font(TallyFont.mono(11, weight: .medium))
                                        .foregroundStyle(c.accent)
                                }
                            }
                        }

                        Spacer()

                        SparklineView(values: history)

                        Text("\(Int(state.pct * 100))%")
                            .font(TallyFont.mono(12, weight: .medium))
                            .monospacedDigit()
                            .foregroundStyle(overTarget ? c.warn : c.dim)
                            .frame(width: 44, alignment: .trailing)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 4)
                    .contentShape(Rectangle())
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(c.rule).frame(height: 1)
                    }
                }
                .buttonStyle(.plain)
                .opacity(shouldDim ? 0.5 : 1)
            }
        }
    }

    // MARK: - Bonus section (not scheduled but logged today)

    private func bonusSection(tasks: [TallyTask], now: Date, c: TallyColors) -> some View {
        let todayKey = localDateKey(now)
        let loggedToday = tasks.filter { task in
            allEntries.contains { $0.taskId == task.id && $0.date == todayKey && !$0.deleted }
        }

        return Group {
            if !loggedToday.isEmpty {
                let withState = loggedToday.map { task -> (TallyTask, TaskStatus) in
                    (task, taskStateFor(task: task, date: startOfDay(now), entries: allEntries, now: now))
                }
                taskSection(label: "BONUS · \(loggedToday.count) LOGGED", tasks: withState, now: now, c: c, bonus: true)
            }
        }
    }

    // MARK: - Empty state

    private func emptyState(c: TallyColors) -> some View {
        VStack(spacing: 16) {
            Text("No tasks scheduled today")
                .font(TallyFont.heading(18, weight: .medium))
                .foregroundStyle(c.text)
            Text("It's a rest day — or add some tasks to fill it in.")
                .font(TallyFont.body(13))
                .foregroundStyle(c.dim)
                .multilineTextAlignment(.center)
            Button {
                showTemplatePicker = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                    Text("New task")
                }
                .font(TallyFont.heading(14, weight: .medium))
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(c.accent)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    // MARK: - Helpers

    private func dateKicker(_ now: Date) -> String {
        let dow = dayOfWeek(now)
        let cal = Calendar.current
        let month = cal.component(.month, from: now) - 1
        let day = cal.component(.day, from: now)
        let h = cal.component(.hour, from: now)
        let m = cal.component(.minute, from: now)
        return "\(dayNames[dow]) · \(monthNamesShort[month]) \(day) · \(String(format: "%02d:%02d", h, m))"
    }

    private func taskSortTime(_ task: TallyTask) -> Int {
        let ft = task.times.first ?? "all-day"
        if ft == "all-day" { return 9999 }
        return parseHHMM(ft).mins
    }

    private func taskTimeLabel(_ task: TallyTask) -> String? {
        let ft = task.times.first ?? "all-day"
        if ft == "all-day" { return nil }
        return ft
    }

}
