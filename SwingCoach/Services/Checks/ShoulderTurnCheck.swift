//
//  ShoulderTurnCheck.swift
//  SwingCoach
//

import CoreGraphics

/// Check 5 (plan section 3): how much the shoulders coil in the backswing.
/// In the face-on view rotation shows up as the apparent shoulder width
/// shrinking, so measure width-at-the-top ÷ width-at-address (lower =
/// more turn). Face-On only.
///
/// Occlusion fallback (required by the plan): at full rotation the trail
/// shoulder is often hidden and its confidence drops. Without enough
/// confident both-shoulder frames around the top this returns nil —
/// scoring low-confidence keypoints would penalize good rotation.
nonisolated struct ShoulderTurnCheck {

    func run(frames: [PoseFrameData], phases: SwingPhases) -> CheckResult? {
        let window = Constants.checkBoundarySampleWindow
        guard let addressWidth = PoseFrameData.medianJointDistance(
                  in: frames,
                  between: .leftShoulder, and: .rightShoulder,
                  during: 0...phases.addressEnd,
                  minSamples: Constants.minCheckSamples),
              let topWidth = PoseFrameData.medianJointDistance(
                  in: frames,
                  between: .leftShoulder, and: .rightShoulder,
                  during: (phases.top - window)...(phases.top + window),
                  minSamples: Constants.minCheckSamples) else {
            return nil
        }
        let ratio = Double(topWidth / addressWidth)
        let score = CheckScoring.score(value: ratio,
                                       goodBand: Constants.shoulderTurnGoodBand,
                                       criticalLow: nil,
                                       criticalHigh: Constants.shoulderTurnCriticalLimit)
        return CheckResult(checkName: .shoulderTurn,
                           score: score,
                           measuredValue: ratio,
                           feedback: FeedbackGenerator.shoulderTurn(score: score))
    }
}
