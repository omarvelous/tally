//
//  CircularRingView.swift
//  Tally
//
//  Circular progress ring.

import SwiftUI

struct CircularRingView: View {
    let pct: Double
    var size: CGFloat = 56
    var lineWidth: CGFloat = 5
    var color: Color? = nil

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let c = TallyColors.resolve(colorScheme)
        ZStack {
            Circle()
                .stroke(c.bg3, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: min(pct, 1.0))
                .stroke(color ?? c.accent, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: size, height: size)
    }
}

#Preview {
    HStack(spacing: 20) {
        CircularRingView(pct: 0.65)
        CircularRingView(pct: 1.0, color: .green)
        CircularRingView(pct: 0.3, size: 40, lineWidth: 4)
    }
    .padding()
}
