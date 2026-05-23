//
//  HabitPickerView.swift
//  Tally
//
//  Browse the global habit catalog and adopt habits.
//  Replaces TaskTemplatePicker for V2 (shared-habits model).

import SwiftUI
import SwiftData

struct HabitPickerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthService.self) private var auth
    @Environment(SyncEngine.self) private var syncEngine
    @Query(sort: \Category.sortOrder) private var categories: [Category]
    @Query(sort: \Habit.sortOrder) private var allHabits: [Habit]
    @Query private var userHabits: [UserHabit]

    @State private var selectedCategory: String?
    @State private var adoptingId: String?

    var body: some View {
        let c = TallyColors.resolve(colorScheme)
        let adoptedIds = Set(userHabits.filter { $0.profileId == (auth.userId ?? "") }.map(\.habitId))

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Category filter
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            categoryChip("All", isActive: selectedCategory == nil, c: c) {
                                selectedCategory = nil
                            }
                            ForEach(categories) { cat in
                                categoryChip(cat.name, isActive: selectedCategory == cat.id, c: c) {
                                    selectedCategory = cat.id
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }

                    // Popular section
                    let popular = filteredHabits.filter(\.isPopular)
                    if !popular.isEmpty && selectedCategory == nil {
                        sectionHeader("POPULAR", c: c)
                        habitGrid(habits: popular, adoptedIds: adoptedIds, c: c)
                    }

                    // All habits
                    sectionHeader(selectedCategory == nil ? "ALL HABITS" : "HABITS", c: c)
                    habitGrid(habits: filteredHabits, adoptedIds: adoptedIds, c: c)
                }
                .padding(.bottom, 20)
            }
            .background(c.bg)
            .navigationTitle("Browse Habits")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var filteredHabits: [Habit] {
        guard let catId = selectedCategory else { return allHabits }
        return allHabits.filter { $0.categoryId == catId }
    }

    // MARK: - Components

    private func categoryChip(_ label: String, isActive: Bool, c: TallyColors, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(TallyFont.mono(11, weight: .semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isActive ? c.accent : c.bg2)
                .foregroundStyle(isActive ? .white : c.text)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(isActive ? .clear : c.rule, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func sectionHeader(_ title: String, c: TallyColors) -> some View {
        Text(title)
            .font(TallyFont.label())
            .textCase(.uppercase)
            .tracking(1.2)
            .foregroundStyle(c.dim)
            .padding(.horizontal, 20)
    }

    private func habitGrid(habits: [Habit], adoptedIds: Set<String>, c: TallyColors) -> some View {
        LazyVStack(spacing: 0) {
            ForEach(habits) { habit in
                let isAdopted = adoptedIds.contains(habit.id)
                let isAdopting = adoptingId == habit.id

                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(habit.name)
                            .font(TallyFont.heading(14, weight: .medium))
                            .foregroundStyle(c.text)
                        Text(habit.descriptionText)
                            .font(TallyFont.mono(11))
                            .foregroundStyle(c.dim)
                            .lineLimit(1)
                    }
                    Spacer()

                    if let unit = habit.unit {
                        Text(unit.uppercased())
                            .font(TallyFont.mono(10))
                            .foregroundStyle(c.dim)
                    }

                    if isAdopted {
                        Text("ADDED")
                            .font(TallyFont.mono(10, weight: .semibold))
                            .foregroundStyle(c.pos)
                    } else {
                        Button {
                            adoptHabit(habit)
                        } label: {
                            if isAdopting {
                                ProgressView()
                                    .frame(width: 60, height: 32)
                            } else {
                                Text("ADD")
                                    .font(TallyFont.mono(11, weight: .semibold))
                                    .frame(width: 60, height: 32)
                                    .background(c.accent)
                                    .foregroundStyle(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(c.rule).frame(height: 1).padding(.leading, 20)
                }
            }
        }
    }

    // MARK: - Adopt

    private func adoptHabit(_ habit: Habit) {
        guard let profileId = auth.userId else { return }
        adoptingId = habit.id
        Task {
            try? await syncEngine.adoptHabit(
                habit: habit,
                profileId: profileId,
                target: habit.defaultTarget,
                days: habit.defaultDays,
                times: habit.defaultTimes,
                today: localDateKey(Date()),
                context: modelContext
            )
            // Generate today's habit_day for the newly adopted habit
            HabitDayGenerator.generateForDate(Date(), profileId: profileId, context: modelContext)
            adoptingId = nil
        }
    }
}
