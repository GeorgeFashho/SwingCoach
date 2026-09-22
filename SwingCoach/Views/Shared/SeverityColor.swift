//
//  SeverityColor.swift
//  SwingCoach
//

import SwiftUI

/// The single severity→presentation mapping. Every view renders severity
/// through this extension so good/needsWork/critical can never look
/// different in different places.
///
/// Split into two color tokens (design spec §2.2): `fill` is the vivid signal
/// for icons, the gauge arc, the accent rule, and tint backgrounds; `text` is
/// a darkened variant for small COLORED labels so they clear WCAG AA on white
/// (the vivid fills fail AA as text). Tone stays in copy — the encouraging
/// "Looking Good / Needs Work / Focus Here" labels are unchanged.
nonisolated extension Severity {

    /// Vivid signal — icons, the ScoreGauge arc, the 4pt accent rule, tint fills.
    var fill: Color {
        switch self {
        case .good: .adaptive(light: 0x34C759, dark: 0x30D158)
        case .needsWork: .adaptive(light: 0xFF9500, dark: 0xFF9F0A)
        case .critical: .adaptive(light: 0xFF3B30, dark: 0xFF453A)
        }
    }

    /// AA-safe colored label text on a card/white surface (darkened in light,
    /// the vivid value in dark where it already passes).
    var text: Color {
        switch self {
        case .good: .adaptive(light: 0x1E7A37, dark: 0x30D158)
        case .needsWork: .adaptive(light: 0x9C5D00, dark: 0xFF9F0A)
        case .critical: .adaptive(light: 0xC0392B, dark: 0xFF453A)
        }
    }

    /// Back-compat alias for the vivid signal color.
    var color: Color { fill }

    var displayName: String {
        switch self {
        case .good: "Looking Good"
        case .needsWork: "Needs Work"
        case .critical: "Focus Here"
        }
    }

    var iconName: String {
        switch self {
        case .good: "checkmark.circle.fill"
        case .needsWork: "exclamationmark.circle.fill"
        case .critical: "exclamationmark.triangle.fill"
        }
    }
}
