//
//  SkippedCheckTests.swift
//  SwingCoachTests
//

import Testing
@testable import SwingCoach

/// The analysis view must explain every gap: checks the camera angle can't
/// measure name the angle they need, and the applicability metadata can
/// never drift from the check matrix AnalysisEngine actually runs.
struct SkippedCheckTests {

    private func inapplicableChecks(for angle: CameraAngle) -> Set<CheckName> {
        Set(CheckName.allCases.filter { !$0.isApplicable(to: angle) })
    }

    @Test func faceOnSkipsTheDownTheLineChecksAndNamesTheAngle() {
        let skipped = inapplicableChecks(for: .faceOn)
        #expect(skipped == [.setupPosture, .spineAngle])
        for check in skipped {
            let message = FeedbackGenerator.skippedMessage(for: check)
            #expect(message?.contains("Down-the-Line") == true)
        }
    }

    @Test func downTheLineSkipsTheFaceOnChecksAndNamesTheAngle() {
        let skipped = inapplicableChecks(for: .downTheLine)
        #expect(skipped == [.headStability, .hipSway, .shoulderTurn])
        for check in skipped {
            let message = FeedbackGenerator.skippedMessage(for: check)
            #expect(message?.contains("Face-On") == true)
        }
    }

    @Test func tempoAppliesToBothAnglesAndIsNeverSkipped() {
        #expect(CheckName.tempo.isApplicable(to: .faceOn))
        #expect(CheckName.tempo.isApplicable(to: .downTheLine))
        #expect(FeedbackGenerator.skippedMessage(for: .tempo) == nil)
    }

    /// AnalysisEngine returns one outcome per applicable check even with no
    /// pose data (insufficientData rather than absence), so the set of
    /// outcome names is exactly the engine's per-angle matrix.
    @Test(arguments: CameraAngle.allCases)
    func applicabilityMatchesTheEngineMatrix(angle: CameraAngle) {
        let phases = SwingPhases(addressEnd: 0.25, top: 0.5, impact: 0.75, followThroughEnd: 1.0)
        let outcomes = AnalysisEngine().analyze(frames: [], phases: phases, cameraAngle: angle)
        let engineChecks = Set(outcomes.map(\.checkName))
        let derived = Set(CheckName.allCases.filter { $0.isApplicable(to: angle) })
        #expect(engineChecks == derived)
    }
}
