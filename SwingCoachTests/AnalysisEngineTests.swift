//
//  AnalysisEngineTests.swift
//  SwingCoachTests
//

import Testing
@testable import SwingCoach

struct AnalysisEngineTests {

    private let engine = AnalysisEngine()

    @Test func faceOnRunsTheFaceOnChecks() throws {
        let outcomes = engine.analyze(frames: SwingFixtures.normalSwing(),
                                      phases: SwingFixtures.knownPhases(),
                                      cameraAngle: .faceOn)
        #expect(outcomes.map(\.checkName) == [.headStability, .hipSway, .shoulderTurn, .tempo])
        for outcome in outcomes {
            let result = try #require(outcome.result,
                                      "expected a score for \(outcome.checkName)")
            #expect(result.severity == .good)
        }
    }

    @Test func downTheLineRunsTheDownTheLineChecks() throws {
        let outcomes = engine.analyze(frames: SwingFixtures.normalSwing(),
                                      phases: SwingFixtures.knownPhases(),
                                      cameraAngle: .downTheLine)
        #expect(outcomes.map(\.checkName) == [.setupPosture, .spineAngle, .tempo])
        for outcome in outcomes {
            let result = try #require(outcome.result,
                                      "expected a score for \(outcome.checkName)")
            #expect(result.severity == .good)
        }
    }

    @Test func occludedShouldersReportInsufficientDataNotAScore() throws {
        let frames = SwingFixtures.normalSwing(trailShoulderConfidenceAtTop: 0.1)
        let outcomes = engine.analyze(frames: frames,
                                      phases: SwingFixtures.knownPhases(),
                                      cameraAngle: .faceOn)
        let shoulderTurn = try #require(outcomes.first { $0.checkName == .shoulderTurn })
        guard case .insufficientData(_, let message) = shoulderTurn else {
            Issue.record("expected an insufficientData outcome, got \(shoulderTurn)")
            return
        }
        #expect(message.contains("couldn't see your shoulders"))
        // The occlusion only affects shoulder turn — everything else scores.
        #expect(outcomes.compactMap(\.result).count == 3)
    }

    @Test func fullSwingRunsEndToEndFromSegmentationToScores() throws {
        // The whole Phase 3 pipeline on the standard fixture: segment the
        // raw frames, then run every face-on check against the DETECTED
        // (not known-true) boundaries.
        let frames = SwingFixtures.normalSwing()
        let segmentation = PhaseSegmentationService().segment(frames: frames,
                                                              cameraAngle: .faceOn,
                                                              handedness: .right)
        let phases = try #require(segmentation.phases)

        let outcomes = engine.analyze(frames: frames, phases: phases, cameraAngle: .faceOn)
        #expect(outcomes.map(\.checkName) == [.headStability, .hipSway, .shoulderTurn, .tempo])
        for outcome in outcomes {
            let result = try #require(outcome.result,
                                      "expected a score for \(outcome.checkName)")
            #expect(result.severity == .good)
        }

        // The fixture is a true 3:1 swing; detection tolerances shift the
        // measured ratio slightly but it must stay in the good band.
        let tempo = try #require(outcomes.first { $0.checkName == .tempo }?.result)
        #expect(tempo.measuredValue >= 2.5 && tempo.measuredValue <= 3.6)
    }
}
