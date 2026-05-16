//
//  PresetChipGrid.swift
//  Tally
//
//  Grid of quick-log buttons for count/timer tasks.

import SwiftUI

struct PresetChipGrid: View {
    let values: [Double]
    let unit: String?
    let onTap: (Double) -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let c = TallyColors.resolve(colorScheme)
        let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: min(values.count, 4))

        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(values, id: \.self) { value in
                Button {
                    onTap(value)
                } label: {
                    Text("+\(Int(value))")
                        .font(TallyFont.heading(14, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(c.accentSoft)
                        .foregroundStyle(c.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

#Preview {
    PresetChipGrid(values: [5, 10, 25, 50], unit: "reps") { value in
        print("Tapped +\(Int(value))")
    }
    .padding()
}
