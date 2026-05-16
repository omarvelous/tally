//
//  DayCompletionTests.swift
//  TallyTests
//

import XCTest
@testable import Tally

final class DayCompletionTests: XCTestCase {

    private func today() -> Date { Calendar.current.startOfDay(for: Date()) }
    private func todayKey() -> String { localDateKey(today()) }
    private func makeNow(hour: Int) -> Date {
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        comps.hour = hour
        return Calendar.current.date(from: comps)!
    }

    func testAllDone() {
        let now = makeNow(hour: 22)
        let task1 = TallyTask(id: "t1", name: "Check", type: .check, days: [], times: ["07:30"])
        let task2 = TallyTask(id: "t2", name: "Count", type: .count, target: 10, unit: "reps", days: [], times: ["08:00"])
        let entries = [
            LogEntry(taskId: "t1", date: todayKey(), time: "07:34", value: 1.0),
            LogEntry(taskId: "t2", date: todayKey(), time: "08:14", value: 10),
        ]
        let result = dayCompletionFor(date: today(), tasks: [task1, task2], entries: entries, now: now)
        XCTAssertEqual(result.done, 2)
        XCTAssertEqual(result.total, 2)
        XCTAssertEqual(result.pct, 1.0)
    }

    func testPartialDay() {
        let now = makeNow(hour: 22)
        let task1 = TallyTask(id: "t1", name: "Check", type: .check, days: [], times: ["07:30"])
        let task2 = TallyTask(id: "t2", name: "Count", type: .count, target: 10, unit: "reps", days: [], times: ["08:00"])
        let entries = [
            LogEntry(taskId: "t1", date: todayKey(), time: "07:34", value: 1.0),
            // task2 only partially done
            LogEntry(taskId: "t2", date: todayKey(), time: "08:14", value: 5),
        ]
        let result = dayCompletionFor(date: today(), tasks: [task1, task2], entries: entries, now: now)
        XCTAssertEqual(result.done, 1)
        XCTAssertEqual(result.partial, 1)
        XCTAssertEqual(result.pct, 0.5)
    }

    func testNoTasksScheduled() {
        // Tasks only scheduled on weekdays, test on a weekend day
        let task = TallyTask(name: "Work", type: .check, days: [0, 1, 2, 3, 4], times: ["09:00"])
        // Find next Saturday (dow=5)
        var testDate = today()
        while dayOfWeek(testDate) != 5 {
            testDate = addDays(testDate, 1)
        }
        let result = dayCompletionFor(date: testDate, tasks: [task], entries: [], now: makeNow(hour: 12))
        XCTAssertEqual(result.total, 0)
        XCTAssertEqual(result.pct, 0)
    }

    func testArchivedTasksExcluded() {
        let active = TallyTask(id: "t1", name: "Active", type: .check, days: [], times: ["07:30"])
        let archived = TallyTask(id: "t2", name: "Archived", type: .check, days: [], times: ["07:30"], archived: true)
        let entries = [
            LogEntry(taskId: "t1", date: todayKey(), time: "07:34", value: 1.0),
        ]
        let result = dayCompletionFor(date: today(), tasks: [active, archived], entries: entries, now: makeNow(hour: 22))
        XCTAssertEqual(result.total, 1)
        XCTAssertEqual(result.done, 1)
        XCTAssertEqual(result.pct, 1.0)
    }
}
