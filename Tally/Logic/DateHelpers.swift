//
//  DateHelpers.swift
//  Tally
//
//  Pure date utilities. No side effects.
//  Convention: Mon=0, Tue=1, Wed=2, Thu=3, Fri=4, Sat=5, Sun=6

import Foundation

/// Format a Date as "YYYY-MM-DD" in the current calendar/timezone.
func localDateKey(_ date: Date) -> String {
    let cal = Calendar.current
    let y = cal.component(.year, from: date)
    let m = cal.component(.month, from: date)
    let d = cal.component(.day, from: date)
    return String(format: "%04d-%02d-%02d", y, m, d)
}

/// Format a Date as "HH:MM" in the current calendar/timezone.
func localTimeKey(_ date: Date) -> String {
    let cal = Calendar.current
    let h = cal.component(.hour, from: date)
    let m = cal.component(.minute, from: date)
    return String(format: "%02d:%02d", h, m)
}

/// Day of week: 0=Mon, 1=Tue, ... 6=Sun.
/// Apple's Calendar uses 1=Sun, 2=Mon, ..., 7=Sat — we remap.
func dayOfWeek(_ date: Date) -> Int {
    let wd = Calendar.current.component(.weekday, from: date) // 1=Sun..7=Sat
    return (wd + 5) % 7 // 0=Mon..6=Sun
}

/// Midnight of the given date.
func startOfDay(_ date: Date) -> Date {
    Calendar.current.startOfDay(for: date)
}

/// Add (or subtract) days, returning midnight of the resulting date.
func addDays(_ date: Date, _ n: Int) -> Date {
    let result = Calendar.current.date(byAdding: .day, value: n, to: date)!
    return startOfDay(result)
}

/// Parse "HH:MM" into components.
struct HHMMComponents {
    let h: Int
    let m: Int
    var mins: Int { h * 60 + m }
}

func parseHHMM(_ s: String) -> HHMMComponents {
    let parts = s.split(separator: ":").compactMap { Int($0) }
    guard parts.count == 2 else { return HHMMComponents(h: 0, m: 0) }
    return HHMMComponents(h: parts[0], m: parts[1])
}

/// Minutes since midnight for a given Date.
func minutesSinceMidnight(_ date: Date) -> Int {
    let cal = Calendar.current
    return cal.component(.hour, from: date) * 60 + cal.component(.minute, from: date)
}

// MARK: - Display constants

let dayLabels = ["M", "T", "W", "T", "F", "S", "S"]
let dayNames = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
let monthNamesShort = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
