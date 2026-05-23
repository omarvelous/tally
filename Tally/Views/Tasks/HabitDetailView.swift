//
//  HabitDetailView.swift
//  Tally
//
//  Detail screen for an adopted habit. Shows stats, 14-day trend,
//  schedule info, and archive/unarchive action.

import SwiftUI
import SwiftData

struct HabitDetailView: View {
    let userHabitId: String

    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Environment(AuthService.self) private var auth
    @Query private var allHabitDays: [HabitDay]

    var body: some View {
        let c = TallyColors.resolve(colorScheme)
        let now = Date()

        if let resolved = resolveUserHabit(id: userHabitId, context: modelContext) {
            let sparkline = habitSparkline(userHabitId: userHabitId, now: now, context: modelContext)
            let rate = sparkline.isEmpty ? 0 : Int((sparkline.reduce(0, +) / Double(sparkline.count) * 100).rounded())
            let uhId = userHabitId
            let habitDays = allHabitDays.filter { $0.userHabitId == uhId }
            let totalDays = habitDays.count
            let doneDays = habitDays.filter { $0.status == "done" }.count
            let allTimeRate = totalDays > 0 ? Int((Double(doneDays) / Double(totalDays) * 100).rounded()) : 0

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 4) {
                        Text(resolved.categoryName.uppercased())
                            .font(TallyFont.label())
                            .textCase(.uppercase)
                            .tracking(1.2)
                            .foregroundStyle(c.dim)
                        Text(resolved.habitName)
                            .font(TallyFont.heading(28, weight: .medium))
                            .foregroundStyle(c.text)
                        if !resolved.description.isEmpty {
                            Text(resolved.description)
                                .font(TallyFont.body(14))
                                .foregroundStyle(c.dim)
                        }
                    }
                    .padding(.top, 8)

                    // Stats tiles
                    HStack(spacing: 8) {
                        StatTile(label: "14D RATE", value: "\(rate)%")
                        StatTile(label: "ALL-TIME", value: "\(allTimeRate)%")
                        StatTile(label: "TRACKED", value: "\(totalDays)d")
                        StatTile(label: "DONE", value: "\(doneDays)")
                    }

                    // 14-day trend
                    trendCard(sparkline: sparkline, now: now, c: c)

                    // Day-by-day history
                    dayHistory(habitDays: habitDays, resolved: resolved, c: c)

                    // Schedule info
                    scheduleCard(resolved: resolved, c: c)

                    // Type info
                    infoCard(resolved: resolved, c: c)

                    // Actions
                    actionsSection(resolved: resolved, c: c)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .background(c.bg)
            .navigationTitle(resolved.habitName)
            .navigationBarTitleDisplayMode(.inline)
        } else {
            Text("Habit not found")
                .foregroundStyle(TallyColors.resolve(colorScheme).dim)
        }
    }

    // MARK: - Day History

    private func dayHistory(habitDays: [HabitDay], resolved: ResolvedUserHabit, c: TallyColors) -> some View {
        let sorted = habitDays.sorted { $0.date > $1.date }
        let recent = Array(sorted.prefix(30))

        return VStack(alignment: .leading, spacing: 0) {
            Text("HISTORY · LAST \(recent.count) DAYS")
                .font(TallyFont.label())
                .textCase(.uppercase)
                .tracking(1.2)
                .foregroundStyle(c.dim)
                .padding(.bottom, 4)

            ForEach(recent, id: \.id) { hd in
                NavigationLink(value: HabitDayNavID(id: hd.id)) {
                    HStack(spacing: 10) {
                        StatusPip(status: statusKindFor(hd.status))

                        Text(formatDateLabel(hd.date))
                            .font(TallyFont.heading(13, weight: .medium))
                            .foregroundStyle(c.text)

                        Spacer()

                        // Value summary
                        if resolved.type == .count || resolved.type == .timer {
                            Text(verbatim: "\(Int(hd.sum.rounded())) / \(Int(hd.targetSnap ?? 0)) \(hd.unitSnap ?? "")")
                                .font(TallyFont.mono(11))
                                .foregroundStyle(c.dim)
                        }

                        Text(verbatim: "\(Int(hd.pct * 100))%")
                            .font(TallyFont.mono(11, weight: .semibold))
                            .monospacedDigit()
                            .foregroundStyle(hd.status == "done" ? c.pos : hd.status == "partial" ? c.accent : c.dim)
                            .frame(width: 36, alignment: .trailing)

                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(c.dim2)
                    }
                    .padding(.vertical, 10)
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(c.rule).frame(height: 1)
                    }
                }
                .buttonStyle(.plain)
            }

            if sorted.count > 30 {
                Text("\(sorted.count - 30) MORE DAYS")
                    .font(TallyFont.mono(10))
                    .foregroundStyle(c.dim)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
            }
        }
    }

    private func statusKindFor(_ status: String) -> TaskStatusKind {
        switch status {
        case "done": return .done
        case "partial": return .partial
        case "skipped": return .off
        default: return .due
        }
    }

    private func formatDateLabel(_ dateKey: String) -> String {
        let parts = dateKey.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return dateKey }
        let dow = dayOfWeek(Calendar.current.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2])) ?? Date())
        return "\(dayNames[dow]) · \(monthNamesShort[parts[1] - 1]) \(parts[2])"
    }

    // MARK: - Trend Card

    private func trendCard(sparkline: [Double], now: Date, c: TallyColors) -> some View {
        TallyCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("LAST 14 DAYS")
                    .font(TallyFont.label())
                    .textCase(.uppercase)
                    .tracking(1.2)
                    .foregroundStyle(c.dim)

                HStack(alignment: .bottom, spacing: 3) {
                    ForEach(0..<14, id: \.self) { i in
                        let pct = sparkline[i]
                        VStack(spacing: 2) {
                            if i == 13 {
                                Text("TODAY")
                                    .font(TallyFont.mono(8, weight: .semibold))
                                    .foregroundStyle(c.dim)
                            }
                            RoundedRectangle(cornerRadius: 2)
                                .fill(pct >= 1 ? c.accent : pct > 0 ? c.accentSoft : c.dim3)
                                .frame(height: max(min(CGFloat(pct), 1.0), 0.05) * 60)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 74)
            }
        }
    }

    // MARK: - Schedule Card

    private func scheduleCard(resolved: ResolvedUserHabit, c: TallyColors) -> some View {
        TallyCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("SCHEDULE")
                    .font(TallyFont.label())
                    .textCase(.uppercase)
                    .tracking(1.2)
                    .foregroundStyle(c.dim)

                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Days")
                            .font(TallyFont.mono(11))
                            .foregroundStyle(c.dim)
                        Text(compactDays(resolved.days))
                            .font(TallyFont.heading(14, weight: .medium))
                            .foregroundStyle(c.text)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Time")
                            .font(TallyFont.mono(11))
                            .foregroundStyle(c.dim)
                        Text(resolved.times.first?.uppercased() ?? "ALL-DAY")
                            .font(TallyFont.heading(14, weight: .medium))
                            .foregroundStyle(c.text)
                    }
                    if let target = resolved.target {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Target")
                                .font(TallyFont.mono(11))
                                .foregroundStyle(c.dim)
                            Text("\(Int(target)) \(resolved.unit ?? "")")
                                .font(TallyFont.heading(14, weight: .medium))
                                .foregroundStyle(c.text)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Info Card

    private func infoCard(resolved: ResolvedUserHabit, c: TallyColors) -> some View {
        TallyCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("DETAILS")
                    .font(TallyFont.label())
                    .textCase(.uppercase)
                    .tracking(1.2)
                    .foregroundStyle(c.dim)

                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Type")
                            .font(TallyFont.mono(11))
                            .foregroundStyle(c.dim)
                        Text(resolved.type.rawValue.capitalized)
                            .font(TallyFont.heading(14, weight: .medium))
                            .foregroundStyle(c.text)
                    }
                    if let unit = resolved.unit {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Unit")
                                .font(TallyFont.mono(11))
                                .foregroundStyle(c.dim)
                            Text(unit)
                                .font(TallyFont.heading(14, weight: .medium))
                                .foregroundStyle(c.text)
                        }
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Since")
                            .font(TallyFont.mono(11))
                            .foregroundStyle(c.dim)
                        Text(resolved.effectiveFrom)
                            .font(TallyFont.heading(14, weight: .medium))
                            .foregroundStyle(c.text)
                    }
                }
            }
        }
    }

    // MARK: - Actions

    private func actionsSection(resolved: ResolvedUserHabit, c: TallyColors) -> some View {
        VStack(spacing: 0) {
            Text("ACTIONS")
                .font(TallyFont.label())
                .textCase(.uppercase)
                .tracking(1.2)
                .foregroundStyle(c.dim)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 4)

            Button {
                toggleArchive(resolved: resolved)
            } label: {
                HStack {
                    Text(resolved.isArchived ? "Restore habit" : "Archive habit")
                        .font(TallyFont.heading(14, weight: .medium))
                        .foregroundStyle(resolved.isArchived ? c.accent : c.neg)
                    Spacer()
                    Image(systemName: resolved.isArchived ? "arrow.uturn.backward" : "archivebox")
                        .foregroundStyle(c.dim)
                }
                .padding(.vertical, 13)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(c.rule).frame(height: 1)
                }
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Helpers

    private func compactDays(_ days: [Int]) -> String {
        if days.isEmpty || days.count == 7 { return "Daily" }
        if days.count == 5 && days.sorted() == [0, 1, 2, 3, 4] { return "Weekdays" }
        return days.sorted().map { dayNames[$0] }.joined(separator: ", ")
    }

    private func toggleArchive(resolved: ResolvedUserHabit) {
        let uhId = resolved.userHabitId
        let descriptor = FetchDescriptor<UserHabit>(predicate: #Predicate { $0.id == uhId })
        guard let uh = (try? modelContext.fetch(descriptor))?.first else { return }
        if uh.isArchived {
            uh.archivedAt = nil
        } else {
            uh.archivedAt = Date().timeIntervalSince1970 * 1000
        }
        try? modelContext.save()
    }
}

// MARK: - Navigation wrapper (avoids String collision with TasksScreen)

struct HabitDayNavID: Hashable {
    let id: String
}

// MARK: - Resolved UserHabit (for detail view)

struct ResolvedUserHabit {
    let userHabitId: String
    let habitName: String
    let description: String
    let categoryName: String
    let type: TaskType
    let unit: String?
    let target: Double?
    let days: [Int]
    let times: [String]
    let effectiveFrom: String
    let isArchived: Bool
}

@MainActor
func resolveUserHabit(id: String, context: ModelContext) -> ResolvedUserHabit? {
    let uhId = id
    guard let uh = (try? context.fetch(
        FetchDescriptor<UserHabit>(predicate: #Predicate { $0.id == uhId })
    ))?.first else { return nil }

    let habitId = uh.habitId
    guard let habit = (try? context.fetch(
        FetchDescriptor<Habit>(predicate: #Predicate { $0.id == habitId })
    ))?.first else { return nil }

    let catId = habit.categoryId
    let category = (try? context.fetch(
        FetchDescriptor<Category>(predicate: #Predicate { $0.id == catId })
    ))?.first

    let sched = (try? context.fetch(
        FetchDescriptor<UserHabitSchedule>(predicate: #Predicate { $0.userHabitId == uhId && $0.effectiveTo == nil })
    ))?.first

    return ResolvedUserHabit(
        userHabitId: uh.id,
        habitName: habit.name,
        description: habit.descriptionText,
        categoryName: category?.name ?? "",
        type: habit.type,
        unit: habit.unit,
        target: sched?.target,
        days: sched?.days ?? [],
        times: sched?.times ?? ["all-day"],
        effectiveFrom: sched?.effectiveFrom ?? "",
        isArchived: uh.isArchived
    )
}
