//
//  SpineAngleCheckTests.swift
//  SwingCoachTests
//

import Testing
@testable import SwingCoach

/// Like SetupPostureCheckTests, tilt losses go through acos, so scores are
/// asserted with tolerances at values safely inside bands.
struct SpineAngleCheckTests {

    private func result(addressTilt: Double, impactTilt: Double) throws -> CheckResult {
        let frames = SwingFixtures.normalSwing(spineTiltAtAddress: addressTilt,
                                               spineTiltAtImpact: impactTilt)
        let check = SpineAngleCheck().run(frames: frames, phases: SwingFixtures.knownPhases())
        return try #require(check)
    }

    @Test func maintainedTiltScoresFull() throws {
        let spine = try result(addressTilt: 40, impactTilt: 40)
        #expect(abs(spine.score - 100) < 0.01)
        #expect(spine.severity == .good)
        #expect(spine.feedback.contains("Excellent posture maintenance"))
        #expect(abs(spine.measuredValue) < 0.01)
    }

    @Test func slightLossStillGood() throws {
        let spine = try result(addressTilt: 40, impactTilt: 37.5)
        #expect(abs(spine.score - 85) < 0.01)
        #expect(spine.severity == .good)
    }

    @Test func moderateLossNeedsWork() throws {
        let spine = try result(addressTilt: 40, impactTilt: 32)
        // Loss of 8° sits 3/7 of the way from the band edge (5°) to the
        // critical limit (12°): 70 − 40 × 3/7.
        #expect(abs(spine.score - (70 - 40 * 3 / 7)) < 0.01)
        #expect(spine.severity == .needsWork)
        #expect(spine.feedback.contains("early extension"))
    }

    @Test func severeLossIsCritical() throws {
        let spine = try result(addressTilt: 40, impactTilt: 24)
        // Loss of 16° is 4° past the critical limit: 30 × (1 − 4/7).
        #expect(abs(spine.score - (30 * 3 / 7)) < 0.01)
        #expect(spine.severity == .critical)
    }

    @Test func deepeningTheBendIsNotPenalized() throws {
        let spine = try result(addressTilt: 40, impactTilt: 45)
        #expect(abs(spine.score - 100) < 0.01)
        #expect(spine.severity == .good)
        #expect(spine.measuredValue < 0)
    }

    @Test func lowConfidenceInputReturnsNil() {
        let check = SpineAngleCheck().run(frames: SwingFixtures.lowConfidence(),
                                          phases: SwingFixtures.knownPhases())
        #expect(check == nil)
    }
}
