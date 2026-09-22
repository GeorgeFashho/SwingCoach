//
//  SetupPostureCheck.swift
//  SwingCoach
//

/// Check 1 (plan section 3): the forward tilt of the torso at address —
/// the median root→neck angle from vertical over the address frames.
/// Down-the-Line only. Returns nil when the neck or root was not detected
/// confidently enough to measure.
nonisolated struct SetupPostureCheck {

    func run(frames: [PoseFrameData], phases: SwingPhases) -> CheckResult? {
        guard let tilt = PoseFrameData.medianSpineTilt(in: frames,
                                                       during: 0...phases.addressEnd) else {
            return nil
        }
        let score = CheckScoring.score(value: tilt,
                                       goodBand: Constants.setupPostureGoodBand,
                                       criticalLow: Constants.setupPostureCriticalLow,
                                       criticalHigh: Constants.setupPostureCriticalHigh)
        return CheckResult(checkName: .setupPosture,
                           score: score,
                           measuredValue: tilt,
                           feedback: FeedbackGenerator.setupPosture(score: score, tilt: tilt))
    }
}
