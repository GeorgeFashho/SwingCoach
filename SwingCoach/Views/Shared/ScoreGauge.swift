//
//  ScoreGauge.swift
//  SwingCoach
//

import SwiftUI

/// Circular score indicator: an arc that fills with the check's 0–100 score
/// in its severity color, with the rounded score in the center. Pure
/// presentation — score and severity come straight from a CheckResult.
struct ScoreGauge: View {
    let score: Double
    let severity: Severity
    var diameter: CGFloat = 44

    private var lineWidth: CGFloat { max(4, diameter / 11) }

    var body: some View {
        ZStack {
            Circle()
                .stroke(.quaternary, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: min(max(score / 100, 0), 1))
                .stroke(severity.fill, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.5), value: score)
            Text("\(Int(score.rounded()))")
                .font(.metric(diameter * 0.36))
                .monospacedDigit()
        }
        .padding(lineWidth / 2)
        .frame(width: diameter, height: diameter)
    }
}

#Preview {
    HStack(spacing: 20) {
        ScoreGauge(score: 92, severity: .good)
        ScoreGauge(score: 55, severity: .needsWork)
        ScoreGauge(score: 18, severity: .critical, diameter: 120)
    }
    .padding()
}
