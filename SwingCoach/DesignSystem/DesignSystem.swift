//
//  DesignSystem.swift
//  SwingCoach
//
//  The single source of truth for spacing, radius, color, type, and the
//  reusable card/button treatments. Research-backed tokens (see
//  .omc/research/ui-design-spec.md): a deep fairway-green brand distinct from
//  the vivid "good" signal green, a 4pt spacing grid, and a 3-step radius scale
//  — the discipline that turns an ad-hoc prototype into a polished app.
//

import SwiftUI
import UIKit

// MARK: - Spacing (4/8pt grid)

nonisolated enum Space {
    static let xs: CGFloat = 4
    static let s: CGFloat = 8
    static let m: CGFloat = 12
    static let l: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
    static let xxxl: CGFloat = 48
}

// MARK: - Corner radius (always .continuous)

nonisolated enum Radius {
    static let s: CGFloat = 8    // chips, badges, thumbnails
    static let m: CGFloat = 12   // buttons, inner elements
    static let l: CGFloat = 16   // cards
    static let xl: CGFloat = 22  // sheets, hero panels
}

// MARK: - Adaptive color from hex

extension UIColor {
    /// sRGB color from a 0xRRGGBB literal.
    convenience init(hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: 1)
    }
}

extension Color {
    /// A color that resolves to `light`/`dark` (0xRRGGBB) by trait — the
    /// programmatic equivalent of an Asset-Catalog light/dark color set.
    /// `nonisolated` so the `nonisolated` Severity extension can build its
    /// fill/text tokens without a main-actor hop.
    nonisolated static func adaptive(light: UInt32, dark: UInt32) -> Color {
        Color(uiColor: UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

// MARK: - Brand palette (deep fairway green — distinct from the "good" signal)

extension Color {
    /// Tint: selected tab, links, icon accents, keypoint dots, gauge brand.
    static let brandPrimary = Color.adaptive(light: 0x1F7A46, dark: 0x35C878)
    /// Filled-CTA background paired with a WHITE label. Separate from the tint
    /// because the bright dark tint (#35C878) fails white-text contrast; this
    /// deeper fill keeps white AA-legible.
    static let brandPrimaryFill = Color.adaptive(light: 0x1F7A46, dark: 0x1E8E52)
    /// Deep supportive accent — section emphasis, brand illustration linework.
    static let brandSecondary = Color.adaptive(light: 0x14532D, dark: 0x2E7D4F)
}

// MARK: - Typography helper (SF Rounded, numbers only)

extension Font {
    /// SF Rounded — reserved for numerals/metrics (scores, countdown, tempo).
    /// Pair with `.monospacedDigit()`. Body/labels stay SF Pro.
    static func metric(_ size: CGFloat, _ weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

// MARK: - Card surface

extension View {
    /// The one card treatment: an elevated grouped surface with the standard
    /// radius + padding. Every card goes through this so they can't diverge.
    func cardSurface(padding: CGFloat = Space.l, radius: CGFloat = Radius.l) -> some View {
        self
            .padding(padding)
            .background(Color(.secondarySystemGroupedBackground),
                        in: .rect(cornerRadius: radius, style: .continuous))
    }
}

// MARK: - Button styles

/// Filled fairway-green CTA with a white label. Use instead of
/// `.borderedProminent` so the AA-safe `brandPrimaryFill` is used (not the
/// too-bright accent tint in dark mode).
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(Color.brandPrimaryFill,
                        in: .rect(cornerRadius: Radius.m, style: .continuous))
            .opacity(configuration.isPressed ? 0.9 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
