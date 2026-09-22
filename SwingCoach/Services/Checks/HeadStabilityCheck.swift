//
//  HeadStabilityCheck.swift
//  SwingCoach
//

import CoreGraphics
import Foundation

/// Check 2 (plan section 3): how far the nose drifts from its address
/// position during the swing, measured in shoulder-widths. Face-On only.
/// Returns nil when the nose or shoulders were not detected confidently
/// enough to measure — never a made-up score.
nonisolated struct HeadStabilityCheck {

    func run(frames: [PoseFrameData], phases: SwingPhases) -> CheckResult? {
        guard let (displacement, shoulderWidth) = Self.displacement(in: frames, phases: phases) else {
            return nil
        }
        let measured = Double(hypot(displacement.dx, displacement.dy) / shoulderWidth)
        let score = CheckScoring.score(value: measured,
                                       goodBand: Constants.headStabilityGoodBand,
                                       criticalLow: nil,
                                       criticalHigh: Constants.headStabilityCriticalLimit)
        return CheckResult(checkName: .headStability,
                           score: score,
                           measuredValue: measured,
                           feedback: FeedbackGenerator.headStability(score: score,
                                                                     displacement: displacement))
    }

    /// The nose's largest drift from its address reference during the swing,
    /// as a vector in normalized image coords, plus the shoulder width used to
    /// normalize it (measured / shoulderWidth). Shared by `run` (for the score
    /// and feedback direction) and the coaching card (for the head drill's
    /// lateral-vs-vertical branch). nil when there aren't enough confident
    /// nose samples at address or during the swing — the same honest gap
    /// `run` returns as insufficientData.
    static func displacement(in frames: [PoseFrameData],
                             phases: SwingPhases) -> (vector: CGVector, shoulderWidth: CGFloat)? {
        let minimumConfidence = Constants.minimumJointConfidence

        // Reference: the median confident nose position at address (median,
        // not mean, so junk early in the clip — now legitimately inside a
        // long address window — can't skew it), and the median shoulder
        // width for scale normalization.
        var addressNosePoints: [CGPoint] = []
        for frame in frames where frame.timestamp <= phases.addressEnd {
            if let nose = frame.joint(.nose), nose.confidence >= minimumConfidence {
                addressNosePoints.append(nose.location)
            }
        }
        guard addressNosePoints.count >= Constants.minHeadStabilitySamples,
              let shoulderWidth = PoseFrameData.medianJointDistance(
                  in: frames,
                  between: .leftShoulder, and: .rightShoulder,
                  during: 0...phases.addressEnd) else { return nil }
        let addressNose = CGPoint(
            x: addressNosePoints.map(\.x).sorted()[addressNosePoints.count / 2],
            y: addressNosePoints.map(\.y).sorted()[addressNosePoints.count / 2])

        // Largest drift from that reference during the swing itself.
        var maxDisplacement: CGFloat = 0
        var displacementAtMax = CGVector.zero
        var swingSampleCount = 0
        for frame in frames
        where frame.timestamp > phases.addressEnd && frame.timestamp <= phases.followThroughEnd {
            guard let nose = frame.joint(.nose), nose.confidence >= minimumConfidence else { continue }
            swingSampleCount += 1
            let dx = nose.x - addressNose.x
            let dy = nose.y - addressNose.y
            let displacement = hypot(dx, dy)
            if displacement > maxDisplacement {
                maxDisplacement = displacement
                displacementAtMax = CGVector(dx: dx, dy: dy)
            }
        }
        guard swingSampleCount >= Constants.minHeadStabilitySamples else { return nil }

        return (displacementAtMax, shoulderWidth)
    }
}
