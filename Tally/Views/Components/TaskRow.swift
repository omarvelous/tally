//
//  TaskRow.swift
//  Tally
//
//  Reusable task row: status pip + name + time/value label + sparkline + pct.

import SwiftUI

struct TaskRow: View {
    let task: TallyTask
    let state: TaskStatus
    let sparkline: [Double]

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let c = TallyColors.resolve(colorScheme)

        HStack(spacing: 10) {
            StatusPip(status: state.status)

            VStack(alignment: .leading, spacing: 2) {
                Text(task.name)
                    .font(TallyFont.heading(14, weight: .medium))
                    .foregroundStyle(c.text)
                Text(state.label)
                    .font(TallyFont.mono(11))
                    .foregroundStyle(c.dim)
            }

            Spacer()

            SparklineView(values: sparkline)

            Text(pctText)
                .font(TallyFont.mono(12, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(c.dim)
                .frame(width: 36, alignment: .trailing)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .contentShape(Rectangle())
    }

    private var pctText: String {
        if state.status == .off { return "—" }
        return "\(Int(state.pct * 100))%"
    }
}

#Preview {
    let task = TallyTask(name: "Push-ups", type: .count, target: 100, unit: "reps", days: [], times: ["08:00"])
    let state = TaskStatus(status: .partial, pct: 0.65, sum: 65, label: "65 / 100 reps", count: 3, value: nil)
    let sparkline = [0.8, 1.0, 1.0, 0.6, 1.0, 1.0, 0.9, 1.0, 0.7, 1.0, 0.8, 1.0, 1.0, 0.65]

    VStack(spacing: 0) {
        TaskRow(task: task, state: state, sparkline: sparkline)
        Divider()
        TaskRow(
            task: TallyTask(name: "Vitamins", type: .check, days: [], times: ["07:30"]),
            state: TaskStatus(status: .done, pct: 1, sum: nil, label: "Done", count: 1, value: nil),
            sparkline: [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1]
        )
    }
    .padding()
}
