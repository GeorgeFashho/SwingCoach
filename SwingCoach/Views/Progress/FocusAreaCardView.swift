//
//  FocusAreaCardView.swift
//  SwingCoach
//

import SwiftUI

/// The cross-session focus area on the Progress tab (plan Stage 2): the check
/// to work on across practice sessions, its mean-score gauge, a trend arrow,
/// and a drill. Pure presentation over a CoachingEngine.FocusAreaResult.
struct FocusAreaCardView: View {
    let focusArea: CoachingEngine.FocusAreaResult

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Your focus area", systemImage: "scope")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                trendBadge
            }

            HStack(spacing: 14) {
                ScoreGauge(score: focusArea.meanScore, severity: focusArea.severity, diameter: 56)
                VStack(alignment: .leading, spacing: 3) {
                    Text(focusArea.checkName.displayName)
                        .font(.headline)
                    Text("Your average across recent swings")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Text(FeedbackGenerator.drill(for: focusArea.checkName,
                                         measuredValue: focusArea.measuredValue))
                .font(.callout)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .cardSurface()
    }

    private var trendBadge: some View {
        Label(trendStyle.label, systemImage: trendStyle.symbol)
            .font(.caption.weight(.medium))
            .foregroundStyle(trendStyle.color)
    }

    private var trendStyle: (symbol: String, label: String, color: Color) {
        switch focusArea.trend {
        case .improving: ("arrow.up.right", "Improving", Severity.good.text)
        case .steady: ("arrow.right", "Steady", Color.secondary)
        case .declining: ("arrow.down.right", "Declining", Severity.critical.text)
        }
    }
}
