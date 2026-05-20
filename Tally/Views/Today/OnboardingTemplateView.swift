//
//  OnboardingTemplateView.swift
//  Tally
//
//  Batch onboarding shown on TodayScreen when user has zero tasks.
//  Displays popular templates as a checklist, allows multi-select + batch add.

import SwiftUI
import SwiftData

struct OnboardingTemplateView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme

    let onBrowseAll: () -> Void
    let onCreateCustom: () -> Void

    @State private var selected: Set<String> = []

    private let catalog = loadTemplateCatalog()

    private var popularTemplates: [TaskTemplate] {
        catalog.popular.compactMap { id in
            catalog.templates.first { $0.id == id }
        }
    }

    var body: some View {
        let c = TallyColors.resolve(colorScheme)

        VStack(spacing: 24) {
            // Header
            VStack(spacing: 8) {
                Text("Start tracking")
                    .font(TallyFont.heading(24, weight: .medium))
                    .foregroundStyle(c.text)
                Text("Pick a few habits to get going")
                    .font(TallyFont.body(14))
                    .foregroundStyle(c.dim)
            }

            // Template checklist
            VStack(spacing: 8) {
                ForEach(popularTemplates) { template in
                    let isSelected = selected.contains(template.id)
                    Button {
                        if isSelected {
                            selected.remove(template.id)
                        } else {
                            selected.insert(template.id)
                        }
                    } label: {
                        HStack(spacing: 12) {
                            // Checkbox
                            RoundedRectangle(cornerRadius: 6)
                                .fill(isSelected ? c.accent : Color.clear)
                                .frame(width: 22, height: 22)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(isSelected ? c.accent : c.dim2, lineWidth: 1.5)
                                )
                                .overlay {
                                    if isSelected {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundStyle(.white)
                                    }
                                }

                            // Name
                            Text(template.name)
                                .font(TallyFont.heading(14, weight: .medium))
                                .foregroundStyle(c.text)

                            Spacer()

                            // Type badge
                            Text(badgeText(template).uppercased())
                                .font(TallyFont.mono(9, weight: .semibold))
                                .tracking(0.6)
                                .foregroundStyle(typeColor(for: template.type, colors: c))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(typeColor(for: template.type, colors: c).opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                        .padding(14)
                        .background(isSelected ? c.accentSoft : c.bg2)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(isSelected ? c.accent : c.rule, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            // Add selected button
            Button {
                addSelected()
            } label: {
                Text(selected.isEmpty ? "SELECT TASKS TO ADD" : "ADD \(selected.count) TASK\(selected.count == 1 ? "" : "S")")
                    .font(TallyFont.mono(12, weight: .semibold))
                    .tracking(1.0)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(selected.isEmpty ? c.dim3 : c.accent)
                    .foregroundStyle(selected.isEmpty ? c.dim : .white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .disabled(selected.isEmpty)

            // Secondary actions
            VStack(spacing: 12) {
                Button {
                    onBrowseAll()
                } label: {
                    Text("Browse all templates")
                        .font(TallyFont.heading(14, weight: .medium))
                        .foregroundStyle(c.accent)
                }

                Button {
                    onCreateCustom()
                } label: {
                    Text("Skip — I'll create my own")
                        .font(TallyFont.body(13))
                        .foregroundStyle(c.dim)
                }
            }
        }
        .padding(.top, 20)
    }

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

    private func addSelected() {
        for id in selected {
            if let template = catalog.templates.first(where: { $0.id == id }) {
                let task = taskFromTemplate(template)
                modelContext.insert(task)
            }
        }
    }
}
