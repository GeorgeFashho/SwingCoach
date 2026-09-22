//
//  HipSwayCheck.swift
//  SwingCoach
//

import CoreGraphics
import Foundation

/// Check 3 (plan section 3): whether the hips slide sideways during the
/// backswing instead of rotating in place — the lateral shift of the hip
/// midpoint from address to the top, in stance-widths (ankle distance).
/// Face-On only. Returns nil when hips or ankles were not detected
/// confidently enough to measure.
nonisolated struct HipSwayCheck {

    func run(frames: [PoseFrameData], phases: SwingPhases) -> CheckResult? {
        let window = Constants.checkBoundarySampleWindowWide
        guard let stanceWidth = PoseFrameData.medianJointDistance(
                  in: frames,
                  between: .leftAnkle, and: .rightAnkle,
                  during: 0...phases.addressEnd,
                  minSamples: Constants.minCheckSamples),
              let addressMidX = medianHipMidpointX(in: frames, during: 0...phases.addressEnd),
              let topMidX = medianHipMidpointX(
                  in: frames,
                  during: (phases.top - window)...(phases.top + window)) else {
            return nil
        }
        let sway = Double(abs(topMidX - addressMidX) / stanceWidth)
        let score = CheckScoring.score(value: sway,
                                       goodBand: Constants.hipSwayGoodBand,
                                       criticalLow: nil,
                                       criticalHigh: Constants.hipSwayCriticalLimit)
        return CheckResult(checkName: .hipSway,
                           score: score,
                           measuredValue: sway,
                           feedback: FeedbackGenerator.hipSway(score: score))
    }

    private func medianHipMidpointX(in frames: [PoseFrameData],
                                    during range: ClosedRange<TimeInterval>) -> CGFloat? {
        var midpoints: [CGFloat] = []
        for frame in frames where range.contains(frame.timestamp) {
            guard let left = frame.joint(.leftHip),
                  let right = frame.joint(.rightHip),
                  left.confidence >= Constants.minimumJointConfidence,
                  right.confidence >= Constants.minimumJointConfidence else { continue }
            midpoints.append((left.x + right.x) / 2)
        }
        guard midpoints.count >= Constants.minCheckSamples else { return nil }
        return midpoints.sorted()[midpoints.count / 2]
    }
}
