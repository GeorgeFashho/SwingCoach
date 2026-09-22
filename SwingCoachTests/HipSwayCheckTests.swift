//
//  HipSwayCheckTests.swift
//  SwingCoachTests
//

import CoreGraphics
import Testing
@testable import SwingCoach

struct HipSwayCheckTests {

    /// Runs the check on the standard fixture with an exact hip-midpoint
    /// sway (in stance-widths) against the fixture's known-true phases.
    private func result(sway: CGFloat) throws -> CheckResult {
        let frames = SwingFixtures.normalSwing(hipSwayInStanceWidths: sway)
        let check = HipSwayCheck().run(frames: frames, phases: SwingFixtures.knownPhases())
        return try #require(check)
    }

    @Test func rotatingInPlaceScoresFull() throws {
        let hips = try result(sway: 0)
        #expect(abs(hips.score - 100) < 1e-9)
        #expect(hips.severity == .good)
        #expect(hips.feedback.contains("Nice hip action"))
    }

    @Test func smallShiftStillGood() throws {
        let hips = try result(sway: 0.05)
        #expect(abs(hips.score - 85) < 1e-9)
        #expect(hips.severity == .good)
        #expect(abs(hips.measuredValue - 0.05) < 1e-9)
    }

    @Test func goodBandEdgeScores70() throws {
        let hips = try result(sway: 0.10)
        #expect(abs(hips.score - 70) < 1e-9)
        #expect(hips.severity == .good)
    }

    @Test func moderateSwayNeedsWork() throws {
        let hips = try result(sway: 0.15)
        #expect(abs(hips.score - 50) < 1e-9)
        #expect(hips.severity == .needsWork)
        #expect(hips.feedback.contains("sliding sideways"))
    }

    @Test func criticalLimitScores30() throws {
        let hips = try result(sway: 0.20)
        #expect(abs(hips.score - 30) < 1e-9)
        #expect(hips.severity == .needsWork)
    }

    @Test func severeSwayScoresZeroAndCritical() throws {
        let hips = try result(sway: 0.30)
        #expect(abs(hips.score) < 1e-9)
        #expect(hips.severity == .critical)
    }

    @Test func lowConfidenceInputReturnsNil() {
        let check = HipSwayCheck().run(frames: SwingFixtures.lowConfidence(),
                                       phases: SwingFixtures.knownPhases())
        #expect(check == nil)
    }
}
