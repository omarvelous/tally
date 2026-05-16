//
//  SeedData.swift
//  Tally
//
//  Debug-only seed data: 8 tasks + 30 days of history.
//  Ported from tally-state.jsx SEED_TASKS + buildSeedLog().

#if DEBUG
import Foundation
import SwiftData

enum SeedData {

    static let tasks: [TallyTask] = [
        TallyTask(id: "t-vit",     name: "Vitamins",    type: .check,   days: [0,1,2,3,4,5,6], times: ["07:30"]),
        TallyTask(id: "t-weigh",   name: "Weigh-in",    type: .numeric, unit: "kg",  days: [0,1,2,3,4,5,6], times: ["07:30"]),
        TallyTask(id: "t-stretch", name: "Stretch",     type: .yesno,   days: [0,1,2,3,4,5,6], times: ["08:00"]),
        TallyTask(id: "t-push",    name: "Push-ups",    type: .count,   target: 100, unit: "reps", days: [0,1,2,3,4,5,6], times: ["08:00","12:00","18:00"]),
        TallyTask(id: "t-water",   name: "Water",       type: .count,   target: 128, unit: "oz",  days: [0,1,2,3,4,5,6], times: ["all-day"]),
        TallyTask(id: "t-walk",    name: "Lunch walk",  type: .timer,   target: 30,  unit: "min", days: [0,1,2,3,4],     times: ["12:30"]),
        TallyTask(id: "t-squat",   name: "Squats",      type: .count,   target: 50,  unit: "reps", days: [0,2,4],         times: ["18:00"]),
        TallyTask(id: "t-read",    name: "Read",        type: .timer,   target: 20,  unit: "min", days: [0,1,2,3,4,5,6], times: ["21:00"]),
    ]

    static func buildLog() -> [LogEntry] {
        var log: [LogEntry] = []
        let today = startOfDay(Date())

        for offset in stride(from: 30, through: 1, by: -1) {
            let d = addDays(today, -offset)
            let key = localDateKey(d)
            let dow = dayOfWeek(d)
            let missDay = offset == 16
            let partialPush = offset == 22
            let partialRead = offset == 9

            for t in tasks {
                guard t.isScheduled(on: dow) else { continue }
                if missDay && (t.id == "t-push" || t.id == "t-squat") { continue }

                switch t.type {
                case .check, .yesno:
                    let time = t.times[0] == "all-day" ? "20:00" : t.times[0]
                    log.append(LogEntry(taskId: t.id, date: key, time: time, value: 1.0, ts: d.timeIntervalSince1970 * 1000))

                case .numeric:
                    let base = 76.5 - Double(30 - offset) * 0.08
                    let value = (base * 10).rounded() / 10
                    log.append(LogEntry(taskId: t.id, date: key, time: t.times[0], value: value, ts: d.timeIntervalSince1970 * 1000))

                case .count:
                    if partialPush && t.id == "t-push" {
                        log.append(LogEntry(taskId: t.id, date: key, time: "08:14", value: 30, ts: d.timeIntervalSince1970 * 1000))
                        log.append(LogEntry(taskId: t.id, date: key, time: "12:08", value: 30, ts: d.timeIntervalSince1970 * 1000))
                    } else {
                        let target = t.target ?? 100
                        let sets = t.id == "t-water" ? 8 : 3
                        let each = Int(target) / sets
                        let remainder = Int(target) - each * sets
                        for i in 0..<sets {
                            let v = Double(each + (i < remainder ? 1 : 0))
                            let baseH = t.id == "t-water" ? 7 : 8
                            let time = String(format: "%02d:%02d", baseH + i * 2, 10 + i * 5)
                            log.append(LogEntry(taskId: t.id, date: key, time: time, value: v, ts: d.timeIntervalSince1970 * 1000))
                        }
                    }

                case .timer:
                    if partialRead && t.id == "t-read" {
                        log.append(LogEntry(taskId: t.id, date: key, time: t.times[0], value: 12, ts: d.timeIntervalSince1970 * 1000))
                    } else {
                        log.append(LogEntry(taskId: t.id, date: key, time: t.times[0], value: t.target ?? 0, ts: d.timeIntervalSince1970 * 1000))
                    }
                }
            }
        }

        // Today's partial log
        let todayKey = localDateKey(today)
        let ts = today.timeIntervalSince1970 * 1000
        log.append(LogEntry(taskId: "t-vit",     date: todayKey, time: "07:34", value: 1.0,  ts: ts))
        log.append(LogEntry(taskId: "t-weigh",   date: todayKey, time: "07:38", value: 74.2, ts: ts))
        log.append(LogEntry(taskId: "t-stretch", date: todayKey, time: "08:02", value: 1.0,  ts: ts))
        log.append(LogEntry(taskId: "t-push",    date: todayKey, time: "08:14", value: 20,   ts: ts))
        log.append(LogEntry(taskId: "t-push",    date: todayKey, time: "12:08", value: 25,   ts: ts))
        log.append(LogEntry(taskId: "t-push",    date: todayKey, time: "13:45", value: 20,   ts: ts))
        log.append(LogEntry(taskId: "t-water",   date: todayKey, time: "07:10", value: 16,   ts: ts))
        log.append(LogEntry(taskId: "t-water",   date: todayKey, time: "08:30", value: 16,   ts: ts))
        log.append(LogEntry(taskId: "t-water",   date: todayKey, time: "10:00", value: 16,   ts: ts))
        log.append(LogEntry(taskId: "t-water",   date: todayKey, time: "11:15", value: 16,   ts: ts))
        log.append(LogEntry(taskId: "t-water",   date: todayKey, time: "12:45", value: 8,    ts: ts))
        log.append(LogEntry(taskId: "t-water",   date: todayKey, time: "13:30", value: 16,   ts: ts))
        log.append(LogEntry(taskId: "t-walk",    date: todayKey, time: "12:55", value: 32,   ts: ts))

        return log
    }

    static func seedIfNeeded(context: ModelContext) {
        let descriptor = FetchDescriptor<TallyTask>()
        let count = (try? context.fetchCount(descriptor)) ?? 0
        guard count == 0 else { return }

        for task in tasks {
            context.insert(task)
        }
        for entry in buildLog() {
            context.insert(entry)
        }
    }
}
#endif
