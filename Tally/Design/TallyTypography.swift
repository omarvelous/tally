//
//  TallyTypography.swift
//  Tally
//
//  Typography helpers. Uses system fonts as stand-in until IBM Plex is bundled.
//  Ported from tally-ui.jsx lines 39-47.

import SwiftUI

enum TallyFont {
    /// Heading style: tight line-height, slight negative tracking.
    static func heading(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .default)
    }

    /// Monospace style: tabular figures for aligned numbers.
    static func mono(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    /// Body style: regular weight, looser line-height.
    static func body(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }

    /// Label style: small caps, wide tracking.
    static func label() -> Font {
        .system(size: 10, weight: .medium, design: .monospaced)
    }
}

// MARK: - View modifiers

extension View {
    /// Section header label style: uppercase, wide tracking, dim color.
    func tallyLabel() -> some View {
        self
            .font(TallyFont.label())
            .textCase(.uppercase)
            .tracking(1.4)
    }

    /// Tabular figures for mono-spaced number alignment.
    func tabularFigures() -> some View {
        self.monospacedDigit()
    }
}
