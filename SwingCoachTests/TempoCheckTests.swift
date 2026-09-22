//
//  TempoCheckTests.swift
//  SwingCoachTests
//

import Testing
@testable import SwingCoach

struct TempoCheckTests {

    /// Builds phases with a fixed 0.25s downswing (a power of two, so
    /// ratio × downswing ÷ downswing round-trips exactly and boundary
    /// ratios like 2.0 don't land a rounding error past the critical
    /// limit) and a backswing chosen to hit the requested ratio exactly.
    private func result(forRatio ratio: Double) throws -> CheckResult {
        let downswing = 0.25
        let top = ratio * downswing
        let phases = SwingPhases(addressEnd: 0,
                                 top: top,
                                 impact: top + downswing,
                                 followThroughEnd: top + downswing + 0.5)
        return try #require(TempoCheck().run(phases: phases))
    }

    @Test func idealRatioScoresFull() throws {
        let tempo = try result(forRatio: 3.0)
        #expect(abs(tempo.score - 100) < 1e-9)
        #expect(tempo.severity == .good)
        #expect(tempo.feedback.contains("Nice tempo"))
        #expect(abs(tempo.measuredValue - 3.0) < 1e-9)
    }

    @Test func goodBandEdgesScore70() throws {
        let fast = try result(forRatio: 2.5)
        let slow = try result(forRatio: 3.5)
        #expect(abs(fast.score - 70) < 1e-9)
        #expect(abs(slow.score - 70) < 1e-9)
        #expect(fast.severity == .good)
        #expect(slow.severity == .good)
    }

    @Test func rushedTempoNeedsWork() throws {
        let tempo = try result(forRatio: 2.25)
        #expect(abs(tempo.score - 50) < 1e-9)
        #expect(tempo.severity == .needsWork)
        #expect(tempo.feedback.contains("rushing"))
    }

    @Test func criticalLimitScores30() throws {
        let tempo = try result(forRatio: 2.0)
        #expect(abs(tempo.score - 30) < 1e-9)
        #expect(tempo.severity == .needsWork)
    }

    @Test func severeRushScoresZeroAndCritical() throws {
        let tempo = try result(forRatio: 1.5)
        #expect(abs(tempo.score) < 1e-9)
        #expect(tempo.severity == .critical)
        #expect(tempo.feedback.contains("rushing"))
    }

    @Test func slowTempoReadsAsDeceleration() throws {
        let tempo = try result(forRatio: 4.0)
        #expect(abs(tempo.score - 50) < 1e-9)
        #expect(tempo.severity == .needsWork)
        #expect(tempo.feedback.contains("decelerating"))

        let extreme = try result(forRatio: 5.5)
        #expect(abs(extreme.score) < 1e-9)
        #expect(extreme.severity == .critical)
    }

    @Test func zeroDurationPhasesReturnNil() {
        let phases = SwingPhases(addressEnd: 0, top: 1, impact: 1, followThroughEnd: 2)
        #expect(TempoCheck().run(phases: phases) == nil)
    }
}
