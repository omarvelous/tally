//
//  StreakScreen.swift
//  Tally
//
//  Streak screen: reads from DaySummary (V2 materialized data).

import SwiftUI
import SwiftData

struct StreakScreen: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @Environment(AuthService.self) private var auth
    @Query private var allSummaries: [DaySummary]

    @State private var monthOffset = 0

    var body: some View {
        let c = TallyColors.resolve(colorScheme)
        let now = Date()
        let profileId = auth.userId ?? ""
        let history = buildHistory(profileId: profileId, now: now)
        let streak = computeCurrentStreak(history: history)
        let best = computeBestStreak(history: history)
        let avgPct = history.isEmpty ? 0 : Int((history.reduce(0.0) { $0 + $1.pct } / Double(history.count) * 100).rounded())
        let earned60 = history.filter { $0.total > 0 && $0.pct >= 1 }.count

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 4) {
                        Text("STREAK · HISTORY")
                            .font(TallyFont.label())
                            .textCase(.uppercase)
                            .tracking(1.2)
                            .foregroundStyle(c.dim)
                        Text("Streak")
                            .font(TallyFont.heading(32, weight: .medium))
                            .foregroundStyle(c.text)
                    }
                    .padding(.top, 8)

                    // Hero card
                    heroCard(streak: streak, best: best, history: history, c: c)

                    // Stat tiles
                    HStack(spacing: 8) {
                        StatTile(label: "BEST", value: "\(best)d")
                        StatTile(label: "EARNED 60D", value: "\(earned60)")
                        StatTile(label: "AVG", value: "\(avgPct)%")
                    }

                    // Month calendar
                    monthCalendar(profileId: profileId, now: now, c: c)

                    Text("TAP A DAY TO REVIEW")
                        .font(TallyFont.mono(10))
                        .tracking(1.4)
                        .foregroundStyle(c.dim)
                        .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .background(c.bg)
            .navigationDestination(for: String.self) { dateKey in
                DayDetailView(dateString: dateKey)
            }
        }
    }

    // MARK: - Data

    private struct DaySnap: Sendable {
        let date: String
        let pct: Double
        let total: Int
        let done: Int
        let isToday: Bool
    }

    private func buildHistory(profileId: String, now: Date) -> [DaySnap] {
        let byDate = Dictionary(
            allSummaries.filter { $0.profileId == profileId }.map { ($0.date, $0) },
            uniquingKeysWith: { a, _ in a }
        )
        return (0...60).reversed().map { i in
            let d = addDays(now, -i)
            let key = localDateKey(d)
            let summary = byDate[key]
            return DaySnap(
                date: key,
                pct: summary?.pct ?? 0,
                total: summary?.total ?? 0,
                done: summary?.done ?? 0,
                isToday: i == 0
            )
        }
    }

    private func computeCurrentStreak(history: [DaySnap]) -> Int {
        var streak = 0
        if let today = history.last, today.total > 0 && today.pct >= 1 { streak = 1 }
        for i in stride(from: history.count - 2, through: 0, by: -1) {
            let h = history[i]
            if h.total == 0 { continue }
            if h.pct >= 1 { streak += 1 } else { break }
        }
        return streak
    }

    private func computeBestStreak(history: [DaySnap]) -> Int {
        var best = 0, run = 0
        for h in history {
            if h.total > 0 && h.pct >= 1 { run += 1; best = max(best, run) } else { run = 0 }
        }
        return best
    }

    // MARK: - Hero card

    private func heroCard(streak: Int, best: Int, history: [DaySnap], c: TallyColors) -> some View {
        TallyCard {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text("CURRENT")
                        .font(TallyFont.label())
                        .textCase(.uppercase)
                        .tracking(1.2)
                        .foregroundStyle(c.dim)
                    Spacer()
                    Text(streak > 0 ? "SINCE \(streakStartLabel(streak, history))" : "WAITING TO START")
                        .font(TallyFont.mono(11))
                        .foregroundStyle(c.dim)
                }

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\(streak)")
                        .font(TallyFont.heading(80, weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle(streak > 0 ? c.accent : c.dim)
                    Text("day\(streak == 1 ? "" : "s")")
                        .font(TallyFont.heading(22, weight: .medium))
                        .foregroundStyle(c.dim)
                    Spacer()
                    Text(streak >= best && streak > 0 ? "↑ ALL-TIME BEST" : "BEST · \(best)d")
                        .font(TallyFont.mono(10))
                        .foregroundStyle(streak >= best && streak > 0 ? c.pos : c.dim)
                }

                // 30-day strip
                HStack(spacing: 2) {
                    ForEach(Array(history.suffix(30).enumerated()), id: \.offset) { _, day in
                        let barColor: Color = day.total == 0 ? c.bg3 : day.pct >= 1 ? c.accent : day.pct > 0 ? c.accentSoft : c.bg3
                        NavigationLink(value: day.date) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(barColor)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 2)
                                        .stroke(day.isToday ? c.accent : .clear, lineWidth: 1.5)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(height: 36)

                HStack {
                    Text("30 DAYS AGO").font(TallyFont.mono(10)).foregroundStyle(c.dim)
                    Spacer()
                    Text("TODAY").font(TallyFont.mono(10)).foregroundStyle(c.dim)
                }
            }
        }
    }

    // MARK: - Month calendar

    private func monthCalendar(profileId: String, now: Date, c: TallyColors) -> some View {
        let cal = Calendar.current
        let viewMonth = cal.date(byAdding: .month, value: monthOffset, to: now)!
        let year = cal.component(.year, from: viewMonth)
        let month = cal.component(.month, from: viewMonth)
        let monthNames = ["January", "February", "March", "April", "May", "June",
                          "July", "August", "September", "October", "November", "December"]

        return VStack(spacing: 10) {
            HStack {
                Button { monthOffset -= 1 } label: {
                    Text("‹ PREV").font(TallyFont.mono(11, weight: .semibold)).tracking(1.0).foregroundStyle(c.dim)
                }
                Spacer()
                Text("\(monthNames[month - 1]) \(year)")
                    .font(TallyFont.heading(15, weight: .medium))
                    .foregroundStyle(c.text)
                Spacer()
                Button { monthOffset = min(0, monthOffset + 1) } label: {
                    Text("NEXT ›").font(TallyFont.mono(11, weight: .semibold)).tracking(1.0)
                        .foregroundStyle(monthOffset == 0 ? c.dim2 : c.dim)
                }
                .disabled(monthOffset == 0)
            }

            MonthCalendarV2(year: year, month: month, profileId: profileId, now: now)
        }
    }

    private func streakStartLabel(_ streak: Int, _ history: [DaySnap]) -> String {
        guard streak > 0 else { return "—" }
        let firstDayIdx = history.count - streak
        guard firstDayIdx >= 0 && firstDayIdx < history.count else { return "—" }
        let dateStr = history[firstDayIdx].date
        let parts = dateStr.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return "—" }
        return "\(monthNamesShort[parts[1] - 1].uppercased()) \(parts[2])"
    }
}

