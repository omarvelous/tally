//
//  TaskStateTests.swift
//  TallyTests
//
//  Tests for the taskStateFor selector across all 5 task types.

import XCTest
@testable import Tally

final class TaskStateTests: XCTestCase {

    // Helper to create a date at a specific time today
    private func makeNow(hour: Int, minute: Int = 0) -> Date {
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        comps.hour = hour
        comps.minute = minute
        return Calendar.current.date(from: comps)!
    }

    private func today() -> Date {
        Calendar.current.startOfDay(for: Date())
    }

    private func todayKey() -> String {
        localDateKey(today())
    }

    // MARK: - Check type

    func testCheckDone() {
        let task = TallyTask(name: "Vitamins", type: .check, days: [], times: ["07:30"])
        let entry = LogEntry(taskId: task.id, date: todayKey(), time: "07:34", value: 1.0)
        let state = taskStateFor(task: task, date: today(), entries: [entry], now: makeNow(hour: 10))
        XCTAssertEqual(state.status, .done)
        XCTAssertEqual(state.pct, 1.0)
    }

    func testCheckDueBeforeTime() {
        let task = TallyTask(name: "Vitamins", type: .check, days: [], times: ["14:00"])
        let state = taskStateFor(task: task, date: today(), entries: [], now: makeNow(hour: 10))
        XCTAssertEqual(state.status, .due)
        XCTAssertEqual(state.pct, 0)
    }

    func testCheckOverdueAfterTime() {
        let task = TallyTask(name: "Vitamins", type: .check, days: [], times: ["07:30"])
        let state = taskStateFor(task: task, date: today(), entries: [], now: makeNow(hour: 10))
        XCTAssertEqual(state.status, .overdue)
    }

    // MARK: - YesNo type

    func testYesNoDoneWithYes() {
        let task = TallyTask(name: "Stretch", type: .yesno, days: [], times: ["08:00"])
        let entry = LogEntry(taskId: task.id, date: todayKey(), time: "08:05", value: 1.0)
        let state = taskStateFor(task: task, date: today(), entries: [entry], now: makeNow(hour: 10))
        XCTAssertEqual(state.status, .done)
        XCTAssertEqual(state.label, "Yes")
    }

    func testYesNoDueBeforeTime() {
        let task = TallyTask(name: "Stretch", type: .yesno, days: [], times: ["08:00"])
        let state = taskStateFor(task: task, date: today(), entries: [], now: makeNow(hour: 7))
        XCTAssertEqual(state.status, .due)
    }

    // MARK: - Numeric type

    func testNumericDoneWithEntry() {
        let task = TallyTask(name: "Weigh-in", type: .numeric, unit: "kg", days: [], times: ["07:30"])
        let entry = LogEntry(taskId: task.id, date: todayKey(), time: "07:38", value: 74.2)
        let state = taskStateFor(task: task, date: today(), entries: [entry], now: makeNow(hour: 10))
        XCTAssertEqual(state.status, .done)
        XCTAssertEqual(state.pct, 1.0)
        XCTAssertEqual(state.value, 74.2)
        XCTAssertTrue(state.label.contains("74.2"))
    }

    func testNumericDueNoEntry() {
        let task = TallyTask(name: "Weigh-in", type: .numeric, unit: "kg", days: [], times: ["07:30"])
        let state = taskStateFor(task: task, date: today(), entries: [], now: makeNow(hour: 6))
        XCTAssertEqual(state.status, .due)
    }

    // MARK: - Count type

    func testCountDoneExactTarget() {
        let task = TallyTask(name: "Push-ups", type: .count, target: 100, unit: "reps", days: [], times: ["08:00"])
        let entries = [
            LogEntry(taskId: task.id, date: todayKey(), time: "08:14", value: 30),
            LogEntry(taskId: task.id, date: todayKey(), time: "12:08", value: 40),
            LogEntry(taskId: task.id, date: todayKey(), time: "18:00", value: 30),
        ]
        let state = taskStateFor(task: task, date: today(), entries: entries, now: makeNow(hour: 20))
        XCTAssertEqual(state.status, .done)
        XCTAssertEqual(state.pct, 1.0)
        XCTAssertEqual(state.sum, 100)
        XCTAssertEqual(state.count, 3)
    }

    func testCountPartial() {
        let task = TallyTask(name: "Push-ups", type: .count, target: 100, unit: "reps", days: [], times: ["08:00"])
        let entries = [
            LogEntry(taskId: task.id, date: todayKey(), time: "08:14", value: 30),
            LogEntry(taskId: task.id, date: todayKey(), time: "12:08", value: 30),
        ]
        let state = taskStateFor(task: task, date: today(), entries: entries, now: makeNow(hour: 14))
        XCTAssertEqual(state.status, .partial)
        XCTAssertEqual(state.sum, 60)
        XCTAssertEqual(state.pct, 0.6, accuracy: 0.01)
    }

