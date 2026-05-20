//
//  TaskState.swift
//  Tally
//
//  Pure selector: given a task, a date, log entries, and now → computed status.
//  Ported from tally-state.jsx lines 193-245.

import Foundation

enum TaskStatusKind: String, Sendable {
    case done
    case partial
    case overdue
    case due
    case off
}

struct TaskStatus: Sendable {
    let status: TaskStatusKind
    let pct: Double          // 0.0...1.0
    let sum: Double?         // for count/timer
    let label: String        // display string
    let count: Int           // number of entries
    let value: Double?       // for numeric: latest reading
}

func taskStateFor(task: TallyTask, date: Date, entries: [LogEntry], now: Date) -> TaskStatus {
    let key = localDateKey(date)
    let dow = dayOfWeek(date)
    let scheduled = task.isScheduled(on: dow)

    let taskEntries = entries.filter { $0.taskId == task.id && $0.date == key && !$0.deleted }

    // Not scheduled and no entries — truly off
    if !scheduled && taskEntries.isEmpty {
        return TaskStatus(status: .off, pct: 0, sum: nil, label: "Not scheduled", count: 0, value: nil)
    }

    let isPastDate = startOfDay(date) < startOfDay(now)
    let isFutureDate = startOfDay(date) > startOfDay(now)

    // Determine if the task's due time has passed (only relevant if scheduled)
    let firstTime = task.times.first ?? "all-day"
    let nowMins = minutesSinceMidnight(now)
    let dueTime = firstTime == "all-day" ? (23 * 60 + 59) : parseHHMM(firstTime).mins
    let isToday = key == localDateKey(now)
    let passedTime = scheduled ? (isToday ? nowMins > dueTime : isPastDate) : false

    switch task.type {
    case .check, .yesno:
        let done = taskEntries.contains { $0.value >= 1.0 }
        if done {
            let label = task.type == .yesno ? "Yes" : "Done"
            return TaskStatus(status: .done, pct: 1, sum: nil, label: label, count: 1, value: nil)
        }
        let overdueStatus: TaskStatusKind = passedTime && !isFutureDate ? .overdue : .due
        return TaskStatus(status: overdueStatus, pct: 0, sum: nil, label: "—", count: 0, value: nil)

    case .numeric:
        if let last = taskEntries.last {
            let formatted = task.unit != nil ? "\(formatNumber(last.value)) \(task.unit!)" : formatNumber(last.value)
            return TaskStatus(status: .done, pct: 1, sum: nil, label: formatted, count: 1, value: last.value)
        }
        let overdueStatus: TaskStatusKind = passedTime && !isFutureDate ? .overdue : .due
        return TaskStatus(status: overdueStatus, pct: 0, sum: nil, label: "—", count: 0, value: nil)

    case .count:
        let sum = taskEntries.reduce(0.0) { $0 + $1.value }
        let target = task.target ?? 1
        let pct = sum / target  // uncapped — allows >1.0 for over-target
        let done = sum >= target
        let status: TaskStatusKind
        if done {
            status = .done
        } else if sum > 0 {
            status = .partial
        } else if passedTime && !isFutureDate {
            status = .overdue
        } else {
            status = .due
        }
        let unitStr = task.unit ?? ""
        let label = "\(Int(sum.rounded())) / \(Int(target)) \(unitStr)".trimmingCharacters(in: .whitespaces)
        return TaskStatus(status: status, pct: pct, sum: sum, label: label, count: taskEntries.count, value: nil)

    case .timer:
        let sum = taskEntries.reduce(0.0) { $0 + $1.value }
        let target = task.target ?? 1
        let pct = sum / target  // uncapped — allows >1.0 for over-target
        let done = sum >= target
        let status: TaskStatusKind
        if done {
            status = .done
        } else if sum > 0 {
            status = .partial
        } else if passedTime && !isFutureDate {
            status = .overdue
        } else {
            status = .due
        }
        let unitStr = task.unit ?? "min"
        let label = "\(Int(sum.rounded())) / \(Int(target)) \(unitStr)".trimmingCharacters(in: .whitespaces)
        return TaskStatus(status: status, pct: pct, sum: sum, label: label, count: taskEntries.count, value: nil)
    }
}

private func formatNumber(_ n: Double) -> String {
    if n == n.rounded() {
        return String(Int(n))
    }
    return String(format: "%.1f", n)
}
