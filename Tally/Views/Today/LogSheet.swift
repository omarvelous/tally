//
//  LogSheet.swift
//  Tally
//
//  Bottom-sheet modal logging surface. Now works with HabitDay (V2).
//  Pinned footer keeps log controls at a fixed position.

import SwiftUI
import SwiftData
import WidgetKit

struct LogSheet: View {
    let habitDayId: String

    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @Environment(SyncEngine.self) private var syncEngine

    @Query private var allLogEntries: [HabitLogEntry]
    @State private var stagedValue: String = ""
    @State private var usingPlaceholder: Bool = true
    @State private var deleteTarget: HabitLogEntry?

    var body: some View {
        let c = TallyColors.resolve(colorScheme)

        if let resolved = resolveHabitDay(id: habitDayId, context: modelContext) {
            let hdId = habitDayId
            let todayEntries = allLogEntries
                .filter { $0.habitDayId == hdId && !$0.deleted }
                .sorted { $0.loggedAt > $1.loggedAt }

            VStack(spacing: 0) {
                // Static header
                VStack(alignment: .leading, spacing: 16) {
                    // Schedule + status
                    VStack(alignment: .leading, spacing: 4) {
                        Text(verbatim: "\(resolved.firstTime.uppercased()) · \(scheduleLabel(resolved.days))")
                            .font(TallyFont.label())
                            .textCase(.uppercase)
                            .tracking(1.2)
                            .foregroundStyle(c.dim)
                        HStack {
                            Text(resolved.name)
                                .font(TallyFont.heading(24, weight: .medium))
                                .foregroundStyle(c.text)
                            Spacer()
                            statusPill(resolved: resolved, c: c)
                        }
                    }

                    // Hero card
                    heroCard(resolved: resolved, c: c)

                    // 14-day trend
                    miniTrend(resolved: resolved, c: c)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 12)

                // Scrollable entries list
                if !todayEntries.isEmpty {
                    ScrollView {
                        entriesList(resolved: resolved, entries: todayEntries, c: c)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 16)
                    }
                } else {
                    Spacer()
                }

                // Pinned footer — log controls
                Divider()
                logFooter(resolved: resolved, c: c)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(c.bg)
            }
            .background(c.bg)
            .alert(
                "Delete this entry?",
                isPresented: Binding(get: { deleteTarget != nil }, set: { if !$0 { deleteTarget = nil } })
            ) {
                Button("Cancel", role: .cancel) { deleteTarget = nil }
                Button("Delete", role: .destructive) {
                    if let entry = deleteTarget {
                        softDeleteEntry(entry, resolved: resolved)
                        deleteTarget = nil
                    }
                }
            }
        } else {
            Text("Habit not found")
                .foregroundStyle(TallyColors.resolve(colorScheme).dim)
        }
    }

    // MARK: - Status pill

    private func statusPill(resolved: ResolvedHabitDay, c: TallyColors) -> some View {
        let color: Color = resolved.isDone ? c.pos : resolved.status == "partial" ? c.accent : c.dim2
        return Text(verbatim: "\(Int(resolved.pct * 100))%")
            .font(TallyFont.mono(11, weight: .semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }

    // MARK: - Hero card

    private func heroCard(resolved: ResolvedHabitDay, c: TallyColors) -> some View {
        Group {
            switch resolved.type {
            case .count, .timer:
                let target = resolved.targetSnap ?? 1
                TallyCard {
                    VStack(spacing: 4) {
                        Text(resolved.type == .timer ? "MINUTES TODAY" : "LOGGED TODAY")
                            .font(TallyFont.label())
                            .textCase(.uppercase)
                            .tracking(1.2)
                            .foregroundStyle(c.dim)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Spacer()
                            Text(verbatim: "\(Int(resolved.sum.rounded()))")
                                .font(TallyFont.heading(72, weight: .medium))
                                .monospacedDigit()
                                .foregroundStyle(resolved.isDone ? c.pos : c.text)
                            Text(verbatim: "/ \(Int(target))")
                                .font(TallyFont.heading(24, weight: .medium))
                                .foregroundStyle(c.dim)
                            Spacer()
                        }

                        Text(verbatim: "\((resolved.unitSnap ?? "").uppercased()) · \(Int(resolved.pct * 100))% COMPLETE")
                            .font(TallyFont.mono(11))
                            .foregroundStyle(c.dim)

                        ProgressBarView(pct: resolved.pct, height: 8, color: resolved.isDone ? c.pos : c.accent)
                            .padding(.top, 8)
                    }
                }

            case .check:
                TallyCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("STATUS")
                            .font(TallyFont.label())
                            .textCase(.uppercase)
                            .tracking(1.2)
                            .foregroundStyle(c.dim)
                        Text(resolved.isDone ? "Done ✓" : "Pending")
                            .font(TallyFont.heading(40, weight: .medium))
                            .foregroundStyle(resolved.isDone ? c.pos : c.text)
                    }
                }

            case .yesno:
                TallyCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("TODAY'S ANSWER")
                            .font(TallyFont.label())
                            .textCase(.uppercase)
                            .tracking(1.2)
                            .foregroundStyle(c.dim)
                        Text(resolved.isDone ? "Yes" : "—")
                            .font(TallyFont.heading(40, weight: .medium))
                            .foregroundStyle(resolved.isDone ? c.pos : c.text)
                    }
                }

            case .numeric:
                TallyCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("LATEST READING")
                            .font(TallyFont.label())
                            .textCase(.uppercase)
                            .tracking(1.2)
                            .foregroundStyle(c.dim)
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text(resolved.sum > 0 ? String(format: "%.1f", resolved.sum) : "—")
                                .font(TallyFont.heading(56, weight: .medium))
                                .monospacedDigit()
                                .foregroundStyle(resolved.isDone ? c.pos : c.text)
                            Text(resolved.unitSnap ?? "")
                                .font(TallyFont.heading(20, weight: .medium))
                                .foregroundStyle(c.dim)
                        }
                    }
                }
            }
        }
    }

    // MARK: - 14-day mini trend

    private func miniTrend(resolved: ResolvedHabitDay, c: TallyColors) -> some View {
        let now = Date()
        let history = habitSparkline(userHabitId: resolved.userHabitId, now: now, context: modelContext)

        return VStack(alignment: .leading, spacing: 8) {
            Text("LAST 14 DAYS")
                .font(TallyFont.label())
                .textCase(.uppercase)
                .tracking(1.2)
                .foregroundStyle(c.dim)

            HStack(alignment: .bottom, spacing: 3) {
                ForEach(0..<14, id: \.self) { i in
                    let pct = history[i]
                    VStack(spacing: 2) {
                        if i == 13 {
                            Text("TODAY")
                                .font(TallyFont.mono(8, weight: .semibold))
                                .foregroundStyle(c.dim)
                        }
                        RoundedRectangle(cornerRadius: 2)
                            .fill(pct >= 1 ? c.accent : pct > 0 ? c.accentSoft : c.dim3)
                            .frame(height: max(min(CGFloat(pct), 1.0), 0.05) * 50)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 64)
        }
    }

    // MARK: - Pinned footer (log controls)

    @ViewBuilder
    private func logFooter(resolved: ResolvedHabitDay, c: TallyColors) -> some View {
        switch resolved.type {
        case .count, .timer:
            VStack(alignment: .leading, spacing: 8) {
                Text(resolved.type == .count ? "QUICK ADD" : "ADD MINUTES")
                    .font(TallyFont.label())
                    .textCase(.uppercase)
                    .tracking(1.2)
                    .foregroundStyle(c.dim)

                let presets: [Double] = resolved.type == .count
                    ? [5, 10, 25, resolved.targetSnap ?? 50]
                    : [5, 10, 15, resolved.targetSnap ?? 20]
                PresetChipGrid(values: presets, unit: resolved.unitSnap, selectedValue: Double(stagedValue)) { value in
                    let current = Double(stagedValue) ?? 0
                    stagedValue = "\(Int(current + value))"
                    usingPlaceholder = false
                }

                HStack(spacing: 8) {
                    HStack(alignment: .firstTextBaseline) {
                        TextField("0", text: $stagedValue)
                            .keyboardType(.decimalPad)
                            .font(TallyFont.mono(18, weight: .semibold))
                            .foregroundStyle(c.text)
                            .multilineTextAlignment(.trailing)
                            .onChange(of: stagedValue) { usingPlaceholder = false }
                        Text(verbatim: (resolved.unitSnap ?? "").uppercased())
                            .font(TallyFont.mono(11))
                            .foregroundStyle(c.dim)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(c.bg2)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(c.accent, lineWidth: 1))

                    Button {
                        if let v = Double(stagedValue), v > 0 {
                            logValue(v, resolved: resolved)
                            dismiss()
                        }
                    } label: {
                        let hasValue = (Double(stagedValue) ?? 0) > 0
                        Text("LOG")
                            .font(TallyFont.heading(14, weight: .medium))
                            .padding(.horizontal, 20)
                            .frame(height: 46)
                            .background(hasValue ? c.accent : c.dim3)
                            .foregroundStyle(hasValue ? .white : c.dim)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }

        case .check:
            Button {
                if !resolved.isDone {
                    logValue(1.0, resolved: resolved)
                    dismiss()
                }
            } label: {
                HStack {
                    if resolved.isDone {
                        Text("Already done")
                    } else {
                        Image(systemName: "checkmark")
                        Text("Mark complete")
                    }
                }
                .font(TallyFont.heading(14, weight: .medium))
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(resolved.isDone ? c.bg3 : c.accent)
                .foregroundStyle(resolved.isDone ? c.dim : .white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .disabled(resolved.isDone)

        case .yesno:
            VStack(alignment: .leading, spacing: 8) {
                Text("TODAY'S ANSWER")
                    .font(TallyFont.label())
                    .textCase(.uppercase)
                    .tracking(1.2)
                    .foregroundStyle(c.dim)
                HStack(spacing: 8) {
                    yesNoButton(label: "Yes", isActive: resolved.isDone, c: c) {
                        logValue(1.0, resolved: resolved)
                        dismiss()
                    }
                    yesNoButton(label: "No", isActive: false, c: c) {
                        logValue(0.0, resolved: resolved)
                        dismiss()
                    }
                }
            }

        case .numeric:
            VStack(alignment: .leading, spacing: 8) {
                Text("ENTER READING")
                    .font(TallyFont.label())
                    .textCase(.uppercase)
                    .tracking(1.2)
                    .foregroundStyle(c.dim)
                HStack(spacing: 8) {
                    HStack(alignment: .firstTextBaseline) {
                        TextField("0.0", text: $stagedValue)
                            .keyboardType(.decimalPad)
                            .font(TallyFont.mono(28, weight: .semibold))
                            .foregroundStyle(c.text)
                            .onChange(of: stagedValue) { usingPlaceholder = false }
                        Text(verbatim: (resolved.unitSnap ?? "").uppercased())
                            .font(TallyFont.mono(13))
                            .foregroundStyle(c.dim)
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
                    .background(c.bg2)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(c.rule, lineWidth: 1))
                }
                Button {
                    if let v = Double(stagedValue) {
                        logValue(v, resolved: resolved)
                        dismiss()
                    }
                } label: {
                    let hasValue = Double(stagedValue) != nil
                    Text("SAVE")
                        .font(TallyFont.heading(14, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(hasValue ? c.accent : c.dim3)
                        .foregroundStyle(hasValue ? .white : c.dim)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Entries list

    private func entriesList(resolved: ResolvedHabitDay, entries: [HabitLogEntry], c: TallyColors) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            let countLabel = resolved.type == .count ? "SETS" : (entries.count == 1 ? "ENTRY" : "ENTRIES")
            Text(verbatim: "TODAY · \(entries.count) \(countLabel)")
                .font(TallyFont.label())
                .textCase(.uppercase)
                .tracking(1.2)
                .foregroundStyle(c.dim)
                .padding(.bottom, 4)

            ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                SwipeableRow(pillLabel: "DELETE", pillColor: c.neg) {
                    deleteTarget = entry
                } content: {
                    HStack(spacing: 8) {
                        Text(verbatim: String(format: "%02d", entries.count - index))
                            .font(TallyFont.mono(11))
                            .foregroundStyle(c.dim)
                            .frame(width: 24)
                        Text(verbatim: entry.time)
                            .font(TallyFont.mono(11))
                            .foregroundStyle(c.dim)
                        Spacer()
                        Text(verbatim: entryValueText(resolved: resolved, entry: entry))
                            .font(TallyFont.mono(14, weight: .semibold))
                            .foregroundStyle(c.text)
                        Text(verbatim: (resolved.unitSnap ?? "").uppercased())
                            .font(TallyFont.mono(10))
                            .foregroundStyle(c.dim)
                            .frame(width: 36, alignment: .trailing)
                    }
                    .padding(.vertical, 10)
                }
                .overlay(alignment: .bottom) {
                    Rectangle().fill(c.rule).frame(height: 1)
                }
            }

            // Total row for count/timer
            if resolved.type == .count || resolved.type == .timer {
                HStack(spacing: 8) {
                    Text("Σ")
                        .font(TallyFont.mono(11, weight: .semibold))
                        .frame(width: 24)
                    Text("TOTAL")
                        .font(TallyFont.mono(11))
                        .foregroundStyle(c.dim)
                    Spacer()
                    Text(verbatim: "\(Int(resolved.sum.rounded()))")
                        .font(TallyFont.mono(15, weight: .semibold))
                        .foregroundStyle(resolved.isDone ? c.pos : c.accent)
                    Text(verbatim: (resolved.unitSnap ?? "").uppercased())
                        .font(TallyFont.mono(10))
                        .foregroundStyle(c.dim)
                        .frame(width: 36, alignment: .trailing)
                }
                .padding(.vertical, 12)
            }
        }
    }

    private func entryValueText(resolved: ResolvedHabitDay, entry: HabitLogEntry) -> String {
        switch resolved.type {
        case .check, .yesno: return "✓"
        case .numeric: return String(format: "%.1f", entry.value)
        case .count, .timer: return "+\(Int(entry.value))"
        }
    }

    private func softDeleteEntry(_ entry: HabitLogEntry, resolved: ResolvedHabitDay) {
        entry.deleted = true

        // Recompute HabitDay from remaining entries
        let hdId = habitDayId
        let remaining = allLogEntries.filter { $0.habitDayId == hdId && !$0.deleted }
        let newSum = remaining.reduce(0.0) { $0 + $1.value }

        let descriptor = FetchDescriptor<HabitDay>(predicate: #Predicate { $0.id == hdId })
        if let habitDay = (try? modelContext.fetch(descriptor))?.first {
            habitDay.sum = newSum
            let target = habitDay.targetSnap
            if target == nil || target == 0 {
                habitDay.pct = newSum >= 1 ? 1.0 : 0.0
            } else {
                habitDay.pct = newSum / target!
            }
            if habitDay.pct >= 1.0 { habitDay.status = "done" }
            else if habitDay.pct > 0 { habitDay.status = "partial" }
            else { habitDay.status = "pending" }
        }

        try? modelContext.save()
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: - Helpers

    private func logValue(_ value: Double, resolved: ResolvedHabitDay) {
        Task {
            do {
                try await syncEngine.logCompletion(
                    habitDayId: resolved.habitDayId,
                    value: value,
                    timezone: TimeZone.current.identifier,
                    context: modelContext
                )
            } catch {
                print("[LogSheet] push to Supabase failed: \(error)")
            }
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    private func scheduleLabel(_ days: [Int]) -> String {
        if days.isEmpty || days.count == 7 { return "DAILY" }
        if days == [0,1,2,3,4] { return "WEEKDAYS" }
        if days == [0,2,4] { return "MWF" }
        return days.map { dayLabels[$0] }.joined(separator: " ")
    }

    private func yesNoButton(label: String, isActive: Bool, c: TallyColors, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(TallyFont.heading(14, weight: .medium))
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(isActive ? c.accent : c.bg2)
                .foregroundStyle(isActive ? .white : c.text)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isActive ? Color.clear : c.rule, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}