    func testCountOverdueNoEntries() {
        let task = TallyTask(name: "Push-ups", type: .count, target: 100, unit: "reps", days: [], times: ["08:00"])
        let state = taskStateFor(task: task, date: today(), entries: [], now: makeNow(hour: 12))
        XCTAssertEqual(state.status, .overdue)
        XCTAssertEqual(state.sum, 0)
    }

    func testCountDueBeforeTime() {
        let task = TallyTask(name: "Push-ups", type: .count, target: 100, unit: "reps", days: [], times: ["08:00"])
        let state = taskStateFor(task: task, date: today(), entries: [], now: makeNow(hour: 7))
        XCTAssertEqual(state.status, .due)
    }

    // MARK: - Timer type

    func testTimerDone() {
        let task = TallyTask(name: "Read", type: .timer, target: 20, unit: "min", days: [], times: ["21:00"])
        let entry = LogEntry(taskId: task.id, date: todayKey(), time: "21:05", value: 25)
        let state = taskStateFor(task: task, date: today(), entries: [entry], now: makeNow(hour: 22))
        XCTAssertEqual(state.status, .done)
        XCTAssertEqual(state.pct, 1.0)
    }

    func testTimerPartial() {
        let task = TallyTask(name: "Read", type: .timer, target: 20, unit: "min", days: [], times: ["21:00"])
        let entry = LogEntry(taskId: task.id, date: todayKey(), time: "21:05", value: 12)
        let state = taskStateFor(task: task, date: today(), entries: [entry], now: makeNow(hour: 22))
        XCTAssertEqual(state.status, .partial)
        XCTAssertEqual(state.pct, 0.6, accuracy: 0.01)
    }

    // MARK: - Off-schedule

    func testOffScheduleDay() {
        // Task scheduled only Mon/Wed/Fri (0,2,4) — test on a day that's NOT one of those
        let task = TallyTask(name: "Squats", type: .count, target: 50, unit: "reps", days: [0, 2, 4], times: ["18:00"])
        // Find next Tuesday (dow=1)
        var testDate = today()
        while dayOfWeek(testDate) != 1 {
            testDate = addDays(testDate, 1)
        }
        let state = taskStateFor(task: task, date: testDate, entries: [], now: makeNow(hour: 12))
        XCTAssertEqual(state.status, .off)
    }

    // MARK: - Past date

    func testPastDateMissed() {
        let task = TallyTask(name: "Vitamins", type: .check, days: [], times: ["07:30"])
        let yesterday = addDays(today(), -1)
        let state = taskStateFor(task: task, date: yesterday, entries: [], now: makeNow(hour: 10))
        XCTAssertEqual(state.status, .overdue)
    }

    func testPastDateDone() {
        let task = TallyTask(name: "Vitamins", type: .check, days: [], times: ["07:30"])
        let yesterday = addDays(today(), -1)
        let yesterdayKey = localDateKey(yesterday)
        let entry = LogEntry(taskId: task.id, date: yesterdayKey, time: "07:34", value: 1.0)
        let state = taskStateFor(task: task, date: yesterday, entries: [entry], now: makeNow(hour: 10))
        XCTAssertEqual(state.status, .done)
    }

    // MARK: - All-day tasks

    func testAllDayTaskDueBeforeMidnight() {
        let task = TallyTask(name: "Water", type: .count, target: 128, unit: "oz", days: [], times: ["all-day"])
        let state = taskStateFor(task: task, date: today(), entries: [], now: makeNow(hour: 14))
        // All-day due time is 23:59 — so before that, it's just "due", not overdue
        XCTAssertEqual(state.status, .due)
    }

    func testAllDayTaskPartial() {
        let task = TallyTask(name: "Water", type: .count, target: 128, unit: "oz", days: [], times: ["all-day"])
        let entries = [
            LogEntry(taskId: task.id, date: todayKey(), time: "07:10", value: 16),
            LogEntry(taskId: task.id, date: todayKey(), time: "08:30", value: 16),
        ]
        let state = taskStateFor(task: task, date: today(), entries: entries, now: makeNow(hour: 10))
        XCTAssertEqual(state.status, .partial)
        XCTAssertEqual(state.sum, 32)
    }

    // MARK: - Entries from other tasks don't interfere

    func testEntriesFilteredByTaskId() {
        let task1 = TallyTask(id: "t1", name: "Task1", type: .check, days: [], times: ["08:00"])
        let task2 = TallyTask(id: "t2", name: "Task2", type: .check, days: [], times: ["08:00"])
        let entry = LogEntry(taskId: "t2", date: todayKey(), time: "08:05", value: 1.0)
        let state = taskStateFor(task: task1, date: today(), entries: [entry], now: makeNow(hour: 10))
        XCTAssertEqual(state.status, .overdue) // task1 has no entries
    }
}
