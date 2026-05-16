//
//  MonthCalendarView.swift
//  Tally
//
//  Paginated month grid with days color-coded by completion.

import SwiftUI

struct MonthCalendarView: View {
    let year: Int
    let month: Int  // 1-based
    let tasks: [TallyTask]
    let entries: [LogEntry]
    let now: Date

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let c = TallyColors.resolve(colorScheme)
        let cells = buildCells()
        let pastCells = cells.compactMap { $0 }.filter { !$0.isFuture }
        let earned = pastCells.filter { $0.day.total > 0 && $0.day.pct >= 1 }.count
        let rate = pastCells.isEmpty ? 0 : Int((Double(earned) / Double(pastCells.count) * 100).rounded())
        let weeks = stride(from: 0, to: cells.count, by: 7).map { Array(cells[$0..<min($0 + 7, cells.count)]) }

        VStack(spacing: 6) {
            Text(verbatim: "\(earned) EARNED · \(rate)% RATE")
                .font(TallyFont.mono(10))
                .tracking(1.0)
                .foregroundStyle(c.dim)

            // Day-of-week header
            HStack(spacing: 4) {
                ForEach(Array(["M","T","W","T","F","S","S"].enumerated()), id: \.offset) { _, label in
                    Text(verbatim: label)
                        .font(TallyFont.mono(9))
                        .foregroundStyle(c.dim)
                        .frame(maxWidth: .infinity)
                }
            }

            // Week rows
            ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                HStack(spacing: 4) {
                    ForEach(Array(week.enumerated()), id: \.offset) { _, cell in
                        if let cell = cell {
                            dayCellView(cell: cell, c: c)
                        } else {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.clear)
                                .frame(maxWidth: .infinity)
                                .frame(height: 36)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func dayCellView(cell: DayCell, c: TallyColors) -> some View {
        let isEarned = cell.day.total > 0 && cell.day.pct >= 1
        let isPartial = cell.day.pct > 0 && cell.day.pct < 1
        let isRest = cell.day.total == 0
        let bg: Color = cell.isFuture ? .clear : isEarned ? c.accent : isPartial ? c.accentSoft : isRest ? c.bg3.opacity(0.5) : c.bg3
        let fg: Color = isEarned ? .white : cell.isFuture ? c.dim3 : c.dim
        let dayText = "\(Calendar.current.component(.day, from: cell.date))"

        if cell.isFuture {
            Text(verbatim: dayText)
                .font(TallyFont.mono(11, weight: .semibold))
                .monospacedDigit()
                .frame(maxWidth: .infinity)
                .frame(height: 36)
                .foregroundStyle(fg)
        } else {
            NavigationLink(value: localDateKey(cell.date)) {
                Text(verbatim: dayText)
                    .font(TallyFont.mono(11, weight: .semibold))
                    .monospacedDigit()
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
                    .background(bg)
                    .foregroundStyle(fg)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(cell.isToday ? c.text : .clear, lineWidth: 1.5)
                    )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Grid computation

    private struct DayCell {
        let date: Date
        let day: DayCompletion
        let isToday: Bool
        let isFuture: Bool
    }

    private func buildCells() -> [DayCell?] {
        var cells: [DayCell?] = []
        let cal = Calendar.current

        let firstOfMonth = cal.date(from: DateComponents(year: year, month: month, day: 1))!
        let firstDow = (cal.component(.weekday, from: firstOfMonth) + 5) % 7 // Mon=0
        let daysInMonth = cal.range(of: .day, in: .month, for: firstOfMonth)!.count

        for _ in 0..<firstDow { cells.append(nil) }

        for d in 1...daysInMonth {
            let date = cal.date(from: DateComponents(year: year, month: month, day: d))!
            let day = dayCompletionFor(date: date, tasks: tasks, entries: entries, now: now)
            let isToday = localDateKey(date) == localDateKey(now)
            let isFuture = startOfDay(date) > startOfDay(now)
            cells.append(DayCell(date: date, day: day, isToday: isToday, isFuture: isFuture))
        }

        while cells.count % 7 != 0 { cells.append(nil) }

        return cells
    }
}
