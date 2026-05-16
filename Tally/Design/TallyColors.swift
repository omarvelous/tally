//
//  TallyColors.swift
//  Tally
//
//  Color palette ported from tally-ui.jsx lines 5-37.
//  Usage: TallyColors.light.accent or via @Environment(\.colorScheme)

import SwiftUI

struct TallyColors: Sendable {
    let bg: Color
    let bg2: Color
    let bg3: Color
    let bg4: Color
    let text: Color
    let dim: Color
    let dim2: Color
    let dim3: Color
    let rule: Color
    let accent: Color
    let accentSoft: Color
    let pos: Color
    let neg: Color
    let warn: Color

    static let light = TallyColors(
        bg:         Color(hex: 0xF7F5F1),
        bg2:        Color.white,
        bg3:        Color(hex: 0xEFEBE3),
        bg4:        Color(hex: 0xE5DFD2),
        text:       Color(hex: 0x16161A),
        dim:        Color(hex: 0x16161A, alpha: 0.55),
        dim2:       Color(hex: 0x16161A, alpha: 0.30),
        dim3:       Color(hex: 0x16161A, alpha: 0.14),
        rule:       Color(hex: 0x16161A, alpha: 0.08),
        accent:     Color(hex: 0x2440D7),
        accentSoft: Color(hex: 0x2440D7, alpha: 0.10),
        pos:        Color(hex: 0x1E7A36),
        neg:        Color(hex: 0xB3331A),
        warn:       Color(hex: 0xA36A12)
    )

    static let dark = TallyColors(
        bg:         Color(hex: 0x0B0C10),
        bg2:        Color(hex: 0x15171D),
        bg3:        Color(hex: 0x1E2129),
        bg4:        Color(hex: 0x2A2E38),
        text:       Color(hex: 0xECEAE4),
        dim:        Color(hex: 0xECEAE4, alpha: 0.62),
        dim2:       Color(hex: 0xECEAE4, alpha: 0.32),
        dim3:       Color(hex: 0xECEAE4, alpha: 0.16),
        rule:       Color(hex: 0xECEAE4, alpha: 0.08),
        accent:     Color(hex: 0x7A8FFF),
        accentSoft: Color(hex: 0x7A8FFF, alpha: 0.16),
        pos:        Color(hex: 0x9EE6A8),
        neg:        Color(hex: 0xFF8B72),
        warn:       Color(hex: 0xFFD27A)
    )

    static func resolve(_ colorScheme: ColorScheme) -> TallyColors {
        colorScheme == .dark ? .dark : .light
    }

    /// Color for a given task status kind.
    func statusColor(_ status: TaskStatusKind) -> Color {
        switch status {
        case .done:    return pos
        case .partial: return accent
        case .overdue: return neg
        case .due:     return dim2
        case .off:     return dim3
        }
    }
}

// MARK: - Hex initializer

extension Color {
    init(hex: UInt, alpha: Double = 1.0) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}

// MARK: - Environment key

private struct TallyColorsKey: EnvironmentKey {
    static let defaultValue = TallyColors.light
}

extension EnvironmentValues {
    var tallyColors: TallyColors {
        get { self[TallyColorsKey.self] }
        set { self[TallyColorsKey.self] = newValue }
    }
}
