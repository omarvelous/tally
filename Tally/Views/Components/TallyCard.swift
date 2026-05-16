//
//  TallyCard.swift
//  Tally
//
//  Rounded card container with border or soft accent background.

import SwiftUI

struct TallyCard<Content: View>: View {
    var soft: Bool = false
    @ViewBuilder let content: () -> Content

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let c = TallyColors.resolve(colorScheme)
        content()
            .padding(16)
            .background(soft ? c.accentSoft : c.bg2)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(soft ? Color.clear : c.rule, lineWidth: 1)
            )
    }
}

#Preview {
    VStack(spacing: 12) {
        TallyCard {
            Text("Default card")
        }
        TallyCard(soft: true) {
            Text("Soft accent card")
        }
    }
    .padding()
}