// MARK: - V2 Month Calendar (reads DaySummary)

struct MonthCalendarV2: View {
    let year: Int
    let month: Int
    let profileId: String
    let now: Date

    @Environment(\.colorScheme) private var colorScheme
    @Query private var allSummaries: [DaySummary]

    var body: some View {
        let c = TallyColors.resolve(colorScheme)
        let cells = buildCells()
        let pastCells = cells.compactMap { $0 }.filter { !$0.isFuture }
        let earned = pastCells.filter { $0.total > 0 && $0.pct >= 1 }.count
        let rate = pastCells.isEmpty ? 0 : Int((Double(earned) / Double(pastCells.count) * 100).rounded())
        let weeks = stride(from: 0, to: cells.count, by: 7).map { Array(cells[$0..<min($0 + 7, cells.count)]) }

        VStack(spacing: 6) {
            Text(verbatim: "\(earned) EARNED · \(rate)% RATE")
                .font(TallyFont.mono(10))
                .tracking(1.0)
                .foregroundStyle(c.dim)

            HStack(spacing: 4) {
                ForEach(["M","T","W","T","F","S","S"], id: \.self) { label in
                    Text(verbatim: label).font(TallyFont.mono(9)).foregroundStyle(c.dim).frame(maxWidth: .infinity)
                }
            }

            ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                HStack(spacing: 4) {
                    ForEach(Array(week.enumerated()), id: \.offset) { _, cell in
                        if let cell = cell {
                            dayCellView(cell: cell, c: c)
                        } else {
                            RoundedRectangle(cornerRadius: 6).fill(Color.clear).frame(maxWidth: .infinity).frame(height: 36)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func dayCellView(cell: DayCell, c: TallyColors) -> some View {
        let isEarned = cell.total > 0 && cell.pct >= 1
        let isPartial = cell.pct > 0 && cell.pct < 1
        let isRest = cell.total == 0
        let bg: Color = cell.isFuture ? .clear : isEarned ? c.accent : isPartial ? c.accentSoft : isRest ? c.bg3.opacity(0.5) : c.bg3
        let fg: Color = isEarned ? .white : cell.isFuture ? c.dim3 : c.dim
        let dayText = "\(Calendar.current.component(.day, from: cell.date))"

        if cell.isFuture {
            Text(verbatim: dayText).font(TallyFont.mono(11, weight: .semibold)).monospacedDigit()
                .frame(maxWidth: .infinity).frame(height: 36).foregroundStyle(fg)
        } else {
            NavigationLink(value: localDateKey(cell.date)) {
                Text(verbatim: dayText).font(TallyFont.mono(11, weight: .semibold)).monospacedDigit()
                    .frame(maxWidth: .infinity).frame(height: 36)
                    .background(bg).foregroundStyle(fg).clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(cell.isToday ? c.text : .clear, lineWidth: 1.5))
            }
            .buttonStyle(.plain)
        }
    }

    private struct DayCell {
        let date: Date
        let pct: Double
        let total: Int
        let isToday: Bool
        let isFuture: Bool
    }

    private func buildCells() -> [DayCell?] {
        let byDate = Dictionary(
            allSummaries.filter { $0.profileId == profileId }.map { ($0.date, $0) },
            uniquingKeysWith: { a, _ in a }
        )
        var cells: [DayCell?] = []
        let cal = Calendar.current
        let firstOfMonth = cal.date(from: DateComponents(year: year, month: month, day: 1))!
        let firstDow = (cal.component(.weekday, from: firstOfMonth) + 5) % 7
        let daysInMonth = cal.range(of: .day, in: .month, for: firstOfMonth)!.count

        for _ in 0..<firstDow { cells.append(nil) }
        for d in 1...daysInMonth {
            let date = cal.date(from: DateComponents(year: year, month: month, day: d))!
            let key = localDateKey(date)
            let summary = byDate[key]
            cells.append(DayCell(
                date: date,
                pct: summary?.pct ?? 0,
                total: summary?.total ?? 0,
                isToday: key == localDateKey(now),
                isFuture: startOfDay(date) > startOfDay(now)
            ))
        }
        while cells.count % 7 != 0 { cells.append(nil) }
        return cells
    }
}
