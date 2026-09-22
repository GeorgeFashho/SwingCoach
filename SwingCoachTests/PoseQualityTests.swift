//
//  PoseQualityTests.swift
//  SwingCoachTests
//

import CoreGraphics
import Testing
@testable import SwingCoach

/// The low-pose-quality warning fires only when the average joint
/// confidence is strictly below the Constants threshold. All fixture
/// confidences are dyadic (0.25, 0.5, 0.75) so the averages are exact and
/// the band-edge assertion can't wobble by a ULP (Phase 3a lesson).
struct PoseQualityTests {

    private func frame(confidences: [Float]) -> PoseFrameData {
        var joints: [String: JointPoint] = [:]
        for (index, confidence) in confidences.enumerated() {
            joints["joint\(index)"] = JointPoint(x: 0, y: 0, confidence: confidence)
        }
        return PoseFrameData(frameIndex: 0, timestamp: 0, joints: joints)
    }

    @Test func averageExactlyAtThresholdIsNotLow() {
        // All joints at the 0.5 threshold: average is exactly 0.5, and
        // "strictly below" means the warning must NOT fire.
        let uniform = [frame(confidences: [0.5, 0.5]), frame(confidences: [0.5, 0.5])]
        #expect(PoseQuality.averageJointConfidence(of: uniform) == 0.5)
        #expect(!PoseQuality.isLow(uniform))

        // Mixed dyadic confidences averaging exactly to the threshold.
        let mixed = [frame(confidences: [0.25, 0.75]), frame(confidences: [0.75, 0.25])]
        #expect(PoseQuality.averageJointConfidence(of: mixed) == 0.5)
        #expect(!PoseQuality.isLow(mixed))
    }

    @Test func averageBelowThresholdIsLow() {
        let frames = [frame(confidences: [0.25, 0.25]), frame(confidences: [0.25, 0.25])]
        #expect(PoseQuality.averageJointConfidence(of: frames) == 0.25)
        #expect(PoseQuality.isLow(frames))
    }

    @Test func averageAboveThresholdIsNotLow() {
        let frames = [frame(confidences: [0.75, 0.75])]
        #expect(PoseQuality.averageJointConfidence(of: frames) == 0.75)
        #expect(!PoseQuality.isLow(frames))
    }

    @Test func noJointsMeansNilAverageAndNoWarning() {
        #expect(PoseQuality.averageJointConfidence(of: []) == nil)
        #expect(!PoseQuality.isLow([]))

        let jointless = [frame(confidences: [])]
        #expect(PoseQuality.averageJointConfidence(of: jointless) == nil)
        #expect(!PoseQuality.isLow(jointless))
    }
}
