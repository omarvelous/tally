//
//  TallyWidgets.swift
//  TallyWidgets
//
//  Streak widget: shows current streak count + day completion %.
//  Supports lock screen (accessory) and home screen (small) sizes.

import WidgetKit
import SwiftUI
import SwiftData

// MARK: - Timeline Entry

struct TallyEntry: TimelineEntry {
    let date: Date
    let streakCount: Int
    let dayPct: Int          // 0-100
    let done: Int
    let total: Int
}

// MARK: - Timeline Provider

struct TallyTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> TallyEntry {
        TallyEntry(date: .now, streakCount: 7, dayPct: 65, done: 4, total: 6)
    }

    func getSnapshot(in context: Context, completion: @escaping (TallyEntry) -> Void) {
        let entry = computeEntry()
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TallyEntry>) -> Void) {
        let entry = computeEntry()
        // Refresh at next midnight
        let midnight = Calendar.current.startOfDay(for: Calendar.current.date(byAdding: .day, value: 1, to: .now)!)
        let timeline = Timeline(entries: [entry], policy: .after(midnight))
        completion(timeline)
    }

    private func computeEntry() -> TallyEntry {
        do {
            let container = try ModelContainer(for: TallyTask.self, LogEntry.self, TallySettings.self)
            let context = ModelContext(container)

            let tasks = try context.fetch(FetchDescriptor<TallyTask>())
                .filter { !$0.archived }
            let entries = try context.fetch(FetchDescriptor<LogEntry>())
            let now = Date()

            let day = dayCompletionFor(date: now, tasks: tasks, entries: entries, now: now)
            let streak = streakFor(tasks: tasks, entries: entries, now: now)

            return TallyEntry(
                date: now,
                streakCount: streak.current,
                dayPct: Int((day.pct * 100).rounded()),
                done: day.done,
                total: day.total
            )
        } catch {
            return TallyEntry(date: .now, streakCount: 0, dayPct: 0, done: 0, total: 0)
        }
    }
}

// MARK: - Streak Widget (small + accessory)

struct StreakWidget: Widget {
    let kind = "StreakWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TallyTimelineProvider()) { entry in
            StreakWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Streak")
        .description("Current streak and day completion.")
        .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryRectangular])
    }
}

struct StreakWidgetView: View {
    let entry: TallyEntry

    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryCircular:
            accessoryCircular
        case .accessoryRectangular:
            accessoryRectangular
        default:
            systemSmall
        }
    }

    // Lock screen circular: streak number
    private var accessoryCircular: some View {
        VStack(spacing: 2) {
            Text(verbatim: "\(entry.streakCount)")
                .font(.system(size: 24, weight: .bold, design: .monospaced))
            Text("DAYS")
                .font(.system(size: 8, weight: .medium, design: .monospaced))
                .opacity(0.7)
        }
    }

    // Lock screen rectangular: streak + day %
    private var accessoryRectangular: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text("Tally")
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                Text(verbatim: "\(entry.dayPct)%")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
            }
            HStack(spacing: 4) {
                Text(verbatim: "\(entry.streakCount)d streak")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                Spacer()
                Text(verbatim: "\(entry.done)/\(entry.total)")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .opacity(0.7)
            }
            ProgressView(value: Double(entry.dayPct), total: 100)
                .tint(.blue)
        }
    }

    // Home screen small: streak count + day progress
    private var systemSmall: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("TALLY")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .tracking(1.2)
                    .opacity(0.5)
                Spacer()
                Text("STREAK")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .tracking(1.2)
                    .opacity(0.5)
            }

            Spacer()

            HStack(alignment: .firstTextBaseline) {
                Text(verbatim: "\(entry.streakCount)")
                    .font(.system(size: 48, weight: .medium, design: .monospaced))
                Text("d")
                    .font(.system(size: 20, weight: .medium))
                    .opacity(0.5)
            }

            Spacer()

            VStack(alignment: .leading, spacing: 4) {
                ProgressView(value: Double(entry.dayPct), total: 100)
                    .tint(.blue)
                HStack {
                    Text(verbatim: "\(entry.dayPct)% today")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .opacity(0.7)
                    Spacer()
                    Text(verbatim: "\(entry.done)/\(entry.total)")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .opacity(0.5)
                }
            }
        }
    }
}

