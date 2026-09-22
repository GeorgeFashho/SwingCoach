//
//  CheckDetailView.swift
//  SwingCoach
//

import SwiftUI

/// Deep dive on one check: the score gauge, the coaching feedback, what the
/// check measures, and the raw measurement against the good range. All copy
/// comes from FeedbackGenerator; score and severity come straight from the
/// CheckResult produced by AnalysisEngine.
struct CheckDetailView: View {
    let result: CheckResult

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(spacing: 8) {
                    ScoreGauge(score: result.score, severity: result.severity, diameter: 120)
                    Text(result.severity.displayName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(result.severity.text)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 8)

                FeedbackCard(text: result.feedback, severity: result.severity)

                section("What this means",
                        text: FeedbackGenerator.whatThisMeans(for: result.checkName))

                section("What we measured",
                        text: FeedbackGenerator.measurementDescription(for: result.checkName,
                                                                       measuredValue: result.measuredValue))
            }
            .padding()
        }
        .navigationTitle(result.checkName.displayName)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func section(_ title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}
