//
//  SpineAngleCheck.swift
//  SwingCoach
//

/// Check 4 (plan section 3): spine angle maintenance — the median address
/// tilt minus the median tilt around impact. Positive = the golfer stood up
/// through the ball (early extension). Down-the-Line only. One-sided band:
/// keeping (or deepening) the bend scores 100. Returns nil when either
/// window lacks confident neck/root samples.
nonisolated struct SpineAngleCheck {

    func run(frames: [PoseFrameData], phases: SwingPhases) -> CheckResult? {
        let window = Constants.checkBoundarySampleWindowWide
        guard let addressTilt = PoseFrameData.medianSpineTilt(in: frames,
                                                              during: 0...phases.addressEnd),
              let impactTilt = PoseFrameData.medianSpineTilt(
                  in: frames,
                  during: (phases.impact - window)...(phases.impact + window)) else {
            return nil
        }
        let loss = addressTilt - impactTilt
        let score = CheckScoring.score(value: loss,
                                       goodBand: Constants.spineAngleLossGoodBand,
                                       criticalLow: nil,
                                       criticalHigh: Constants.spineAngleLossCriticalLimit)
        return CheckResult(checkName: .spineAngle,
                           score: score,
                           measuredValue: loss,
                           feedback: FeedbackGenerator.spineAngle(score: score))
    }
}
