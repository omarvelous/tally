//
//  TaskTemplatePicker.swift
//  Tally
//
//  Template browser sheet: popular row, category filter, 2-column grid.
//  Tap = quick-add, long-press = customize in form.

import SwiftUI
import SwiftData

enum TemplatePickerResult {
    case custom
    case quickAdded(TallyTask)
    case customize(TaskTemplate)
}

struct TaskTemplatePicker: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    let onResult: (TemplatePickerResult) -> Void

    @State private var selectedCategory: String = "all"

    private let catalog = loadTemplateCatalog()

    private var popularTemplates: [TaskTemplate] {
        catalog.popular.compactMap { id in
            catalog.templates.first { $0.id == id }
        }
    }

    private var filteredTemplates: [TaskTemplate] {
        if selectedCategory == "all" { return catalog.templates }
        return catalog.templates.filter { $0.category == selectedCategory }
    }

    private var visibleCategories: [TemplateCategory] {
        if selectedCategory == "all" { return catalog.categories }
        return catalog.categories.filter { $0.id == selectedCategory }
    }

    var body: some View {
        let c = TallyColors.resolve(colorScheme)

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Create custom button
                    customButton(c: c)
                        .padding(.horizontal, 20)
                        .padding(.top, 8)

                    // Divider
                    orDivider(c: c)
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        .padding(.bottom, 16)

                    // Popular row
                    popularSection(c: c)
                        .padding(.bottom, 20)

                    // Category chips
                    categoryChips(c: c)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 16)

                    // Template grid by category
                    templateGrid(c: c)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 40)
                }
            }
            .background(c.bg)
            .navigationTitle("New task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(c.dim)
                }
            }
        }
    }

    // MARK: - Custom Button

    private func customButton(c: TallyColors) -> some View {
        Button {
            dismiss()
            onResult(.custom)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .medium))
                Text("CREATE CUSTOM TASK")
                    .font(TallyFont.mono(12, weight: .semibold))
                    .tracking(1.0)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .foregroundStyle(c.accent)
            .background(c.bg2)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(c.accent, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Or Divider

    private func orDivider(c: TallyColors) -> some View {
        HStack(spacing: 12) {
            Rectangle().fill(c.rule).frame(height: 1)
            Text("OR START FROM A TEMPLATE")
                .font(TallyFont.mono(10, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(c.dim2)
            Rectangle().fill(c.rule).frame(height: 1)
        }
    }

    // MARK: - Popular Section

    private func popularSection(c: TallyColors) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("POPULAR")
                .font(TallyFont.label())
                .textCase(.uppercase)
                .tracking(1.2)
                .foregroundStyle(c.dim)
                .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(popularTemplates) { template in
                        popularCard(template: template, c: c)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    private func popularCard(template: TaskTemplate, c: TallyColors) -> some View {
        Button {
            quickAdd(template)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(template.name)
                    .font(TallyFont.heading(14, weight: .medium))
                    .foregroundStyle(c.text)
                Text(badgeText(template))
                    .font(TallyFont.mono(9, weight: .semibold))
                    .tracking(0.6)
                    .foregroundStyle(typeColor(for: template.type, colors: c))
            }
            .padding(12)
            .background(c.bg2)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(c.rule, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                dismiss()
                onResult(.customize(template))
            } label: {
                Label("Customize before adding", systemImage: "slider.horizontal.3")
            }
        }
    }

    // MARK: - Category Chips

    private func categoryChips(c: TallyColors) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                chipButton("All", id: "all", c: c)
                ForEach(catalog.categories) { cat in
                    chipButton(cat.name, id: cat.id, c: c)
                }
            }
        }
    }

    private func chipButton(_ label: String, id: String, c: TallyColors) -> some View {
        let active = selectedCategory == id
        return Button {
            selectedCategory = id
        } label: {
            Text(label.uppercased())
                .font(TallyFont.mono(10, weight: .semibold))
                .tracking(0.8)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(active ? c.accent : Color.clear)
                .foregroundStyle(active ? .white : c.dim)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(active ? c.accent : c.rule, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Template Grid

    private let gridColumns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    private func templateGrid(c: TallyColors) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(visibleCategories) { cat in
                let templates = filteredTemplates.filter { $0.category == cat.id }
                if !templates.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        if selectedCategory == "all" {
                            Text(cat.name.uppercased())
                                .font(TallyFont.label())
                                .tracking(1.2)
                                .foregroundStyle(c.dim)
                        }

                        LazyVGrid(columns: gridColumns, spacing: 10) {
                            ForEach(templates) { template in
                                templateCard(template: template, c: c)
                            }
                        }
                    }
                }
            }
        }
    }

    private func templateCard(template: TaskTemplate, c: TallyColors) -> some View {
        Button {
            quickAdd(template)
        } label: {
            HStack(spacing: 0) {
                // Colored left border
                RoundedRectangle(cornerRadius: 2)
                    .fill(typeColor(for: template.type, colors: c))
                    .frame(width: 4)
                    .padding(.vertical, 8)

                VStack(alignment: .leading, spacing: 6) {
                    Text(template.name)
                        .font(TallyFont.heading(14, weight: .medium))
                        .foregroundStyle(c.text)
                        .lineLimit(1)
                    Text(template.description)
                        .font(TallyFont.body(11))
                        .foregroundStyle(c.dim)
                        .lineLimit(2)
                    Text(badgeText(template).uppercased())
                        .font(TallyFont.mono(9, weight: .semibold))
                        .tracking(0.6)
                        .foregroundStyle(typeColor(for: template.type, colors: c))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(typeColor(for: template.type, colors: c).opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                .padding(.leading, 10)
                .padding(.trailing, 14)
                .padding(.vertical, 14)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(c.bg2)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(c.rule, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                dismiss()
                onResult(.customize(template))
            } label: {
                Label("Customize before adding", systemImage: "slider.horizontal.3")
            }
        }
    }

    // MARK: - Helpers

    private func badgeText(_ template: TaskTemplate) -> String {
        let typeLabel: String = {
            switch template.type {
            case "check":   return "Checkoff"
            case "count":   return "Count"
            case "timer":   return "Timer"
            case "numeric": return "Numeric"
            case "yesno":   return "Yes / No"
            default:        return template.type
            }
        }()
        if let target = template.target, let unit = template.unit {
            return "\(typeLabel) · \(Int(target)) \(unit)"
        } else if let unit = template.unit {
            return "\(typeLabel) · \(unit)"
        }
        return typeLabel
    }

    private func quickAdd(_ template: TaskTemplate) {
        let task = taskFromTemplate(template)
        modelContext.insert(task)
        dismiss()
        onResult(.quickAdded(task))
    }
}
