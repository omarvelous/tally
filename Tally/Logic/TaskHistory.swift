//
//  TaskHistory.swift
//  Tally
//
//  Pure selector: sparkline data — completion % for each of the last N days.
//  Ported from tally-state.jsx lines 284-291.

import Foundation

func taskHistoryFor(task: TallyTask, entries: [LogEntry], now: Date, days: Int = 14) -> [Double] {
    var out: [Double] = []
    for i in stride(from: days - 1, through: 0, by: -1) {
        let d = addDays(now, -i)
        let state = taskStateFor(task: task, date: d, entries: entries, now: now)
        out.append(state.pct)
    }
    return out
}
