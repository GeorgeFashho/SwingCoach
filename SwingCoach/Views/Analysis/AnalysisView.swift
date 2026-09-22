//
//  AnalysisView.swift
//  SwingCoach
//

import SwiftUI

/// Summary of one swing's analysis: a row per applicable check — scored, or
/// honestly explained when it couldn't be measured — plus which checks this
/// camera angle can't see at all. Renders the CheckOutcome values produced
/// by PlaybackViewModel; views never re-derive scores.
struct AnalysisView: View {
    let outcomes: [CheckOutcome]
    let cameraAngle: CameraAngle

    private var inapplicableChecks: [CheckName] {
        CheckName.allCases.filter { !$0.isApplicable(to: cameraAngle) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Swing Analysis")
                .font(.headline)

            ForEach(outcomes, id: \.checkName) { outcome in
                switch outcome {
                case .scored(let result):
                    NavigationLink {
                        CheckDetailView(result: result)
                    } label: {
                        scoredRow(result)
                    }
                    .buttonStyle(.plain)
                case .insufficientData(let name, let message):
                    unmeasuredRow(name: name.displayName, message: message)
                }
            }

            if !inapplicableChecks.isEmpty {
                Text("Not measured from this angle")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.top, 6)

                ForEach(inapplicableChecks, id: \.self) { check in
                    if let message = FeedbackGenerator.skippedMessage(for: check) {
                        unmeasuredRow(name: check.displayName, message: message)
                    }
                }
            }
        }
    }

    private func scoredRow(_ result: CheckResult) -> some View {
        HStack(spacing: 12) {
            ScoreGauge(score: result.score, severity: result.severity)
            VStack(alignment: .leading, spacing: 2) {
                Text(result.checkName.displayName)
                    .font(.subheadline.weight(.medium))
                Text(result.severity.displayName)
                    .font(.caption)
                    .foregroundStyle(result.severity.text)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(Space.m)
        .background(Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: Radius.l, style: .continuous))
    }

    private func unmeasuredRow(name: String, message: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "eye.slash")
                .foregroundStyle(.secondary)
                .frame(width: 44, height: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.subheadline.weight(.medium))
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(Space.m)
        .background(Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: Radius.l, style: .continuous))
    }
}
