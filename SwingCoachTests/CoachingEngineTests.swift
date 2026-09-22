//
//  CoachingEngineTests.swift
//  SwingCoachTests
//

import CoreGraphics
import Foundation
import Testing
@testable import SwingCoach

/// Stage 1 coaching logic: worst-check selection (with tie-break and the
/// selection-≠-severity rule), the all-good signal, and the drill copy's
/// fault-direction branching. Pure — no ModelContainer, no views.
struct CoachingEngineTests {
    private let engine = CoachingEngine()

    private func scored(_ name: CheckName, _ score: Double) -> CheckOutcome {
        .scored(CheckResult(checkName: name, score: score, measuredValue: 0, feedback: ""))
    }

    private func insufficient(_ name: CheckName) -> CheckOutcome {
        .insufficientData(name, message: "")
    }

    // (i) Returns the lowest-scoring check.
    @Test func worstCheckReturnsLowestScore() {
        let outcomes = [scored(.tempo, 80), scored(.headStability, 40), scored(.hipSway, 60)]
        #expect(engine.worstCheck(from: outcomes)?.checkName == .headStability)
    }

    // (ii) Ties break by CheckName.allCases order (lower index wins).
    @Test func worstCheckTieBreaksByAllCasesOrder() {
        // setupPosture (index 0) and tempo (index 5) both score 50.
        let outcomes = [scored(.tempo, 50), scored(.setupPosture, 50)]
        #expect(engine.worstCheck(from: outcomes)?.checkName == .setupPosture)
    }

    // (iii) nil for empty outcomes.
    @Test func worstCheckNilForEmpty() {
        #expect(engine.worstCheck(from: []) == nil)
    }

    // (iv) nil when only insufficientData outcomes exist.
    @Test func worstCheckNilForAllInsufficient() {
        let outcomes = [insufficient(.hipSway), insufficient(.shoulderTurn)]
        #expect(engine.worstCheck(from: outcomes) == nil)
    }

    // (v) Returns the lowest-scoring check EVEN when all scores are good.
    @Test func worstCheckReturnsLowestEvenWhenAllGood() {
        let outcomes = [scored(.tempo, 90), scored(.setupPosture, 80), scored(.spineAngle, 100)]
        #expect(engine.worstCheck(from: outcomes)?.checkName == .setupPosture)
    }

    // (vi) allChecksGood true when every scored check is at/above the floor.
    @Test func allChecksGoodTrueWhenAllAtOrAboveFloor() {
        let outcomes = [scored(.tempo, 70), scored(.setupPosture, 85), scored(.spineAngle, 100)]
        #expect(engine.allChecksGood(from: outcomes))
    }

    // (vii) allChecksGood false when any scored check is below the floor.
    @Test func allChecksGoodFalseWhenAnyBelowFloor() {
        let outcomes = [scored(.tempo, 70), scored(.setupPosture, 69)]
        #expect(!engine.allChecksGood(from: outcomes))
    }

    // (viii) allChecksGood false when no check scored.
    @Test func allChecksGoodFalseWhenNoScored() {
        #expect(!engine.allChecksGood(from: []))
        #expect(!engine.allChecksGood(from: [insufficient(.tempo)]))
    }

    // (ix) Drill returns non-empty copy for every check.
    @Test func drillNonEmptyForEachCheck() {
        for check in CheckName.allCases {
            let text = FeedbackGenerator.drill(for: check, measuredValue: 0, headDisplacement: .zero)
            #expect(!text.isEmpty)
        }
    }

    // (x) setupPosture drill branches on tilt direction.
    @Test func setupPostureDrillBranchesOnTilt() {
        let tooUpright = FeedbackGenerator.drill(for: .setupPosture, measuredValue: 20) // below lowerBound
        let tooBent = FeedbackGenerator.drill(for: .setupPosture, measuredValue: 50)    // above upperBound
        #expect(tooUpright != tooBent)
    }

    // (xi) headStability drill branches on displacement direction.
    @Test func headStabilityDrillBranchesOnDirection() {
        let lateral = FeedbackGenerator.drill(for: .headStability, measuredValue: 0.5,
                                              headDisplacement: CGVector(dx: 1, dy: 0))
        let vertical = FeedbackGenerator.drill(for: .headStability, measuredValue: 0.5,
                                               headDisplacement: CGVector(dx: 0, dy: 1))
        #expect(lateral != vertical)
    }

    // MARK: - Focus area (Stage 2) — pure function, no ModelContainer

    private func sample(_ check: CheckName, _ score: Double, day: Double,
                        session: UUID = UUID()) -> CoachingEngine.CheckSample {
        CoachingEngine.CheckSample(checkName: check, score: score, measuredValue: 0,
                                   sessionID: session, date: Date(timeIntervalSince1970: day * 86_400))
    }

    private func allIDs(_ samples: [CoachingEngine.CheckSample]) -> Set<UUID> {
        Set(samples.map(\.sessionID))
    }

