//
//  SegmentedDayBar.swift
//  Tally
//
//  Row of colored tiles — one per scheduled task — showing day shape at a glance.

import SwiftUI

struct SegmentedDayBar: View {
    let statuses: [TaskStatusKind]
    var height: CGFloat = 8
    var spacing: CGFloat = 3

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let c = TallyColors.resolve(colorScheme)
        HStack(spacing: spacing) {
            ForEach(Array(statuses.enumerated()), id: \.offset) { _, status in
                RoundedRectangle(cornerRadius: 2)
                    .fill(c.statusColor(status))
                    .frame(height: height)
            }
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        SegmentedDayBar(statuses: [.done, .done, .partial, .overdue, .due])
        SegmentedDayBar(statuses: [.done, .done, .done, .done, .done])
        SegmentedDayBar(statuses: [.overdue, .overdue, .due])
    }
    .padding()
}
