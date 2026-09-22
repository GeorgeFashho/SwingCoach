//
//  SetupPostureCheckTests.swift
//  SwingCoachTests
//

import Testing
@testable import SwingCoach

/// The spine tilt travels through acos, which is never bit-exact, so these
/// assert with tolerances at values safely inside score bands — never at a
/// band edge where an ULP could flip the severity (Phase 3a lesson).
struct SetupPostureCheckTests {

    private func result(tilt: Double) throws -> CheckResult {
        let frames = SwingFixtures.normalSwing(spineTiltAtAddress: tilt)
        let check = SetupPostureCheck().run(frames: frames, phases: SwingFixtures.knownPhases())
        return try #require(check)
    }

    @Test func bandCenterTiltScoresFull() throws {
        let posture = try result(tilt: 37.5)
        #expect(abs(posture.score - 100) < 0.01)
        #expect(posture.severity == .good)
        #expect(posture.feedback.contains("athletic bend"))
        #expect(abs(posture.measuredValue - 37.5) < 0.01)
    }

    @Test func tooUprightNeedsWork() throws {
        let posture = try result(tilt: 25)
        #expect(abs(posture.score - 50) < 0.01)
        #expect(posture.severity == .needsWork)
        #expect(posture.feedback.contains("standing too tall"))
    }

    @Test func tooHunchedNeedsWork() throws {
        let posture = try result(tilt: 50)
        #expect(abs(posture.score - 50) < 0.01)
        #expect(posture.severity == .needsWork)
        #expect(posture.feedback.contains("bending over too much"))
    }

    @Test func severelyUprightIsCritical() throws {
        let posture = try result(tilt: 15)
        #expect(abs(posture.score - 15) < 0.01)
        #expect(posture.severity == .critical)
    }

    @Test func severelyHunchedIsCritical() throws {
        let posture = try result(tilt: 60)
        #expect(abs(posture.score - 15) < 0.01)
        #expect(posture.severity == .critical)
    }

    @Test func lowConfidenceInputReturnsNil() {
        let check = SetupPostureCheck().run(frames: SwingFixtures.lowConfidence(),
                                            phases: SwingFixtures.knownPhases())
        #expect(check == nil)
    }
}
