//
//  PresetChipGrid.swift
//  Tally
//
//  Grid of quick-log buttons for count/timer tasks.
//  Optional selectedValue highlights the staged chip.

import SwiftUI

struct PresetChipGrid: View {
    let values: [Double]
    let unit: String?
    var selectedValue: Double? = nil
    let onTap: (Double) -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let c = TallyColors.resolve(colorScheme)
        let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: min(values.count, 4))

        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(values, id: \.self) { value in
                let isSelected = selectedValue == value
                Button {
                    onTap(value)
                } label: {
                    Text(verbatim: "+\(Int(value))")
                        .font(TallyFont.heading(14, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(isSelected ? c.accent : c.accentSoft)
                        .foregroundStyle(isSelected ? .white : c.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

#Preview {
    PresetChipGrid(values: [5, 10, 25, 50], unit: "reps", selectedValue: 25) { value in
        print("Tapped +\(Int(value))")
    }
    .padding()
}
