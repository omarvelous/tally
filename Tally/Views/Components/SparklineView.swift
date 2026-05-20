//
//  SparklineView.swift
//  Tally
//
//  14-day mini line chart. Ported from tally-ui.jsx Spark component.
//  Shows over-target values (>1.0) in warn/gold color.

import SwiftUI

struct SparklineView: View {
    let values: [Double]
    var width: CGFloat = 56
    var height: CGFloat = 18

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let c = TallyColors.resolve(colorScheme)
        let lastValue = min(values.last ?? 0, 1.0)
        let strokeColor = lastValue < 0.7 ? c.dim2 : c.accent

        Canvas { context, size in
            guard values.count > 1 else { return }
            let maxIndex = CGFloat(values.count - 1)

            var path = Path()
            for (i, v) in values.enumerated() {
                let x = (CGFloat(i) / maxIndex) * (size.width - 2) + 1
                let clamped = min(v, 1.0)
                let y = size.height - 1 - CGFloat(clamped) * (size.height - 2)
                if i == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
            context.stroke(path, with: .color(strokeColor), lineWidth: 1.2)

            // End dot
            if let last = values.last {
                let x = size.width - 1
                let clamped = min(last, 1.0)
                let y = size.height - 1 - CGFloat(clamped) * (size.height - 2)
                let dot = Path(ellipseIn: CGRect(x: x - 2, y: y - 2, width: 4, height: 4))
                context.fill(dot, with: .color(strokeColor))
            }
        }
        .frame(width: width, height: height)
    }
}

#Preview {
    VStack(spacing: 12) {
        SparklineView(values: [0.2, 0.4, 0.6, 0.8, 1.0, 1.0, 0.9, 1.0, 0.7, 1.0, 0.8, 1.0, 1.0, 1.0])
        SparklineView(values: [1.0, 0.8, 0.5, 0.3, 0.2, 0.4, 0.5, 0.3, 0.4, 0.2, 0.1, 0.3, 0.4, 0.5])
        SparklineView(values: [0.5, 0.8, 1.0, 1.2, 1.5, 1.3, 1.0, 0.9, 1.1, 1.4, 1.6, 1.2, 1.0, 1.8])
        SparklineView(values: [])
    }
    .padding()
}
