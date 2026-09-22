//
//  ShoulderTurnCheckTests.swift
//  SwingCoachTests
//

import CoreGraphics
import Testing
@testable import SwingCoach

struct ShoulderTurnCheckTests {

    /// Runs the check on the standard fixture whose apparent shoulder width
    /// narrows to exactly `ratio` × the address width around the top.
    private func result(ratio: CGFloat) throws -> CheckResult {
        let frames = SwingFixtures.normalSwing(shoulderTurnRatio: ratio)
        let check = ShoulderTurnCheck().run(frames: frames, phases: SwingFixtures.knownPhases())
        return try #require(check)
    }

    @Test func deepTurnScoresHigh() throws {
        let turn = try result(ratio: 0.25)
        #expect(abs(turn.score - (100 - 30 * (0.25 / 0.7))) < 1e-9)
        #expect(turn.severity == .good)
        #expect(turn.feedback.contains("Great shoulder turn"))
        #expect(abs(turn.measuredValue - 0.25) < 1e-9)
    }

    @Test func goodBandEdgeScores70() throws {
        let turn = try result(ratio: 0.70)
        #expect(abs(turn.score - 70) < 1e-9)
        #expect(turn.severity == .good)
    }

    @Test func criticalLimitScores30() throws {
        let turn = try result(ratio: 0.85)
        #expect(abs(turn.score - 30) < 1e-9)
        #expect(turn.severity == .needsWork)
        #expect(turn.feedback.contains("arms"))
    }

    @Test func noTurnScoresZeroAndCritical() throws {
        let turn = try result(ratio: 1.0)
        #expect(abs(turn.score) < 1e-9)
        #expect(turn.severity == .critical)
    }

    @Test func occludedTrailShoulderAtTopReturnsNilNotAScore() {
        // The plan's required occlusion fallback: a well-turned swing whose
        // trail shoulder can't be seen at the top must NOT be scored —
        // scoring low-confidence keypoints would penalize good rotation.
        let frames = SwingFixtures.normalSwing(shoulderTurnRatio: 0.5,
                                               trailShoulderConfidenceAtTop: 0.1)
        let check = ShoulderTurnCheck().run(frames: frames, phases: SwingFixtures.knownPhases())
        #expect(check == nil)
    }

    @Test func lowConfidenceInputReturnsNil() {
        let check = ShoulderTurnCheck().run(frames: SwingFixtures.lowConfidence(),
                                            phases: SwingFixtures.knownPhases())
        #expect(check == nil)
    }
}
