//
//  OnboardingScreen.swift
//  Tally
//
//  First-launch experience: welcome → pick habits → start tracking.
//  Shown after sign-in when the user has no adopted habits.

import SwiftUI
import SwiftData

struct OnboardingScreen: View {
    let onComplete: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Environment(AuthService.self) private var auth
    @Environment(SyncEngine.self) private var syncEngine
    @Query(sort: \Category.sortOrder) private var categories: [Category]
    @Query(sort: \Habit.sortOrder) private var allHabits: [Habit]
    @Query private var userHabits: [UserHabit]

    @State private var step: OnboardingStep = .welcome
    @State private var selected: Set<String> = []
    @State private var isAdopting = false

    enum OnboardingStep {
        case welcome
        case pickHabits
    }

    var body: some View {
        let c = TallyColors.resolve(colorScheme)

        VStack(spacing: 0) {
            switch step {
            case .welcome:
                welcomeView(c: c)
            case .pickHabits:
                pickHabitsView(c: c)
            }
        }
        .background(c.bg)
    }

    // MARK: - Welcome

    private func welcomeView(c: TallyColors) -> some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 12) {
                Text("Welcome to Tally")
                    .font(TallyFont.heading(32, weight: .medium))
                    .foregroundStyle(c.text)
                Text("Track habits, build streaks,\nand see your progress over time.")
                    .font(TallyFont.body(15))
                    .foregroundStyle(c.dim)
                    .multilineTextAlignment(.center)
            }

            // Three feature highlights
            VStack(alignment: .leading, spacing: 16) {
                featureRow(icon: "checkmark.circle", title: "Daily habits", subtitle: "Check off, count, or time your habits", c: c)
                featureRow(icon: "flame", title: "Streaks", subtitle: "Build consistency day by day", c: c)
                featureRow(icon: "chart.bar", title: "Progress", subtitle: "14-day sparklines on every habit", c: c)
            }
            .padding(.horizontal, 32)

            Spacer()

            Button {
                withAnimation { step = .pickHabits }
            } label: {
                Text("Pick your habits")
                    .font(TallyFont.heading(16, weight: .medium))
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(c.accent)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
    }

    private func featureRow(icon: String, title: String, subtitle: String, c: TallyColors) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(c.accent)
                .frame(width: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(TallyFont.heading(14, weight: .medium))
                    .foregroundStyle(c.text)
                Text(subtitle)
                    .font(TallyFont.body(12))
                    .foregroundStyle(c.dim)
            }
        }
    }

    // MARK: - Pick Habits

    @ViewBuilder
    private func pickHabitsView(c: TallyColors) -> some View {
        let profileId = auth.userId ?? ""
        let adoptedIds = Set(userHabits.filter { $0.profileId == profileId }.map(\.habitId))
        let popular = allHabits.filter(\.isPopular)

        VStack(spacing: 0) {
            // Header
            VStack(spacing: 8) {
                Text("Pick your habits")
                    .font(TallyFont.heading(24, weight: .medium))
                    .foregroundStyle(c.text)
                Text("Choose at least one to get started. You can add more anytime.")
                    .font(TallyFont.body(13))
                    .foregroundStyle(c.dim)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 24)
            .padding(.horizontal, 24)

            // Scrollable habit list
            ScrollView {
                VStack(spacing: 20) {
                    // Popular section
                    if !popular.isEmpty {
                        habitSection("POPULAR", habits: popular, adoptedIds: adoptedIds, c: c)
                    }

                    // By category
                    ForEach(categories) { category in
                        let catHabits = allHabits.filter { $0.categoryId == category.id && !$0.isPopular }
                        if !catHabits.isEmpty {
                            habitSection(category.name.uppercased(), habits: catHabits, adoptedIds: adoptedIds, c: c)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
            }

            // Bottom bar
            Divider()
            VStack(spacing: 12) {
                let totalSelected = selected.count + adoptedIds.count
                Button {
                    adoptSelected()
                } label: {
                    if isAdopting {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                    } else {
                        Text(selected.isEmpty ? "SELECT HABITS TO START" : "START WITH \(totalSelected) HABIT\(totalSelected == 1 ? "" : "S")")
                            .font(TallyFont.mono(13, weight: .semibold))
                            .tracking(0.8)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(selected.isEmpty ? c.dim3 : c.accent)
                            .foregroundStyle(selected.isEmpty ? c.dim : .white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }
                .buttonStyle(.plain)
                .disabled(selected.isEmpty || isAdopting)

                if adoptedIds.isEmpty {
                    Button {
                        onComplete()
                    } label: {
                        Text("Skip for now")
                            .font(TallyFont.body(13))
                            .foregroundStyle(c.dim)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(c.bg)
        }
    }

    private func habitSection(_ title: String, habits: [Habit], adoptedIds: Set<String>, c: TallyColors) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(TallyFont.label())
                .textCase(.uppercase)
                .tracking(1.2)
                .foregroundStyle(c.dim)

            ForEach(habits) { habit in
                let isAdopted = adoptedIds.contains(habit.id)
                let isSelected = selected.contains(habit.id)
                let active = isAdopted || isSelected

                Button {
                    if !isAdopted {
                        if isSelected {
                            selected.remove(habit.id)
                        } else {
                            selected.insert(habit.id)
                        }
                    }
                } label: {
                    HStack(spacing: 12) {
                        // Checkbox
                        RoundedRectangle(cornerRadius: 6)
                            .fill(active ? c.accent : Color.clear)
                            .frame(width: 22, height: 22)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(active ? c.accent : c.dim2, lineWidth: 1.5)
                            )
                            .overlay {
                                if active {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(.white)
                                }
                            }

                        VStack(alignment: .leading, spacing: 1) {
                            Text(habit.name)
                                .font(TallyFont.heading(14, weight: .medium))
                                .foregroundStyle(c.text)
                            Text(habit.descriptionText)
                                .font(TallyFont.mono(11))
                                .foregroundStyle(c.dim)
                                .lineLimit(1)
                        }

                        Spacer()

                        if isAdopted {
                            Text("ADDED")
                                .font(TallyFont.mono(9, weight: .semibold))
                                .foregroundStyle(c.pos)
                        } else if let unit = habit.unit {
                            Text(unit.uppercased())
                                .font(TallyFont.mono(10))
                                .foregroundStyle(c.dim)
                        }
                    }
                    .padding(12)
                    .background(active ? c.accentSoft : c.bg2)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(active ? c.accent : c.rule, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .disabled(isAdopted)
            }
        }
    }

    // MARK: - Adopt

    private func adoptSelected() {
        guard let profileId = auth.userId else { return }
        isAdopting = true
        Task {
            let today = localDateKey(Date())
            for habitId in selected {
                guard let habit = allHabits.first(where: { $0.id == habitId }) else { continue }
                do {
                    try await syncEngine.adoptHabit(
                        habit: habit,
                        profileId: profileId,
                        target: habit.defaultTarget,
                        days: habit.defaultDays,
                        times: habit.defaultTimes,
                        today: today,
                        context: modelContext
                    )
                } catch {
                    print("[Onboarding] adopt failed for \(habit.name): \(error)")
                }
            }
            isAdopting = false
            onComplete()
        }
    }
}
