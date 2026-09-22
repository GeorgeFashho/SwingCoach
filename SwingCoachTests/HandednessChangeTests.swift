//
//  HandednessChangeTests.swift
//  SwingCoachTests
//

import SwiftData
import Testing
@testable import SwingCoach

/// Segmentation leads with the opposite wrist per handedness, so changing
/// the setting must invalidate saved phase boundaries and stored results —
/// the next open re-segments with the new lead wrist.
@MainActor
struct HandednessChangeTests {

    private static let savedTimestamps: [Double] = [0.25, 0.5, 0.75, 1.0]

    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(for: SwingSession.self, AnalysisResult.self,
                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }

    /// A right-handed session that has been segmented and analyzed.
    private func makeAnalyzedSession(in context: ModelContext) -> SwingSession {
        let session = SwingSession(cameraAngle: .faceOn,
                                   videoFileName: "swing.mov",
                                   duration: 1.0,
                                   handedness: .right)
        context.insert(session)
        session.phaseTimestamps = Self.savedTimestamps
        let tempo = CheckResult(checkName: .tempo, score: 100, measuredValue: 3.0,
                                feedback: FeedbackGenerator.tempo(ratio: 3.0))
        session.analysisResults = [AnalysisResult(result: tempo)]
        return session
    }

    @Test func changingHandednessInvalidatesSavedSegmentationAndResults() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let session = makeAnalyzedSession(in: context)

        HandednessChange.apply(.left, to: [session], in: context)

        #expect(session.hand == .left)
        #expect(session.phaseTimestamps == nil)
        #expect(session.analysisResults.isEmpty)
        let remainingRows = try context.fetch(FetchDescriptor<AnalysisResult>())
        #expect(remainingRows.isEmpty)
    }

    @Test func unchangedHandednessLeavesSessionsUntouched() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let session = makeAnalyzedSession(in: context)

        HandednessChange.apply(.right, to: [session], in: context)

        #expect(session.hand == .right)
        #expect(session.phaseTimestamps == Self.savedTimestamps)
        #expect(session.analysisResults.count == 1)
        let remainingRows = try context.fetch(FetchDescriptor<AnalysisResult>())
        #expect(remainingRows.count == 1)
    }
}
