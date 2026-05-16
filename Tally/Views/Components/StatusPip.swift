//
//  StatusPip.swift
//  Tally
//
//  Colored circle indicating task status.

import SwiftUI

struct StatusPip: View {
    let status: TaskStatusKind
    var size: CGFloat = 8

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Circle()
            .fill(TallyColors.resolve(colorScheme).statusColor(status))
            .frame(width: size, height: size)
    }
}

#Preview {
    HStack(spacing: 12) {
        StatusPip(status: .done)
        StatusPip(status: .partial)
        StatusPip(status: .overdue)
        StatusPip(status: .due)
        StatusPip(status: .off)
    }
    .padding()
}
