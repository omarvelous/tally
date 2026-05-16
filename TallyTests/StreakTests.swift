//
//  StreakTests.swift
//  TallyTests
//

import XCTest
@testable import Tally

final class StreakTests: XCTestCase {

    private func today() -> Date { Calendar.current.startOfDay(for: Date()) }
    private func makeNow(hour: Int) -> Date {
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        comps.hour = hour
        return Calendar.current.date(from: comps)!
    }

    /// Helper: create entries that mark a check task as done on the given dates.
    private func makeEntries(taskId: String, daysBack: [Int]) -> [LogEntry] {
        daysBack.map { offset in
            let d = addDays(today(), -offset)
            return LogEntry(taskId: taskId, date: localDateKey(d), time: "08:00", value: 1.0)
        }
    }

    func testConsecutiveStreak() {
        let now = makeNow(hour: 22)
        let task = TallyTask(id: "t1", name: "Check", type: .check, days: [], times: ["08:00"])
        // Done yesterday, 2 days ago, 3 days ago (3-day streak from yesterday)
        let entries = makeEntries(taskId: "t1", daysBack: [1, 2, 3])
        let result = streakFor(tasks: [task], entries: entries, now: now)
        XCTAssertEqual(result.current, 3)
    }

    func testTodayIncludedIfDone() {
        let now = makeNow(hour: 22)
        let task = TallyTask(id: "t1", name: "Check", type: .check, days: [], times: ["08:00"])
        // Done today, yesterday, 2 days ago
        let entries = makeEntries(taskId: "t1", daysBack: [0, 1, 2])
        let result = streakFor(tasks: [task], entries: entries, now: now)
        XCTAssertEqual(result.current, 3)
    }

    func testTodayExcludedIfNotDone() {
        let now = makeNow(hour: 10) // morning, task not yet done today
        let task = TallyTask(id: "t1", name: "Check", type: .check, days: [], times: ["08:00"])
        // Done yesterday and 2 days ago, but NOT today
        let entries = makeEntries(taskId: "t1", daysBack: [1, 2])
        let result = streakFor(tasks: [task], entries: entries, now: now)
        XCTAssertEqual(result.current, 2)
    }

    func testBrokenStreak() {
        let now = makeNow(hour: 22)
        let task = TallyTask(id: "t1", name: "Check", type: .check, days: [], times: ["08:00"])
        // Done yesterday and 3 days ago, but NOT 2 days ago — streak is 1
        let entries = makeEntries(taskId: "t1", daysBack: [1, 3])
        let result = streakFor(tasks: [task], entries: entries, now: now)
        XCTAssertEqual(result.current, 1)
    }

    func testBestStreakTracked() {
        let now = makeNow(hour: 22)
        let task = TallyTask(id: "t1", name: "Check", type: .check, days: [], times: ["08:00"])
        // 5-day streak from 10-6 days ago, then a gap, then 2-day streak (yesterday + today)
        let entries = makeEntries(taskId: "t1", daysBack: [0, 1, 6, 7, 8, 9, 10])
        let result = streakFor(tasks: [task], entries: entries, now: now)
        XCTAssertEqual(result.current, 2)
        XCTAssertEqual(result.best, 5)
    }

    func testNoEntriesZeroStreak() {
        let now = makeNow(hour: 22)
        let task = TallyTask(id: "t1", name: "Check", type: .check, days: [], times: ["08:00"])
        let result = streakFor(tasks: [task], entries: [], now: now)
        XCTAssertEqual(result.current, 0)
        XCTAssertEqual(result.best, 0)
    }

    func testHistoryLength() {
        let now = makeNow(hour: 12)
        let task = TallyTask(id: "t1", name: "Check", type: .check, days: [], times: ["08:00"])
        let result = streakFor(tasks: [task], entries: [], now: now)
        XCTAssertEqual(result.history.count, 61) // 60 days back + today
        XCTAssertTrue(result.history.last!.isToday)
        XCTAssertFalse(result.history.first!.isToday)
    }
}
