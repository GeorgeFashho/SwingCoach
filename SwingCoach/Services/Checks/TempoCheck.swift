//
//  TempoCheck.swift
//  SwingCoach
//

/// Check 6 (plan section 3): the backswing-to-downswing time ratio. Works
/// from either camera angle because it only needs the phase timestamps.
nonisolated struct TempoCheck {

    func run(phases: SwingPhases) -> CheckResult? {
        guard phases.backswingDuration > 0, phases.downswingDuration > 0 else { return nil }
        let ratio = phases.backswingDuration / phases.downswingDuration
        let score = CheckScoring.score(value: ratio,
                                       goodBand: Constants.tempoGoodBand,
                                       criticalLow: Constants.tempoCriticalLow,
                                       criticalHigh: Constants.tempoCriticalHigh)
        return CheckResult(checkName: .tempo,
                           score: score,
                           measuredValue: ratio,
                           feedback: FeedbackGenerator.tempo(ratio: ratio))
    }
}
