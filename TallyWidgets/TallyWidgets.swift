//
//  TallyWidgets.swift
//  TallyWidgets
//
//  Streak widget: shows current streak count + day completion %.
//  V2: reads from HabitDay + DaySummary (materialized data).

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
        completion(computeEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TallyEntry>) -> Void) {
        let entry = computeEntry()
        let midnight = Calendar.current.startOfDay(for: Calendar.current.date(byAdding: .day, value: 1, to: .now)!)
        let timeline = Timeline(entries: [entry], policy: .after(midnight))
        completion(timeline)
    }

    private func computeEntry() -> TallyEntry {
        do {
            let container = try ModelContainerFactory.create()
            let context = ModelContext(container)
            let now = Date()
            let todayKey = localDateKey(now)

            // Read today's habit_days
            let allHabitDays = try context.fetch(FetchDescriptor<HabitDay>())
            let todayHDs = allHabitDays.filter { $0.date == todayKey }

            let total = todayHDs.count
            let done = todayHDs.filter { $0.status == "done" }.count
            let dayPct = total > 0 ? Int((Double(done) / Double(total) * 100).rounded()) : 0

            // Compute streak from day_summaries
            let allSummaries = try context.fetch(FetchDescriptor<DaySummary>())
            let byDate = Dictionary(allSummaries.map { ($0.date, $0) }, uniquingKeysWith: { a, _ in a })

            var streak = 0
            if let today = byDate[todayKey], today.streakDay { streak = 1 }
            for i in 1...60 {
                let key = localDateKey(addDays(now, -i))
                guard let summary = byDate[key] else { break }
                if summary.total == 0 { continue }
                if summary.streakDay { streak += 1 } else { break }
            }

            return TallyEntry(date: now, streakCount: streak, dayPct: dayPct, done: done, total: total)
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

    private var accessoryCircular: some View {
        VStack(spacing: 2) {
            Text(verbatim: "\(entry.streakCount)")
                .font(.system(size: 24, weight: .bold, design: .monospaced))
            Text("DAYS")
                .font(.system(size: 8, weight: .medium, design: .monospaced))
                .opacity(0.7)
        }
    }

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
        .description("Today's habit checklist.")
        .supportedFamilies([.systemMedium])
    }
}

struct TodayChecklistEntry: TimelineEntry {
    let date: Date
    let dayPct: Int
    let habits: [(name: String, done: Bool, label: String)]
}

struct TodayChecklistProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodayChecklistEntry {
        TodayChecklistEntry(date: .now, dayPct: 65, habits: [
            ("Push-ups", true, "50/50 reps"),
            ("Water", false, "32/64 oz"),
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
            let container = try ModelContainerFactory.create()
            let context = ModelContext(container)
            let now = Date()
            let todayKey = localDateKey(now)

            // Fetch today's habit_days
            let allHabitDays = try context.fetch(FetchDescriptor<HabitDay>())
            let todayHDs = allHabitDays.filter { $0.date == todayKey }

            let total = todayHDs.count
            let done = todayHDs.filter { $0.status == "done" }.count
            let dayPct = total > 0 ? Int((Double(done) / Double(total) * 100).rounded()) : 0

            // Look up habit names
            let allHabits = try context.fetch(FetchDescriptor<Habit>())
            let habitMap = Dictionary(allHabits.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
            let allUserHabits = try context.fetch(FetchDescriptor<UserHabit>())
            let uhMap = Dictionary(allUserHabits.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })

            let habitItems: [(String, Bool, String)] = todayHDs.prefix(6).compactMap { hd in
                guard let uh = uhMap[hd.userHabitId],
                      let habit = habitMap[uh.habitId] else { return nil }
                let isDone = hd.status == "done"
                let label: String
                if isDone && (habit.type == .check || habit.type == .yesno) {
                    label = "Done"
                } else if hd.targetSnap != nil && hd.targetSnap! > 0 {
                    label = "\(Int(hd.sum.rounded()))/\(Int(hd.targetSnap!)) \(hd.unitSnap ?? "")"
                } else {
                    label = isDone ? "Done" : "—"
                }
                return (habit.name, isDone, label)
            }

            return TodayChecklistEntry(date: now, dayPct: dayPct, habits: habitItems)
        } catch {
            return TodayChecklistEntry(date: .now, dayPct: 0, habits: [])
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

            ForEach(Array(entry.habits.enumerated()), id: \.offset) { _, habit in
                HStack(spacing: 8) {
                    Image(systemName: habit.done ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 14))
                        .foregroundStyle(habit.done ? .green : .secondary)
                    Text(habit.name)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)
                    Spacer()
                    Text(habit.label)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .opacity(0.6)
                        .lineLimit(1)
                }
            }

            if entry.habits.isEmpty {
                Text("No habits scheduled today")
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
    TodayChecklistEntry(date: .now, dayPct: 65, habits: [
        ("Vitamins", true, "Done"),
        ("Push-ups", true, "50/50 reps"),
        ("Water", false, "32/64 oz"),
        ("Read", false, "—"),
    ])
}
