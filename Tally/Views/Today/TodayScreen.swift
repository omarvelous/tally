//
//  TodayScreen.swift
//  Tally
//
//  The daily dashboard. Ported from tally-today.jsx TodayScreen.

import SwiftUI
import SwiftData
import Combine

struct TodayScreen: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Query(filter: #Predicate<TallyTask> { !$0.archived }) private var tasks: [TallyTask]
    @Query private var allEntries: [LogEntry]

    @State private var tick = Date()
    private let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var body: some View {
        let c = TallyColors.resolve(colorScheme)
        let now = tick
        let today = startOfDay(now)
        let blocks = groupByTimeBlock(tasks: tasks, date: today)
        let day = dayCompletionFor(date: today, tasks: tasks, entries: allEntries, now: now)
        let streak = streakFor(tasks: tasks, entries: allEntries, now: now)
        let scheduled = blocks.activeBlocks.flatMap { $0.1 }

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    header(now: now, streak: streak, c: c)

                    if scheduled.isEmpty {
                        emptyState(c: c)
                    } else {
                        // Day completion card
                        dayCompletionCard(day: day, scheduled: scheduled, now: now, c: c)

                        // Time block sections
                        ForEach(blocks.activeBlocks, id: \.0) { block, blockTasks in
                            timeBlockSection(block: block, tasks: blockTasks, now: now, c: c)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .background(c.bg)
            .navigationDestination(for: String.self) { taskId in
                TaskDetailView(taskId: taskId)
            }
        }
        .onReceive(timer) { tick = $0 }
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

    // MARK: - Time block section

    private func timeBlockSection(block: TimeBlock, tasks: [TallyTask], now: Date, c: TallyColors) -> some View {
        let doneCount = tasks.filter { taskStateFor(task: $0, date: startOfDay(now), entries: allEntries, now: now).status == .done }.count

        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(block.timeRange.isEmpty ? block.label : "\(block.label) · \(block.timeRange)")
                    .font(TallyFont.label())
                    .textCase(.uppercase)
                    .tracking(1.2)
                    .foregroundStyle(c.dim)
                Spacer()
                Text("\(doneCount)/\(tasks.count)")
                    .font(TallyFont.mono(10))
                    .foregroundStyle(c.dim)
            }

            ForEach(tasks, id: \.id) { task in
                let state = taskStateFor(task: task, date: startOfDay(now), entries: allEntries, now: now)
                let history = taskHistoryFor(task: task, entries: allEntries, now: now)
                NavigationLink(value: task.id) {
                    TaskRow(task: task, state: state, sparkline: history)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Empty state

    private func emptyState(c: TallyColors) -> some View {
        VStack(spacing: 6) {
            Text("No tasks scheduled today")
                .font(TallyFont.heading(18, weight: .medium))
                .foregroundStyle(c.text)
            Text("It's a rest day — or add some tasks to fill it in.")
                .font(TallyFont.body(13))
                .foregroundStyle(c.dim)
                .multilineTextAlignment(.center)
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
}
