//
//  StreakScreen.swift
//  Tally
//
//  Streak screen: hero card with current streak, 30-day strip, stats, month calendar.

import SwiftUI
import SwiftData

struct StreakScreen: View {
    @Environment(\.colorScheme) private var colorScheme
    @Query(filter: #Predicate<TallyTask> { !$0.archived }) private var tasks: [TallyTask]
    @Query private var allEntries: [LogEntry]

    @State private var monthOffset = 0

    var body: some View {
        let c = TallyColors.resolve(colorScheme)
        let now = Date()
        let streak = streakFor(tasks: tasks, entries: allEntries, now: now)
        let avgPct = streak.history.isEmpty ? 0 : Int((streak.history.reduce(0.0) { $0 + $1.pct } / Double(streak.history.count) * 100).rounded())
        let earned60 = streak.history.filter { $0.total > 0 && $0.pct >= 1 }.count

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
                    heroCard(streak: streak, c: c)

                    // Stat tiles
                    HStack(spacing: 8) {
                        StatTile(label: "BEST", value: "\(streak.best)d")
                        StatTile(label: "EARNED 60D", value: "\(earned60)")
                        StatTile(label: "AVG", value: "\(avgPct)%")
                    }

                    // Month calendar
                    monthCalendar(now: now, c: c)

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

    // MARK: - Hero card

    private func heroCard(streak: StreakResult, c: TallyColors) -> some View {
        TallyCard {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text("CURRENT")
                        .font(TallyFont.label())
                        .textCase(.uppercase)
                        .tracking(1.2)
                        .foregroundStyle(c.dim)
                    Spacer()
                    Text(streak.current > 0 ? "SINCE \(streakStartLabel(streak))" : "WAITING TO START")
                        .font(TallyFont.mono(11))
                        .foregroundStyle(c.dim)
                }

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\(streak.current)")
                        .font(TallyFont.heading(80, weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle(streak.current > 0 ? c.accent : c.dim)
                    Text("day\(streak.current == 1 ? "" : "s")")
                        .font(TallyFont.heading(22, weight: .medium))
                        .foregroundStyle(c.dim)
                    Spacer()
                    Text(streak.current >= streak.best && streak.current > 0 ? "↑ ALL-TIME BEST" : "BEST · \(streak.best)d")
                        .font(TallyFont.mono(10))
                        .foregroundStyle(streak.current >= streak.best && streak.current > 0 ? c.pos : c.dim)
                }

                // 30-day strip
                HStack(spacing: 2) {
                    ForEach(Array(streak.history.suffix(30).enumerated()), id: \.offset) { _, day in
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
                    Text("30 DAYS AGO")
                        .font(TallyFont.mono(10))
                        .foregroundStyle(c.dim)
                    Spacer()
                    Text("TODAY")
                        .font(TallyFont.mono(10))
                        .foregroundStyle(c.dim)
                }
            }
        }
    }

    // MARK: - Month calendar

    private func monthCalendar(now: Date, c: TallyColors) -> some View {
        let cal = Calendar.current
        let viewMonth = cal.date(byAdding: .month, value: monthOffset, to: now)!
        let year = cal.component(.year, from: viewMonth)
        let month = cal.component(.month, from: viewMonth)
        let monthNames = ["January", "February", "March", "April", "May", "June",
                          "July", "August", "September", "October", "November", "December"]
        let label = "\(monthNames[month - 1]) \(year)"

        return VStack(spacing: 10) {
            HStack {
                Button {
                    monthOffset -= 1
                } label: {
                    Text("‹ PREV")
                        .font(TallyFont.mono(11, weight: .semibold))
                        .tracking(1.0)
                        .foregroundStyle(c.dim)
                }
                Spacer()
                Text(label)
                    .font(TallyFont.heading(15, weight: .medium))
                    .foregroundStyle(c.text)
                Spacer()
                Button {
                    monthOffset = min(0, monthOffset + 1)
                } label: {
                    Text("NEXT ›")
                        .font(TallyFont.mono(11, weight: .semibold))
                        .tracking(1.0)
                        .foregroundStyle(monthOffset == 0 ? c.dim2 : c.dim)
                }
                .disabled(monthOffset == 0)
            }

            MonthCalendarView(
                year: year,
                month: month,
                tasks: tasks,
                entries: allEntries,
                now: now
            )
        }
    }

    // MARK: - Helpers

    private func streakStartLabel(_ streak: StreakResult) -> String {
        guard streak.current > 0 else { return "—" }
        let firstDayIdx = streak.history.count - streak.current
        guard firstDayIdx >= 0 && firstDayIdx < streak.history.count else { return "—" }
        let dateStr = streak.history[firstDayIdx].date
        let parts = dateStr.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return "—" }
        return "\(monthNamesShort[parts[1] - 1].uppercased()) \(parts[2])"
    }
}
