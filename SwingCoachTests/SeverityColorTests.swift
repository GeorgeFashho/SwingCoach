//
//  SeverityColorTests.swift
//  SwingCoachTests
//

import SwiftUI
import UIKit
import Testing
@testable import SwingCoach

struct SeverityColorTests {

    /// The encouraging labels + status icons are a stable contract (copy and
    /// iconography other screens depend on).
    @Test func displayNamesAndIconsAreStable() {
        #expect(Severity.good.displayName == "Looking Good")
        #expect(Severity.needsWork.displayName == "Needs Work")
        #expect(Severity.critical.displayName == "Focus Here")
        #expect(Severity.good.iconName == "checkmark.circle.fill")
        #expect(Severity.needsWork.iconName == "exclamationmark.circle.fill")
        #expect(Severity.critical.iconName == "exclamationmark.triangle.fill")
    }

    /// Each severity maps to a distinct vivid fill — the shared 3-color language.
    @Test func fillsAreDistinct() {
        let hexes = [Severity.good, .needsWork, .critical].map { Self.hexLight($0.fill) }
        #expect(Set(hexes).count == 3)
    }

    /// Scores at the severity cutoffs (70 and 30, both dyadic) route through
    /// Severity(score:) into the same shared fill mapping.
    @Test func scoreDerivedSeveritiesRouteThroughTheSameMapping() {
        #expect(Self.hexLight(Severity(score: 70).fill) == Self.hexLight(Severity.good.fill))
        #expect(Self.hexLight(Severity(score: 30).fill) == Self.hexLight(Severity.needsWork.fill))
        #expect(Self.hexLight(Severity(score: 0).fill) == Self.hexLight(Severity.critical.fill))
    }

    /// The colored label text tokens must clear WCAG AA (4.5:1) on white so
    /// small severity labels stay legible in light mode (design spec §2.2 —
    /// the vivid fills themselves fail AA as text, which is why `text` exists).
    @Test func textTokensClearWCAG_AA_onWhite() {
        for severity in [Severity.good, .needsWork, .critical] {
            #expect(Self.contrastOnWhite(severity.text) >= 4.5)
        }
    }

    // MARK: - Helpers (resolve adaptive Colors to light-mode sRGB)

    private static func rgbLight(_ color: Color) -> (Double, Double, Double) {
        let ui = UIColor(color).resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        return (Double(r), Double(g), Double(b))
    }

    private static func hexLight(_ color: Color) -> Int {
        let (r, g, b) = rgbLight(color)
        return (Int((r * 255).rounded()) << 16)
            | (Int((g * 255).rounded()) << 8)
            | Int((b * 255).rounded())
    }

    /// WCAG 2.x contrast ratio of `color` against white.
    private static func contrastOnWhite(_ color: Color) -> Double {
        let (r, g, b) = rgbLight(color)
        func lin(_ c: Double) -> Double { c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
        let luminance = 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b)
        return (1.0 + 0.05) / (luminance + 0.05)
    }
}
