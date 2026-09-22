//
//  HeadStabilityCheckTests.swift
//  SwingCoachTests
//

import CoreGraphics
import Testing
@testable import SwingCoach

struct HeadStabilityCheckTests {

    /// Runs the check on the standard fixture with an exact nose drift
    /// (in shoulder-widths) against the fixture's known-true phases.
    private func result(drift: CGFloat, vertical: Bool = false) throws -> CheckResult {
        let frames = SwingFixtures.normalSwing(noseDriftInShoulderWidths: drift,
                                               noseDriftIsVertical: vertical)
        let check = HeadStabilityCheck().run(frames: frames, phases: SwingFixtures.knownPhases())
        return try #require(check)
    }

    @Test func perfectlyStillHeadScoresFull() throws {
        let head = try result(drift: 0)
        #expect(abs(head.score - 100) < 1e-6)
        #expect(head.severity == .good)
        #expect(head.feedback.contains("Great head stability"))
    }

    @Test func smallDriftStillGood() throws {
        let head = try result(drift: 0.075)
        #expect(abs(head.score - 85) < 1e-6)
        #expect(head.severity == .good)
        #expect(abs(head.measuredValue - 0.075) < 1e-6)
    }

    @Test func goodBandEdgeScores70() throws {
        let head = try result(drift: 0.15)
        #expect(abs(head.score - 70) < 1e-6)
        #expect(head.severity == .good)
    }

    @Test func lateralSwayNeedsWork() throws {
        let head = try result(drift: 0.225)
        #expect(abs(head.score - 50) < 1e-6)
        #expect(head.severity == .needsWork)
        #expect(head.feedback.contains("sideways"))
    }

    @Test func verticalDriftGetsHeightFeedback() throws {
        let head = try result(drift: 0.225, vertical: true)
        #expect(head.severity == .needsWork)
        #expect(head.feedback.contains("height"))
    }

    @Test func criticalLimitScores30() throws {
        let head = try result(drift: 0.30)
        #expect(abs(head.score - 30) < 1e-6)
        #expect(head.severity == .needsWork)
    }

    @Test func severeSwayScoresZeroAndCritical() throws {
        let head = try result(drift: 0.45)
        #expect(abs(head.score) < 1e-6)
        #expect(head.severity == .critical)
    }

    @Test func lowConfidenceNoseReturnsNil() {
        let frames = SwingFixtures.normalSwing(noseConfidence: 0.1)
        let check = HeadStabilityCheck().run(frames: frames, phases: SwingFixtures.knownPhases())
        #expect(check == nil)
    }
}
