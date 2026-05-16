//
//  DayCompletion.swift
//  Tally
//
//  Pure selector: given a date, all tasks, all entries, and now → day stats.
//  Ported from tally-state.jsx lines 248-257.

import Foundation

struct DayCompletion: Sendable {
    let done: Int
    let partial: Int
    let overdue: Int
    let total: Int
    let pct: Double         // done / total (0.0 if total == 0)
}

func dayCompletionFor(date: Date, tasks: [TallyTask], entries: [LogEntry], now: Date) -> DayCompletion {
    let dow = dayOfWeek(date)
    let scheduled = tasks.filter { !$0.archived && $0.isScheduled(on: dow) }
    guard !scheduled.isEmpty else {
        return DayCompletion(done: 0, partial: 0, overdue: 0, total: 0, pct: 0)
    }
    let states = scheduled.map { taskStateFor(task: $0, date: date, entries: entries, now: now) }
    let done = states.filter { $0.status == .done }.count
    let partial = states.filter { $0.status == .partial }.count
    let overdue = states.filter { $0.status == .overdue }.count
    return DayCompletion(done: done, partial: partial, overdue: overdue, total: scheduled.count, pct: Double(done) / Double(scheduled.count))
}