    // (i) Returns the lowest-mean-score check.
    @Test func focusAreaReturnsLowestMean() {
        let samples = [
            sample(.setupPosture, 80, day: 1), sample(.setupPosture, 80, day: 2), sample(.setupPosture, 80, day: 3),
            sample(.tempo, 40, day: 1), sample(.tempo, 40, day: 2), sample(.tempo, 40, day: 3),
        ]
        let result = CoachingEngine.focusArea(from: samples, recentSessionIDs: allIDs(samples), previousFocusArea: nil)
        #expect(result?.checkName == .tempo)
        #expect(result?.meanScore == 40)
    }

    // (ii) Checks with fewer than minDataPoints are excluded.
    @Test func focusAreaExcludesSparseChecks() {
        let samples = [
            sample(.setupPosture, 10, day: 1), sample(.setupPosture, 10, day: 2), // only 2 → excluded
            sample(.tempo, 50, day: 1), sample(.tempo, 50, day: 2), sample(.tempo, 50, day: 3),
        ]
        let result = CoachingEngine.focusArea(from: samples, recentSessionIDs: allIDs(samples), previousFocusArea: nil)
        #expect(result?.checkName == .tempo)
    }

    // (iii) nil when no check qualifies.
    @Test func focusAreaNilWhenNoneQualify() {
        let samples = [
            sample(.setupPosture, 10, day: 1), sample(.setupPosture, 10, day: 2),
            sample(.tempo, 50, day: 1),
        ]
        let result = CoachingEngine.focusArea(from: samples, recentSessionIDs: allIDs(samples), previousFocusArea: nil)
        #expect(result == nil)
    }

    // (iv) Trend improving when the newer half's mean beats the older half's by > threshold.
    @Test func focusAreaTrendImproving() {
        let samples = [
            sample(.tempo, 40, day: 1), sample(.tempo, 40, day: 2),
            sample(.tempo, 80, day: 3), sample(.tempo, 80, day: 4),
        ]
        let result = CoachingEngine.focusArea(from: samples, recentSessionIDs: allIDs(samples), previousFocusArea: nil)
        #expect(result?.trend == .improving)
    }

    // (v) Trend declining when the newer half's mean is worse by > threshold.
    @Test func focusAreaTrendDeclining() {
        let samples = [
            sample(.tempo, 80, day: 1), sample(.tempo, 80, day: 2),
            sample(.tempo, 40, day: 3), sample(.tempo, 40, day: 4),
        ]
        let result = CoachingEngine.focusArea(from: samples, recentSessionIDs: allIDs(samples), previousFocusArea: nil)
        #expect(result?.trend == .declining)
    }

    // (vi) Ties break by CheckName.allCases order.
    @Test func focusAreaTieBreaksByAllCasesOrder() {
        let samples = [
            sample(.setupPosture, 50, day: 1), sample(.setupPosture, 50, day: 2), sample(.setupPosture, 50, day: 3),
            sample(.tempo, 50, day: 1), sample(.tempo, 50, day: 2), sample(.tempo, 50, day: 3),
        ]
        let result = CoachingEngine.focusArea(from: samples, recentSessionIDs: allIDs(samples), previousFocusArea: nil)
        #expect(result?.checkName == .setupPosture)
    }

    // (vii) Hysteresis: previous kept when another check is within threshold; replaced when more than threshold worse.
    @Test func focusAreaHysteresis() {
        // Kept: previous tempo (mean 50) vs setupPosture (mean 48) — only 2 worse → keep tempo.
        let keep = [
            sample(.tempo, 50, day: 1), sample(.tempo, 50, day: 2), sample(.tempo, 50, day: 3),
            sample(.setupPosture, 48, day: 1), sample(.setupPosture, 48, day: 2), sample(.setupPosture, 48, day: 3),
        ]
        #expect(CoachingEngine.focusArea(from: keep, recentSessionIDs: allIDs(keep), previousFocusArea: .tempo)?.checkName == .tempo)

        // Replaced: previous tempo (mean 60) vs setupPosture (mean 50) — 10 worse → switch.
        let replace = [
            sample(.tempo, 60, day: 1), sample(.tempo, 60, day: 2), sample(.tempo, 60, day: 3),
            sample(.setupPosture, 50, day: 1), sample(.setupPosture, 50, day: 2), sample(.setupPosture, 50, day: 3),
        ]
        #expect(CoachingEngine.focusArea(from: replace, recentSessionIDs: allIDs(replace), previousFocusArea: .tempo)?.checkName == .setupPosture)
    }

    // (viii) An unqualified previous focus area is ignored — plain lowest mean wins.
    @Test func focusAreaIgnoresUnqualifiedPrevious() {
        let samples = [
            sample(.tempo, 40, day: 1), sample(.tempo, 40, day: 2), sample(.tempo, 40, day: 3),
            sample(.setupPosture, 80, day: 1), sample(.setupPosture, 80, day: 2), sample(.setupPosture, 80, day: 3),
            sample(.hipSway, 10, day: 1), // previous, but only 1 point → not qualified
        ]
        let result = CoachingEngine.focusArea(from: samples, recentSessionIDs: allIDs(samples), previousFocusArea: .hipSway)
        #expect(result?.checkName == .tempo)
    }
}
