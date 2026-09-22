//
//  CoachingCardView.swift
//  SwingCoach
//

import SwiftUI

/// The per-swing "fix this first" card (plan Stage 1): the single worst check,
/// a concrete drill, and what we measured. Severity-tinted with a leading
/// accent rule. Pure presentation — the check, drill, and measurement copy are
/// decided upstream (CoachingEngine + FeedbackGenerator).
struct CoachingCardView: View {
    let result: CheckResult
    let drill: String

    var body: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(result.severity.fill)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: Space.s) {
                Label("Fix this first", systemImage: "target")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(result.severity.text)

                Text(result.checkName.displayName)
                    .font(.headline)

                Text(drill)
                    .font(.callout)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(FeedbackGenerator.measurementDescription(for: result.checkName,
                                                              measuredValue: result.measuredValue))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(Space.l)
        }
        .background(result.severity.fill.opacity(0.14))
        .clipShape(RoundedRectangle(cornerRadius: Radius.l, style: .continuous))
    }
}

/// The positive counterpart shown when every scored check cleared its good
/// band: honest praise instead of a manufactured fault (plan P1).
struct AllChecksGoodCardView: View {
    let message: String

    var body: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(Severity.good.fill)
                .frame(width: 4)

            HStack(alignment: .top, spacing: Space.s + 2) {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(Severity.good.fill)
                Text(message)
                    .font(.callout)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(Space.l)
        }
        .background(Severity.good.fill.opacity(0.14))
        .clipShape(RoundedRectangle(cornerRadius: Radius.l, style: .continuous))
    }
}

#Preview {
    VStack(spacing: 12) {
        CoachingCardView(
            result: CheckResult(checkName: .tempo, score: 12, measuredValue: 1.6,
                                feedback: "You're rushing your downswing."),
            drill: "Try the pause drill: make your normal backswing, then pause for a full second at the top before starting down.")
        AllChecksGoodCardView(message: FeedbackGenerator.allChecksGoodMessage)
    }
    .padding()
}
