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
        let overTarget = pct > 1.0
        let basePct = overTarget ? 1.0 / pct : min(pct, 1.0)
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: radius)
                    .fill(c.bg3)
                if overTarget {
                    // Full bar in warn to show over-target
                    RoundedRectangle(cornerRadius: radius)
                        .fill(c.warn)
                    // Base portion (up to target) in normal color
                    RoundedRectangle(cornerRadius: radius)
                        .fill(color ?? c.accent)
                        .frame(width: geo.size.width * basePct)
                } else {
                    RoundedRectangle(cornerRadius: radius)
                        .fill(color ?? c.accent)
                        .frame(width: geo.size.width * basePct)
                }
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
