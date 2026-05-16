//
//  SwipeableRow.swift
//  Tally
//
//  Generic horizontal-swipe wrapper. Pull left past threshold to reveal
//  a colored pill and trigger an action on release.

import SwiftUI

struct SwipeableRow<Content: View>: View {
    let pillLabel: String
    let pillColor: Color
    var threshold: CGFloat = 70
    let onAction: () -> Void
    var disabled: Bool = false
    @ViewBuilder let content: () -> Content

    @State private var offset: CGFloat = 0
    @State private var isSwiping = false

    var body: some View {
        ZStack(alignment: .trailing) {
            // Pill revealed behind content
            if offset < -10 {
                HStack {
                    Spacer()
                    Text(verbatim: pillLabel)
                        .font(TallyFont.mono(11, weight: .bold))
                        .tracking(0.8)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(pillColor)
                        .clipShape(Capsule())
                }
                .padding(.trailing, 8)
            }

            // Row content slides left
            content()
                .offset(x: min(offset, 0))
                .gesture(
                    disabled ? nil : DragGesture(minimumDistance: 15)
                        .onChanged { value in
                            // Lock to horizontal axis
                            if abs(value.translation.width) > abs(value.translation.height) {
                                isSwiping = true
                                offset = min(0, value.translation.width)
                            }
                        }
                        .onEnded { value in
                            if isSwiping && value.translation.width < -threshold {
                                onAction()
                            }
                            withAnimation(.spring(duration: 0.3)) {
                                offset = 0
                            }
                            isSwiping = false
                        }
                )
                .animation(.spring(duration: 0.3), value: offset)
        }
        .clipped()
    }
}

#Preview {
    VStack(spacing: 0) {
        SwipeableRow(pillLabel: "LOG →", pillColor: .green, onAction: { print("Log!") }) {
            HStack {
                Circle().fill(.blue).frame(width: 8, height: 8)
                Text("Push-ups")
                Spacer()
                Text("65%").foregroundStyle(.secondary)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(.white)
        }
        Divider()
        SwipeableRow(pillLabel: "DELETE", pillColor: .red, onAction: { print("Delete!") }) {
            HStack {
                Text("08:14")
                Spacer()
                Text("+25 reps")
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(.white)
        }
    }
}
