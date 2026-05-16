//
//  DateHelperTests.swift
//  TallyTests
//

import XCTest
@testable import Tally

final class DateHelperTests: XCTestCase {

    // MARK: - localDateKey

    func testDateKeyFormat() {
        // Jan 15, 2026 at noon
        var comps = DateComponents()
        comps.year = 2026; comps.month = 1; comps.day = 15
        comps.hour = 12; comps.minute = 30
        let date = Calendar.current.date(from: comps)!
        XCTAssertEqual(localDateKey(date), "2026-01-15")
    }

    func testDateKeyPadsMonth() {
        var comps = DateComponents()
        comps.year = 2026; comps.month = 3; comps.day = 5
        let date = Calendar.current.date(from: comps)!
        XCTAssertEqual(localDateKey(date), "2026-03-05")
    }

    // MARK: - localTimeKey

    func testTimeKeyFormat() {
        var comps = DateComponents()
        comps.year = 2026; comps.month = 1; comps.day = 1
        comps.hour = 8; comps.minute = 5
        let date = Calendar.current.date(from: comps)!
        XCTAssertEqual(localTimeKey(date), "08:05")
    }

    // MARK: - dayOfWeek

    func testDayOfWeekMonday() {
        // 2026-05-11 is a Monday
        var comps = DateComponents()
        comps.year = 2026; comps.month = 5; comps.day = 11
        let date = Calendar.current.date(from: comps)!
        XCTAssertEqual(dayOfWeek(date), 0) // Mon=0
    }

    func testDayOfWeekSunday() {
        // 2026-05-17 is a Sunday
        var comps = DateComponents()
        comps.year = 2026; comps.month = 5; comps.day = 17
        let date = Calendar.current.date(from: comps)!
        XCTAssertEqual(dayOfWeek(date), 6) // Sun=6
    }

    func testDayOfWeekWednesday() {
        // 2026-05-13 is a Wednesday
        var comps = DateComponents()
        comps.year = 2026; comps.month = 5; comps.day = 13
        let date = Calendar.current.date(from: comps)!
        XCTAssertEqual(dayOfWeek(date), 2) // Wed=2
    }

    // MARK: - addDays

    func testAddDaysForward() {
        var comps = DateComponents()
        comps.year = 2026; comps.month = 5; comps.day = 15
        comps.hour = 14; comps.minute = 30
        let date = Calendar.current.date(from: comps)!
        let result = addDays(date, 3)
        XCTAssertEqual(localDateKey(result), "2026-05-18")
        // Should be at midnight
        XCTAssertEqual(Calendar.current.component(.hour, from: result), 0)
    }

    func testAddDaysBackward() {
        var comps = DateComponents()
        comps.year = 2026; comps.month = 5; comps.day = 15
        let date = Calendar.current.date(from: comps)!
        let result = addDays(date, -5)
        XCTAssertEqual(localDateKey(result), "2026-05-10")
    }

    // MARK: - parseHHMM

    func testParseHHMM() {
        let result = parseHHMM("14:30")
        XCTAssertEqual(result.h, 14)
        XCTAssertEqual(result.m, 30)
        XCTAssertEqual(result.mins, 870)
    }

    func testParseHHMMEarlyMorning() {
        let result = parseHHMM("07:05")
        XCTAssertEqual(result.h, 7)
        XCTAssertEqual(result.m, 5)
        XCTAssertEqual(result.mins, 425)
    }
}
