//
//  TimeBlocks.swift
//  Tally
//
//  Pure selectors: group tasks by time block, describe schedules, pick presets.
//  Ported from tally-state.jsx lines 294-335.

import Foundation

enum TimeBlock: String, CaseIterable, Sendable {
    case morning
    case afternoon
    case evening
    case allDay

    var label: String {
        switch self {
        case .morning:   return "MORNING"
        case .afternoon: return "AFTERNOON"
        case .evening:   return "EVENING"
        case .allDay:    return "ALL DAY"
        }
    }

    var timeRange: String {
        switch self {
        case .morning:   return "06–12"
        case .afternoon: return "12–18"
        case .evening:   return "18+"
        case .allDay:    return ""
        }
    }
}

struct TimeBlockGroups: Sendable {
    let morning: [TallyTask]
    let afternoon: [TallyTask]
    let evening: [TallyTask]
    let allDay: [TallyTask]

    /// Returns non-empty blocks in display order.
    var activeBlocks: [(TimeBlock, [TallyTask])] {
        var result: [(TimeBlock, [TallyTask])] = []
        if !morning.isEmpty   { result.append((.morning, morning)) }
        if !afternoon.isEmpty { result.append((.afternoon, afternoon)) }
        if !evening.isEmpty   { result.append((.evening, evening)) }
        if !allDay.isEmpty    { result.append((.allDay, allDay)) }
        return result
    }
}

func groupByTimeBlock(tasks: [TallyTask], date: Date) -> TimeBlockGroups {
    let dow = dayOfWeek(date)
    let scheduled = tasks.filter { !$0.archived && $0.isScheduled(on: dow) }

    var morning: [TallyTask] = []
    var afternoon: [TallyTask] = []
    var evening: [TallyTask] = []
    var allDay: [TallyTask] = []

    for t in scheduled {
        let ft = t.times.first ?? "all-day"
        if ft == "all-day" {
            allDay.append(t)
        } else {
            let h = parseHHMM(ft).h
            if h < 12 {
                morning.append(t)
            } else if h < 18 {
                afternoon.append(t)
            } else {
                evening.append(t)
            }
        }
    }

    // Sort by first scheduled time within each block
    let byTime: (TallyTask, TallyTask) -> Bool = { a, b in
        let aFirst = a.times.first ?? "all-day"
        let bFirst = b.times.first ?? "all-day"
        if aFirst == "all-day" { return false }
        if bFirst == "all-day" { return true }
        return parseHHMM(aFirst).mins < parseHHMM(bFirst).mins
    }
    morning.sort(by: byTime)
    afternoon.sort(by: byTime)
    evening.sort(by: byTime)

    return TimeBlockGroups(morning: morning, afternoon: afternoon, evening: evening, allDay: allDay)
}

// MARK: - Schedule description

struct ScheduleDescription: Sendable {
    let days: String
    let times: String
}

func describeSchedule(_ task: TallyTask) -> ScheduleDescription {
    let daysStr: String
    if task.days.isEmpty || task.days.count == 7 {
        daysStr = "Daily"
    } else if task.days.count == 5 && task.days.sorted() == [0, 1, 2, 3, 4] {
        daysStr = "Weekdays"
    } else if task.days.count == 2 && task.days.contains(5) && task.days.contains(6) {
        daysStr = "Weekends"
    } else {
        daysStr = task.days.map { dayNames[$0] }.joined(separator: " · ")
    }

    let timesStr: String
    if task.times.count > 2 {
        timesStr = "\(task.times.count) times/day"
    } else {
        timesStr = task.times.joined(separator: " · ")
    }

    return ScheduleDescription(days: daysStr, times: timesStr)
}

// MARK: - Preset log values

func pickPresets(for task: TallyTask) -> [Double] {
    guard let target = task.target else { return [] }
    switch task.type {
    case .count:
        let quarter = (target / 4).rounded()
        let half = (target / 2).rounded()
        return [5, 10, quarter, half].map { max($0, 1) }
    case .timer:
        return [5, 10, 15, target]
    default:
        return []
    }
}

func defaultLogValue(for task: TallyTask) -> Double {
    switch task.type {
    case .count:
        return ((task.target ?? 4) / 4).rounded()
    case .timer:
        return task.target ?? 1
    case .numeric:
        return 0
    case .check, .yesno:
        return 1.0
    }
}
