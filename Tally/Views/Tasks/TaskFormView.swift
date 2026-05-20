//
//  TaskFormView.swift
//  Tally
//
//  Add/Edit task form with type selection, target, schedule, and validation.

import SwiftUI
import SwiftData

struct TaskFormView: View {
    let taskId: String?
    let template: TaskTemplate?

    init(taskId: String?, template: TaskTemplate? = nil) {
        self.taskId = taskId
        self.template = template
    }

    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @Query private var tasks: [TallyTask]

    @State private var name: String = ""
    @State private var type: TaskType = .count
    @State private var target: String = "100"
    @State private var unitSelection: String = "reps"
    @State private var showCustomUnit: Bool = false
    @State private var customUnit: String = ""
    @State private var days: Set<Int> = Set(0...6)
    @State private var times: [String] = ["08:00"]
    @State private var isAllDay: Bool = false
    @State private var showDeleteConfirm = false

    private let catalog = loadTemplateCatalog()

    private var isEdit: Bool { taskId != nil }
    private var existing: TallyTask? { taskId.flatMap { id in tasks.first { $0.id == id } } }

    private var validName: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }
    private var requiresTarget: Bool { type == .count || type == .timer }
    private var validTarget: Bool { !requiresTarget || (Double(target) ?? 0) > 0 }
    private var isValid: Bool { validName && validTarget && !days.isEmpty }

    /// The resolved unit string for saving.
    private var resolvedUnit: String {
        showCustomUnit ? customUnit : unitSelection
    }

    /// Which units to show in the dropdown.
    private var availableUnits: [String] {
        if let allowed = template?.allowedUnits, !allowed.isEmpty {
            return allowed
        }
        return catalog.units
    }

    var body: some View {
        let c = TallyColors.resolve(colorScheme)

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    nameSection(c: c)
                    typeSection(c: c)
                    if requiresTarget || type == .numeric {
                        targetUnitSection(c: c)
                    }
                    daysSection(c: c)
                    timesSection(c: c)
                    if isEdit {
                        deleteSection(c: c)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .background(c.bg)
            .navigationTitle(isEdit ? "Edit task" : "New task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(c.dim)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .font(.body.weight(.semibold))
                        .disabled(!isValid)
                }
            }
        }
        .onAppear { loadInitialState() }
        .confirmationDialog("Delete \"\(existing?.name ?? "")\"?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete task & all history", role: .destructive) { deleteTask() }
        } message: {
            Text("All log entries for this task will be permanently removed.")
        }
    }

    // MARK: - Name

    private func nameSection(c: TallyColors) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("NAME")
                .font(TallyFont.label())
                .textCase(.uppercase)
                .tracking(1.2)
                .foregroundStyle(c.dim)
            TextField("e.g. Push-ups", text: $name)
                .font(TallyFont.heading(22, weight: .medium))
                .foregroundStyle(c.text)
                .padding(.vertical, 10)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(c.rule).frame(height: 1)
                }
        }
    }

    // MARK: - Type

    private static let typeOptions: [(TaskType, String, String)] = [
        (.check,   "Checkoff",        "Just done / not done"),
        (.count,   "Count to goal",   "Log sets, sum to a target"),
        (.numeric, "Numeric value",   "A single reading (e.g. weight)"),
        (.timer,   "Time / duration", "Track minutes spent"),
        (.yesno,   "Yes / No",        "Daily question"),
    ]

    private func typeSection(c: TallyColors) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("TYPE")
                .font(TallyFont.label())
                .textCase(.uppercase)
                .tracking(1.2)
                .foregroundStyle(c.dim)

            ForEach(Self.typeOptions, id: \.0) { option, label, subtitle in
                let selected = type == option
                Button {
                    type = option
                    suggestUnit(for: option)
                } label: {
                    HStack(spacing: 12) {
                        Circle()
                            .strokeBorder(selected ? c.accent : c.dim2, lineWidth: 1.5)
                            .frame(width: 16, height: 16)
                            .overlay {
                                if selected {
                                    Circle().fill(c.accent).frame(width: 10, height: 10)
                                }
                            }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(label)
                                .font(TallyFont.heading(14, weight: .medium))
                                .foregroundStyle(c.text)
                            Text(subtitle.uppercased())
                                .font(TallyFont.mono(10))
                                .foregroundStyle(c.dim)
                        }
                        Spacer()
                    }
                    .padding(14)
                    .background(selected ? c.accentSoft : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(selected ? c.accent : c.rule, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Target + Unit

    private func targetUnitSection(c: TallyColors) -> some View {
        HStack(spacing: 12) {
            if requiresTarget {
                VStack(alignment: .leading, spacing: 4) {
                    Text("TARGET")
                        .font(TallyFont.label())
                        .textCase(.uppercase)
                        .tracking(1.2)
                        .foregroundStyle(c.dim)
                    TextField("100", text: $target)
                        .keyboardType(.numberPad)
                        .font(TallyFont.heading(22, weight: .medium))
                        .foregroundStyle(c.text)
                        .padding(.vertical, 10)
                        .overlay(alignment: .bottom) {
                            Rectangle().fill(c.rule).frame(height: 1)
                        }
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("UNIT")
                    .font(TallyFont.label())
                    .textCase(.uppercase)
                    .tracking(1.2)
                    .foregroundStyle(c.dim)

                if showCustomUnit {
                    // Custom text field with cancel button
                    HStack(spacing: 8) {
                        TextField("e.g. glasses", text: $customUnit)
                            .font(TallyFont.heading(22, weight: .medium))
                            .foregroundStyle(c.text)
                        Button {
                            showCustomUnit = false
                            customUnit = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 18))
                                .foregroundStyle(c.dim2)
                        }
                    }
                    .padding(.vertical, 10)
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(c.accent).frame(height: 2)
                    }
                } else {
                    // Dropdown menu
                    Menu {
                        ForEach(availableUnits, id: \.self) { u in
                            Button(u) { unitSelection = u }
                        }
                        Divider()
                        Button("Other...") {
                            showCustomUnit = true
                            customUnit = ""
                        }
                    } label: {
                        HStack {
                            Text(unitSelection)
                                .font(TallyFont.heading(22, weight: .medium))
                                .foregroundStyle(c.text)
                            Spacer()
                            Image(systemName: "chevron.down")
                                .font(.system(size: 12))
                                .foregroundStyle(c.dim2)
                        }
                        .padding(.vertical, 10)
                        .overlay(alignment: .bottom) {
                            Rectangle().fill(c.rule).frame(height: 1)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Days

    // Day display order: Sun(6), Mon(0), Tue(1), Wed(2), Thu(3), Fri(4), Sat(5)
    private static let dayDisplayOrder = [6, 0, 1, 2, 3, 4, 5]
    private static let dayDisplayLabels = ["Su", "M", "T", "W", "T", "F", "Sa"]

    private func daysSection(c: TallyColors) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("DAYS")
                .font(TallyFont.label())
                .textCase(.uppercase)
                .tracking(1.2)
                .foregroundStyle(c.dim)

            // Day grid — Sunday first
            HStack(spacing: 4) {
                ForEach(Array(Self.dayDisplayOrder.enumerated()), id: \.offset) { displayIdx, dow in
                    let active = days.contains(dow)
                    Button {
                        if active { days.remove(dow) } else { days.insert(dow) }
                    } label: {
                        Text(verbatim: Self.dayDisplayLabels[displayIdx])
                            .font(TallyFont.mono(13, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 40)
                            .background(active ? c.accent : Color.clear)
                            .foregroundStyle(active ? .white : c.dim)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(active ? c.accent : c.rule, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            // Presets
            HStack(spacing: 6) {
                dayPreset("DAILY", days: Set(0...6), c: c)
                dayPreset("WEEKDAYS", days: Set(0...4), c: c)
                dayPreset("M·W·F", days: [0, 2, 4], c: c)
                dayPreset("WEEKENDS", days: [5, 6], c: c)
            }
        }
    }

    private func dayPreset(_ label: String, days preset: Set<Int>, c: TallyColors) -> some View {
        Button {
            days = preset
        } label: {
            Text(label)
                .font(TallyFont.mono(10, weight: .medium))
                .tracking(0.8)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(c.rule, lineWidth: 1)
                )
                .foregroundStyle(c.dim)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Times

    private func timesSection(c: TallyColors) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("TIMES")
                    .font(TallyFont.label())
                    .textCase(.uppercase)
                    .tracking(1.2)
                    .foregroundStyle(c.dim)
                Spacer()
                Button {
                    isAllDay.toggle()
                    if isAllDay {
                        times = ["all-day"]
                    } else {
                        times = ["08:00"]
                    }
                } label: {
                    Text(isAllDay ? "USE SPECIFIC TIMES" : "ALL-DAY GOAL")
                        .font(TallyFont.mono(10, weight: .medium))
                        .tracking(0.8)
                        .foregroundStyle(c.dim)
                }
            }

            if isAllDay {
                Text("ALL DAY — LOG ANY TIME")
                    .font(TallyFont.mono(13, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(c.accentSoft)
                    .foregroundStyle(c.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                FlowLayout(spacing: 6) {
                    ForEach(Array(times.enumerated()), id: \.offset) { i, time in
                        HStack(spacing: 4) {
                            // Simple text field for time input
                            TextField("08:00", text: Binding(
                                get: { times[i] },
                                set: { times[i] = $0 }
                            ))
                            .font(TallyFont.mono(13, weight: .medium))
                            .foregroundStyle(c.text)
                            .frame(width: 50)
                            .keyboardType(.numbersAndPunctuation)

                            if times.count > 1 {
                                Button {
                                    times.remove(at: i)
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 10))
                                        .foregroundStyle(c.dim)
                                }
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(c.bg2)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(c.rule, lineWidth: 1))
                    }

                    Button {
                        times.append("12:00")
                    } label: {
                        Text("+ TIME")
                            .font(TallyFont.mono(11))
                            .foregroundStyle(c.dim)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(c.dim3, style: StrokeStyle(lineWidth: 1, dash: [4]))
                            )
                    }
                }
            }
        }
    }

    // MARK: - Delete

    private func deleteSection(c: TallyColors) -> some View {
        Button {
            showDeleteConfirm = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "trash")
                Text("Delete task")
            }
            .font(TallyFont.heading(14, weight: .medium))
            .foregroundStyle(c.neg)
        }
        .padding(.top, 12)
    }

    // MARK: - Actions

    private func loadInitialState() {
        if let task = existing {
            // Edit mode: load from existing task
            name = task.name
            type = task.type
            target = task.target != nil ? String(Int(task.target!)) : "100"
            let existingUnit = task.unit ?? ""
            if !existingUnit.isEmpty && availableUnits.contains(existingUnit) {
                unitSelection = existingUnit
                showCustomUnit = false
            } else if !existingUnit.isEmpty {
                showCustomUnit = true
                customUnit = existingUnit
            }
            days = task.days.isEmpty ? Set(0...6) : Set(task.days)
            if task.times.first == "all-day" {
                isAllDay = true
                times = ["all-day"]
            } else {
                isAllDay = false
                times = task.times
            }
        } else if let t = template {
            // Template mode: pre-fill from template
            name = t.name
            type = TaskType(rawValue: t.type) ?? .check
            target = t.target != nil ? String(Int(t.target!)) : ""
            if let u = t.unit {
                unitSelection = u
            }
            showCustomUnit = false
            let d = templateDays(t.days)
            days = d.isEmpty ? Set(0...6) : Set(d)
            if t.times.first == "all-day" {
                isAllDay = true
                times = ["all-day"]
            } else {
                isAllDay = false
                times = t.times
            }
        }
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let finalDays = Array(days).sorted()
        let finalTimes = isAllDay ? ["all-day"] : times
        let finalTarget: Double? = requiresTarget ? Double(target) : nil
        let unitStr = resolvedUnit.trimmingCharacters(in: .whitespaces)
        let finalUnit: String? = (type == .check || type == .yesno) ? nil : (unitStr.isEmpty ? nil : unitStr)

        if let task = existing {
            task.name = trimmedName
            task.type = type
            task.target = finalTarget
            task.unit = finalUnit
            task.days = finalDays
            task.times = finalTimes
            task.updatedAt = Date().timeIntervalSince1970 * 1000
        } else {
            let task = TallyTask(
                name: trimmedName,
                type: type,
                target: finalTarget,
                unit: finalUnit,
                days: finalDays,
                times: finalTimes
            )
            modelContext.insert(task)
        }
        dismiss()
    }

    private func deleteTask() {
        guard let task = existing else { return }
        deleteTaskAndEntries(taskId: task.id, context: modelContext)
        dismiss()
    }

    private func suggestUnit(for newType: TaskType) {
        if isEdit { return }
        if let suggested = catalog.defaultUnits[newType.rawValue] {
            unitSelection = suggested
            showCustomUnit = false
        }
    }
}

// MARK: - Simple flow layout for time chips

struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = computeLayout(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = computeLayout(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private struct LayoutResult {
        var size: CGSize
        var positions: [CGPoint]
    }

    private func computeLayout(proposal: ProposedViewSize, subviews: Subviews) -> LayoutResult {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxX = max(maxX, x)
        }

        return LayoutResult(size: CGSize(width: maxX, height: y + rowHeight), positions: positions)
    }
}
