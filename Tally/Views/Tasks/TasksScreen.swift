//
//  TasksScreen.swift
//  Tally
//
//  Habits library: active + archived, swipe-to-log, sort toggle.
//  V2: reads from UserHabit + Habit + HabitDay.

import SwiftUI
import SwiftData

struct TasksScreen: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @Environment(LogSheetCoordinator.self) private var logCoordinator
    @Environment(AuthService.self) private var auth
    @Query private var allUserHabits: [UserHabit]
    @Query private var allHabits: [Habit]
    @Query private var allHabitDays: [HabitDay]
    @Query private var allSchedules: [UserHabitSchedule]

    @State private var sortBy: SortOption = .rate
    @State private var viewFilter: ViewFilter = .active
    @State private var showHabitPicker = false

    enum SortOption: String { case rate, name }
    enum ViewFilter: String { case active, archived }

    var body: some View {
        let c = TallyColors.resolve(colorScheme)
        let now = Date()
        let profileId = auth.userId ?? ""

        let myHabits = allUserHabits.filter { $0.profileId == profileId }
        let active = myHabits.filter { !$0.isArchived }
        let archived = myHabits.filter { $0.isArchived }
        let visible = viewFilter == .active ? active : archived

        // Build habit lookup
        let habitMap = Dictionary(allHabits.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        let schedMap = Dictionary(
            allSchedules.filter { $0.effectiveTo == nil }.map { ($0.userHabitId, $0) },
            uniquingKeysWith: { a, _ in a }
        )

        // Resolve each user_habit with sparkline and rate
        let resolved: [(UserHabit, Habit, [Double], Int)] = visible.compactMap { uh in
            guard let habit = habitMap[uh.habitId] else { return nil }
            let sparkline = habitSparkline(userHabitId: uh.id, now: now, context: modelContext)
            let rate = sparkline.isEmpty ? 0 : Int((sparkline.reduce(0, +) / Double(sparkline.count) * 100).rounded())
            return (uh, habit, sparkline, rate)
        }

        let sorted = resolved.sorted { a, b in
            switch sortBy {
            case .rate: return a.3 > b.3
            case .name: return a.1.name.localizedCompare(b.1.name) == .orderedAscending
            }
        }

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Header
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(verbatim: "LIBRARY · \(active.count) ACTIVE · \(archived.count) ARCHIVED")
                                .font(TallyFont.label())
                                .textCase(.uppercase)
                                .tracking(1.2)
                                .foregroundStyle(c.dim)
                            Text("Habits")
                                .font(TallyFont.heading(32, weight: .medium))
                                .foregroundStyle(c.text)
                        }
                        Spacer()
                        Button { showHabitPicker = true } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "plus")
                                Text("ADD")
                            }
                            .font(TallyFont.mono(11, weight: .semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(c.accent)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                    .padding(.top, 8)

                    // Filter + Sort chips
                    HStack(spacing: 4) {
                        filterChip("ACTIVE · \(active.count)", filter: .active, c: c)
                        filterChip("ARCHIVED · \(archived.count)", filter: .archived, c: c)
                        Spacer()
                        sortButton("BY RATE", option: .rate, c: c)
                        sortButton("BY NAME", option: .name, c: c)
                    }

                    if sorted.isEmpty {
                        VStack(spacing: 6) {
                            Text(viewFilter == .active ? "No habits yet" : "No archived habits")
                                .font(TallyFont.heading(18, weight: .medium))
                                .foregroundStyle(c.text)
                            Text(viewFilter == .active ? "Browse the catalog to add your first habit." : "Archived habits will appear here.")
                                .font(TallyFont.body(13))
                                .foregroundStyle(c.dim)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                    } else {
                        // Habit rows
                        ForEach(sorted, id: \.0.id) { uh, habit, sparkline, rate in
                            let sched = schedMap[uh.id]
                            let todayKey = localDateKey(now)
                            let todayHD = allHabitDays.first { $0.userHabitId == uh.id && $0.date == todayKey }
                            let isArchived = viewFilter == .archived

                            if !isArchived, let hdId = todayHD?.id {
                                SwipeableRow(pillLabel: "LOG →", pillColor: c.pos) {
                                    logCoordinator.open(hdId)
                                } content: {
                                    habitRow(habit: habit, sched: sched, sparkline: sparkline, rate: rate, isArchived: false, c: c)
                                }
                            } else {
                                habitRow(habit: habit, sched: sched, sparkline: sparkline, rate: rate, isArchived: isArchived, c: c)
                                    .opacity(isArchived ? 0.6 : 1)
                            }
                        }

                        Text(viewFilter == .active ? "SWIPE LEFT TO LOG" : "")
                            .font(TallyFont.mono(10))
                            .tracking(1.4)
                            .foregroundStyle(c.dim)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 8)
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
    }

    // MARK: - Chips

    private func filterChip(_ label: String, filter: ViewFilter, c: TallyColors) -> some View {
        Button { viewFilter = filter } label: {
            Text(verbatim: label)
                .font(TallyFont.mono(10, weight: .semibold))
                .tracking(1.0)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(viewFilter == filter ? c.accentSoft : Color.clear)
                .foregroundStyle(viewFilter == filter ? c.accent : c.dim)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }

    private func sortButton(_ label: String, option: SortOption, c: TallyColors) -> some View {
        Button { sortBy = option } label: {
            Text(label)
                .font(TallyFont.mono(10, weight: .semibold))
                .tracking(1.0)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(sortBy == option ? c.accentSoft : Color.clear)
                .foregroundStyle(sortBy == option ? c.accent : c.dim)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Habit row

    private func habitRow(habit: Habit, sched: UserHabitSchedule?, sparkline: [Double], rate: Int, isArchived: Bool, c: TallyColors) -> some View {
        let daysLabel = compactDays(sched?.days ?? [])
        let timesLabel = (sched?.times.first ?? "all-day").uppercased()
        let targetLabel = sched?.target != nil ? " · \(Int(sched!.target!)) \(habit.unit ?? "")" : ""
        let rateColor = isArchived ? c.dim : (rate >= 90 ? c.pos : rate >= 70 ? c.text : c.neg)
        let dotColor = isArchived ? c.dim3 : (rate >= 90 ? c.pos : rate >= 70 ? c.accent : c.neg)

        return HStack(spacing: 10) {
            Circle().fill(dotColor).frame(width: 6, height: 6)

            VStack(alignment: .leading, spacing: 2) {
                Text(habit.name)
                    .font(TallyFont.heading(14, weight: .medium))
                    .foregroundStyle(isArchived ? c.dim : c.text)
                Text(verbatim: "\(daysLabel) · \(timesLabel) · \(habit.habitType.uppercased())\(targetLabel)")
                    .font(TallyFont.mono(10))
                    .foregroundStyle(c.dim)
                    .lineLimit(1)
            }

            Spacer()

            SparklineView(values: sparkline, width: 48, height: 16)

            Text(verbatim: "\(rate)%")
                .font(TallyFont.mono(11, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(rateColor)
                .frame(width: 36, alignment: .trailing)
        }
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) {
            Rectangle().fill(c.rule).frame(height: 1)
        }
    }

    private func compactDays(_ days: [Int]) -> String {
        if days.isEmpty || days.count == 7 { return "DAILY" }
        if days.count == 5 && days.sorted() == [0, 1, 2, 3, 4] { return "WKDAYS" }
        if days.count == 2 && days.contains(5) && days.contains(6) { return "WKENDS" }
        return days.sorted().map { dayLabels[$0] }.joined(separator: "/")
    }
}