// MARK: - Today Checklist Widget (medium)

struct TodayChecklistWidget: Widget {
    let kind = "TodayChecklistWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TodayChecklistProvider()) { entry in
            TodayChecklistView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Today")
        .description("Today's task checklist.")
        .supportedFamilies([.systemMedium])
    }
}

struct TodayChecklistEntry: TimelineEntry {
    let date: Date
    let dayPct: Int
    let tasks: [(name: String, done: Bool, label: String)]
}

struct TodayChecklistProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodayChecklistEntry {
        TodayChecklistEntry(date: .now, dayPct: 65, tasks: [
            ("Push-ups", true, "100/100"),
            ("Water", false, "64/128 oz"),
            ("Read", false, "—"),
        ])
    }

    func getSnapshot(in context: Context, completion: @escaping (TodayChecklistEntry) -> Void) {
        completion(computeEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodayChecklistEntry>) -> Void) {
        let entry = computeEntry()
        let midnight = Calendar.current.startOfDay(for: Calendar.current.date(byAdding: .day, value: 1, to: .now)!)
        let timeline = Timeline(entries: [entry], policy: .after(midnight))
        completion(timeline)
    }

    private func computeEntry() -> TodayChecklistEntry {
        do {
            let container = try ModelContainer(for: TallyTask.self, LogEntry.self, TallySettings.self)
            let context = ModelContext(container)

            let allTasks = try context.fetch(FetchDescriptor<TallyTask>())
                .filter { !$0.archived }
            let entries = try context.fetch(FetchDescriptor<LogEntry>())
            let now = Date()

            let day = dayCompletionFor(date: now, tasks: allTasks, entries: entries, now: now)
            let dow = dayOfWeek(now)
            let scheduled = allTasks.filter { $0.isScheduled(on: dow) }

            let taskItems: [(String, Bool, String)] = scheduled.prefix(6).map { task in
                let state = taskStateFor(task: task, date: startOfDay(now), entries: entries, now: now)
                return (task.name, state.status == .done, state.label)
            }

            return TodayChecklistEntry(
                date: now,
                dayPct: Int((day.pct * 100).rounded()),
                tasks: taskItems
            )
        } catch {
            return TodayChecklistEntry(date: .now, dayPct: 0, tasks: [])
        }
    }
}

struct TodayChecklistView: View {
    let entry: TodayChecklistEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("TODAY")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .tracking(1.2)
                    .opacity(0.5)
                Spacer()
                Text(verbatim: "\(entry.dayPct)%")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
            }

            ForEach(Array(entry.tasks.enumerated()), id: \.offset) { _, task in
                HStack(spacing: 8) {
                    Image(systemName: task.done ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 14))
                        .foregroundStyle(task.done ? .green : .secondary)
                    Text(task.name)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)
                    Spacer()
                    Text(task.label)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .opacity(0.6)
                        .lineLimit(1)
                }
            }

            if entry.tasks.isEmpty {
                Text("No tasks scheduled today")
                    .font(.system(size: 12))
                    .opacity(0.5)
            }
        }
    }
}

// MARK: - Previews

#Preview(as: .systemSmall) {
    StreakWidget()
} timeline: {
    TallyEntry(date: .now, streakCount: 14, dayPct: 65, done: 4, total: 6)
}

#Preview(as: .systemMedium) {
    TodayChecklistWidget()
} timeline: {
    TodayChecklistEntry(date: .now, dayPct: 65, tasks: [
        ("Vitamins", true, "Done"),
        ("Push-ups", true, "100/100 reps"),
        ("Water", false, "64/128 oz"),
        ("Read", false, "—"),
    ])
}
