//
//  Streak.swift
//  Tally
//
//  Pure selector: compute current streak, best streak, and 60-day history.
//  Ported from tally-state.jsx lines 261-281.

import Foundation

struct DaySnapshot: Sendable {
    let date: String        // "YYYY-MM-DD"
    let pct: Double
    let done: Int
    let total: Int
    let isToday: Bool
}

struct StreakResult: Sendable {
    let current: Int
    let best: Int
    let history: [DaySnapshot]
}

func streakFor(tasks: [TallyTask], entries: [LogEntry], now: Date) -> StreakResult {
    // Build 61-day history (60 days back + today)
    var history: [DaySnapshot] = []
    for i in stride(from: 60, through: 0, by: -1) {
        let d = addDays(now, -i)
        let day = dayCompletionFor(date: d, tasks: tasks, entries: entries, now: now)
        history.append(DaySnapshot(
            date: localDateKey(d),
            pct: day.pct,
            done: day.done,
            total: day.total,
            isToday: i == 0
        ))
    }

    // Current streak: walk back from yesterday until < 100%.
    // Include today if it's at 100%.
    var current = 0
    let todayItem = history.last!
    if todayItem.total > 0 && todayItem.pct >= 1.0 {
        current = 1
    }
    for i in stride(from: history.count - 2, through: 0, by: -1) {
        let h = history[i]
        if h.total > 0 && h.pct >= 1.0 {
            current += 1
        } else {
            break
        }
    }

    // Best streak: longest run anywhere in history
    var best = 0
    var run = 0
    for h in history {
        if h.total > 0 && h.pct >= 1.0 {
            run += 1
            best = max(best, run)
        } else {
            run = 0
        }
    }

    return StreakResult(current: current, best: best, history: history)
}
