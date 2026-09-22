//
//  CheckResult.swift
//  SwingCoach
//

/// The outcome of one biomechanical check: the raw measurement, its 0–100
/// score, the severity derived from that score, and beginner-friendly
/// feedback. Persisted as AnalysisResult in Phase 3b.
nonisolated struct CheckResult {
    let checkName: CheckName
    let score: Double
    let measuredValue: Double
    let severity: Severity
    let feedback: String

    init(checkName: CheckName, score: Double, measuredValue: Double, feedback: String) {
        self.checkName = checkName
        self.score = score
        self.measuredValue = measuredValue
        self.severity = Severity(score: score)
        self.feedback = feedback
    }
}

/// The shared piecewise-linear scoring scheme from plan section 3,
/// implemented once so every check scores the same way: 100 at the good
/// band's best point, 70 at its edges, 30 at the critical limits, tapering
/// to 0 beyond them (over the same span again), clamped to 0–100.
nonisolated enum CheckScoring {

    /// - Parameters:
    ///   - goodBand: the measured-value range that counts as good form.
    ///   - criticalLow/criticalHigh: where the score reaches 30 on each
    ///     side. Pass nil when that side has no fault — e.g. head
    ///     displacement has no "moved too little" fault, so its low side is
    ///     nil and values at or below the band's low edge score a full 100.
    static func score(value: Double,
                      goodBand: ClosedRange<Double>,
                      criticalLow: Double?,
                      criticalHigh: Double?) -> Double {
        let edgeScore = Constants.severityGoodFloor
        let criticalScore = Constants.severityNeedsWorkFloor
        let raw: Double

        if goodBand.contains(value) {
            // With both critical limits the best value is the band center;
            // with only one, the best value is the opposite band edge.
            let bestValue: Double
            let bestToEdgeDistance: Double
            if criticalLow == nil {
                bestValue = goodBand.lowerBound
                bestToEdgeDistance = goodBand.upperBound - goodBand.lowerBound
            } else if criticalHigh == nil {
                bestValue = goodBand.upperBound
                bestToEdgeDistance = goodBand.upperBound - goodBand.lowerBound
            } else {
                bestValue = (goodBand.lowerBound + goodBand.upperBound) / 2
                bestToEdgeDistance = (goodBand.upperBound - goodBand.lowerBound) / 2
            }
            let t = bestToEdgeDistance > 0 ? abs(value - bestValue) / bestToEdgeDistance : 0
            raw = 100 - (100 - edgeScore) * t
        } else if value < goodBand.lowerBound {
            if let criticalLow {
                raw = taperedScore(distance: goodBand.lowerBound - value,
                                   criticalDistance: goodBand.lowerBound - criticalLow,
                                   edgeScore: edgeScore,
                                   criticalScore: criticalScore)
            } else {
                raw = 100
            }
        } else {
            if let criticalHigh {
                raw = taperedScore(distance: value - goodBand.upperBound,
                                   criticalDistance: criticalHigh - goodBand.upperBound,
                                   edgeScore: edgeScore,
                                   criticalScore: criticalScore)
            } else {
                raw = 100
            }
        }

        return min(100, max(0, raw))
    }

    /// 70 → 30 between the band edge and the critical limit, then 30 → 0
    /// over the same distance again beyond the limit.
    private static func taperedScore(distance: Double,
                                     criticalDistance: Double,
                                     edgeScore: Double,
                                     criticalScore: Double) -> Double {
        guard criticalDistance > 0 else { return 0 }
        if distance <= criticalDistance {
            return edgeScore - (edgeScore - criticalScore) * (distance / criticalDistance)
        }
        return criticalScore * (1 - (distance - criticalDistance) / criticalDistance)
    }
}
