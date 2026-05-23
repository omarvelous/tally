//
//  TodayScreen.swift
//  Tally
//
//  The daily dashboard. Reads from materialized HabitDay rows.

import SwiftUI
import SwiftData
import Combine

struct TodayScreen: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Environment(MidnightObserver.self) private var midnightObserver
    @Environment(LogSheetCoordinator.self) private var logCoordinator
    @Environment(AuthService.self) private var auth
    @Query private var allHabitDays: [HabitDay]
    @Query private var allDaySummaries: [DaySummary]

    @State private var tick = Date()
    @State private var showHabitPicker = false
    private let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var body: some View {
        let c = TallyColors.resolve(colorScheme)
        let now = tick
        let todayKey = localDateKey(now)
        let profileId = auth.userId ?? ""

        let resolved = resolveHabitDays(for: todayKey, profileId: profileId, context: modelContext)
        let pending = resolved.filter { !$0.isDone }.sorted { $0.sortMinutes < $1.sortMinutes }
        let done = resolved.filter { $0.isDone }.sorted { $0.sortMinutes < $1.sortMinutes }

        // Day summary
        let total = resolved.count
        let doneCount = done.count
        let partialCount = resolved.filter { $0.status == "partial" }.count
        let overdueCount = resolved.filter { $0.status == "pending" }.count
        let dayPct = total > 0 ? Double(doneCount) / Double(total) : 0

        // Streak from DaySummary
        let streak = computeStreak(profileId: profileId, now: now)

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    header(now: now, streak: streak, c: c)

                    if resolved.isEmpty {
                        emptyState(c: c)
                    } else {
                        // Day completion card
                        dayCompletionCard(
                            total: total, doneCount: doneCount, partialCount: partialCount,
                            overdueCount: overdueCount, dayPct: dayPct,
                            resolved: resolved, c: c
                        )

                        // Pending habits
                        if !pending.isEmpty {
                            habitSection(label: "\(pending.count) REMAINING", habits: pending, now: now, c: c)
                        }

                        // Completed habits
                        if !done.isEmpty {
                            habitSection(label: "\(done.count) DONE", habits: done, now: now, c: c, dimmed: true)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .background(c.bg)
        }
        .sheet(isPresented: $showHabitPicker) {
            HabitPickerView()
        }
        .onReceive(timer) { tick = $0 }
        .onChange(of: midnightObserver.currentDateKey) { _, _ in tick = Date() }
    }

    // MARK: - Header

    private func header(now: Date, streak: Int, c: TallyColors) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(dateKicker(now))
                    .font(TallyFont.label())
                    .textCase(.uppercase)
                    .tracking(1.2)
                    .foregroundStyle(c.dim)
                Text("Today")
                    .font(TallyFont.heading(32, weight: .medium))
                    .foregroundStyle(c.text)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text("STREAK")
                    .font(TallyFont.label())
                    .textCase(.uppercase)
                    .tracking(1.2)
                    .foregroundStyle(c.dim)
                Text("\(streak)d")
                    .font(TallyFont.mono(22, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(c.accent)
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Day completion card

    private func dayCompletionCard(
        total: Int, doneCount: Int, partialCount: Int, overdueCount: Int,
        dayPct: Double, resolved: [ResolvedHabitDay], c: TallyColors
    ) -> some View {
        TallyCard {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("DAY COMPLETION")
                        .font(TallyFont.label())
                        .textCase(.uppercase)
                        .tracking(1.2)
                        .foregroundStyle(c.dim)
                    Spacer()
                    Text("\(doneCount)/\(total) HABITS")
                        .font(TallyFont.mono(11))
                        .foregroundStyle(c.dim)
                }

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(Int(dayPct * 100))")
                        .font(TallyFont.heading(56, weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle(c.text)
                    Text("%")
                        .font(TallyFont.heading(20, weight: .medium))
                        .foregroundStyle(c.dim)
                    Spacer()
                    Text(dayPct >= 1.0 ? "DAY EARNED" : "NEED 100% TO EARN")
                        .font(TallyFont.mono(10))
                        .foregroundStyle(dayPct >= 1.0 ? c.pos : c.dim)
                }

                // Segmented bar
                SegmentedDayBar(
                    statuses: resolved.map { $0.statusKind }
                )
                .padding(.top, 6)

                // Summary
                HStack {
                    Text("\(doneCount) done")
                        .font(TallyFont.mono(10))
                        .foregroundStyle(c.dim)
                    Spacer()
                    if partialCount > 0 {
                        Text("\(partialCount) in progress")
                            .font(TallyFont.mono(10))
                            .foregroundStyle(c.accent)
                    }
                    if overdueCount > 0 {
                        Text("\(overdueCount) remaining")
                            .font(TallyFont.mono(10))
                            .foregroundStyle(c.neg)
                    }
                }
                .padding(.top, 2)
            }
        }
    }

    // MARK: - Habit section

    private func habitSection(label: String, habits: [ResolvedHabitDay], now: Date, c: TallyColors, dimmed: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(TallyFont.label())
                .textCase(.uppercase)
                .tracking(1.2)
                .foregroundStyle(c.dim)

            ForEach(habits) { habit in
                let history = habitSparkline(userHabitId: habit.userHabitId, now: now, context: modelContext)
                let overTarget = habit.pct > 1.0
                let isBinary = habit.type == .check || habit.type == .yesno
                let shouldDim = dimmed && isBinary
                Button {
                    logCoordinator.open(habit.habitDayId)
                } label: {
                    HStack(spacing: 10) {
                        if overTarget {
                            Image(systemName: "star.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(c.warn)
                        } else {
                            StatusPip(status: habit.statusKind)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(habit.name)
                                .font(TallyFont.heading(14, weight: .medium))
                                .foregroundStyle(c.text)
                            HStack(spacing: 0) {
                                Text(habit.label)
                                    .font(TallyFont.mono(11))
                                    .foregroundStyle(c.dim)
                                if let time = habit.timeLabel {
                                    Text(" · ")
                                        .font(TallyFont.mono(11))
                                        .foregroundStyle(c.dim)
                                    Text(time)
                                        .font(TallyFont.mono(11, weight: .medium))
                                        .foregroundStyle(c.accent)
                                }
                            }
                        }

                        Spacer()

                        SparklineView(values: history)

                        Text("\(Int(habit.pct * 100))%")
                            .font(TallyFont.mono(12, weight: .medium))
                            .monospacedDigit()
                            .foregroundStyle(overTarget ? c.warn : c.dim)
                            .frame(width: 44, alignment: .trailing)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 4)
                    .contentShape(Rectangle())
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(c.rule).frame(height: 1)
                    }
                }
                .buttonStyle(.plain)
                .opacity(shouldDim ? 0.5 : 1)
            }
        }
    }

    // MARK: - Empty state

    private func emptyState(c: TallyColors) -> some View {
        VStack(spacing: 16) {
            Text("No habits scheduled today")
                .font(TallyFont.heading(18, weight: .medium))
                .foregroundStyle(c.text)
            Text("Browse the catalog and pick habits to track.")
                .font(TallyFont.body(13))
                .foregroundStyle(c.dim)
                .multilineTextAlignment(.center)
            Button {
                showHabitPicker = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                    Text("Browse habits")
                }
                .font(TallyFont.heading(14, weight: .medium))
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(c.accent)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    // MARK: - Helpers

    private func dateKicker(_ now: Date) -> String {
        let dow = dayOfWeek(now)
        let cal = Calendar.current
        let month = cal.component(.month, from: now) - 1
        let day = cal.component(.day, from: now)
        let h = cal.component(.hour, from: now)
        let m = cal.component(.minute, from: now)
        return "\(dayNames[dow]) · \(monthNamesShort[month]) \(day) · \(String(format: "%02d:%02d", h, m))"
    }

    private func computeStreak(profileId: String, now: Date) -> Int {
        let pid = profileId
        let summaries = (try? modelContext.fetch(
            FetchDescriptor<DaySummary>(predicate: #Predicate { $0.profileId == pid })
        )) ?? []
        let byDate = Dictionary(summaries.map { ($0.date, $0) }, uniquingKeysWith: { a, _ in a })

        var streak = 0
        let todayKey = localDateKey(now)
        if let today = byDate[todayKey], today.streakDay { streak = 1 }

        for i in 1...60 {
            let key = localDateKey(addDays(now, -i))
            guard let summary = byDate[key] else { break }
            if summary.total == 0 { continue } // rest day — neutral
            if summary.streakDay { streak += 1 } else { break }
        }
        return streak
    }
}
