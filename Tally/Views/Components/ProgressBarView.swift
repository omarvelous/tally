//
//  ProgressBarView.swift
//  Tally
//
//  Horizontal progress bar.

import SwiftUI

struct ProgressBarView: View {
    let pct: Double
    var height: CGFloat = 6
    var color: Color? = nil
    var radius: CGFloat = 3

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let c = TallyColors.resolve(colorScheme)
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: radius)
                    .fill(c.bg3)
                RoundedRectangle(cornerRadius: radius)
                    .fill(color ?? c.accent)
                    .frame(width: geo.size.width * min(pct, 1.0))
            }
        }
        .frame(height: height)
    }
}

#Preview {
    VStack(spacing: 16) {
        ProgressBarView(pct: 0.65)
        ProgressBarView(pct: 1.0, color: .green)
        ProgressBarView(pct: 0.3, height: 8)
    }
    .padding()
}
