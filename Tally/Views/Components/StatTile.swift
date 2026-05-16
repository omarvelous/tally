//
//  StatTile.swift
//  Tally
//
//  Label + large mono value tile for stats screens.

import SwiftUI

struct StatTile: View {
    let label: String
    let value: String

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let c = TallyColors.resolve(colorScheme)
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(TallyFont.label())
                .textCase(.uppercase)
                .tracking(1.2)
                .foregroundStyle(c.dim)
            Text(value)
                .font(TallyFont.mono(20, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(c.text)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(c.bg2)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(c.rule, lineWidth: 1)
        )
    }
}

#Preview {
    HStack(spacing: 8) {
        StatTile(label: "Current", value: "14d")
        StatTile(label: "Best", value: "28d")
        StatTile(label: "Avg", value: "87%")
    }
    .padding()
}
