//
//  FeedbackCard.swift
//  SwingCoach
//

import SwiftUI

/// The plain-English coaching feedback in a severity-tinted card. Pure
/// presentation: the copy comes from FeedbackGenerator via CheckResult.
struct FeedbackCard: View {
    let text: String
    let severity: Severity

    var body: some View {
        HStack(alignment: .top, spacing: Space.s + 2) {
            Image(systemName: severity.iconName)
                .foregroundStyle(severity.fill)
            Text(text)
                .font(.callout)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(Space.l)
        .background(severity.fill.opacity(0.14),
                    in: RoundedRectangle(cornerRadius: Radius.l, style: .continuous))
    }
}

#Preview {
    VStack(spacing: 12) {
        FeedbackCard(text: "Great head stability! Your head stayed nice and steady throughout the swing.",
                     severity: .good)
        FeedbackCard(text: "Your hips are sliding sideways during the backswing instead of turning.",
                     severity: .critical)
    }
    .padding()
}
