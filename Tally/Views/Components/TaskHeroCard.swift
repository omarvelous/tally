//
//  TaskHeroCard.swift
//  Tally
//
//  Type-specific progress hero card. Extracted from TaskDetailView for reuse in LogSheet.

import SwiftUI

struct TaskHeroCard: View {
    let task: TallyTask
    let state: TaskStatus

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let c = TallyColors.resolve(colorScheme)

        switch task.type {
        case .count, .timer:
            let sum = state.sum ?? 0
            let target = task.target ?? 1
            TallyCard {
                VStack(spacing: 4) {
                    Text(task.type == .timer ? "MINUTES TODAY" : "LOGGED TODAY")
                        .font(TallyFont.label())
                        .textCase(.uppercase)
                        .tracking(1.2)
                        .foregroundStyle(c.dim)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Spacer()
                        Text(verbatim: "\(Int(sum.rounded()))")
                            .font(TallyFont.heading(72, weight: .medium))
                            .monospacedDigit()
                            .foregroundStyle(state.status == .done ? c.pos : c.text)
                        Text(verbatim: "/ \(Int(target))")
                            .font(TallyFont.heading(24, weight: .medium))
                            .foregroundStyle(c.dim)
                        Spacer()
                    }

                    Text(verbatim: "\((task.unit ?? "").uppercased()) · \(Int(state.pct * 100))% COMPLETE")
                        .font(TallyFont.mono(11))
                        .foregroundStyle(c.dim)

                    ProgressBarView(pct: state.pct, height: 8, color: state.status == .done ? c.pos : c.accent)
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
                    Text(state.status == .done ? "Done ✓" : state.status == .overdue ? "Overdue" : "Pending")
                        .font(TallyFont.heading(40, weight: .medium))
                        .foregroundStyle(state.status == .done ? c.pos : c.text)
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
                    Text(state.label == "—" ? "—" : state.label)
                        .font(TallyFont.heading(40, weight: .medium))
                        .foregroundStyle(state.status == .done ? c.pos : c.text)
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
                        Text(state.value != nil ? String(format: "%.1f", state.value!) : "—")
                            .font(TallyFont.heading(56, weight: .medium))
                            .monospacedDigit()
                            .foregroundStyle(state.status == .done ? c.pos : c.text)
                        Text(task.unit ?? "")
                            .font(TallyFont.heading(20, weight: .medium))
                            .foregroundStyle(c.dim)
                    }
                }
            }
        }
    }
}
