//
//  QuickAddToast.swift
//  Tally
//
//  Floating toast shown after quick-adding a task from a template.
//  Parent manages visibility; this view handles appearance and auto-dismiss.

import SwiftUI

struct QuickAddToast: View {
    let taskName: String
    let onEdit: () -> Void
    let onDismiss: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var isVisible = false

    var body: some View {
        let c = TallyColors.resolve(colorScheme)

        Group {
            if isVisible {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(c.pos)

                    Text("Added \(taskName)")
                        .font(TallyFont.heading(14, weight: .medium))
                        .foregroundStyle(c.text)
                        .lineLimit(1)

                    Spacer()

                    Button {
                        withAnimation { isVisible = false }
                        onEdit()
                    } label: {
                        Text("EDIT")
                            .font(TallyFont.mono(11, weight: .semibold))
                            .tracking(0.8)
                            .foregroundStyle(c.accent)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(c.accentSoft)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(c.bg2)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(c.rule, lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .onAppear {
            withAnimation(.spring(duration: 0.3)) {
                isVisible = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation(.easeOut(duration: 0.25)) {
                    isVisible = false
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    onDismiss()
                }
            }
        }
    }
}
