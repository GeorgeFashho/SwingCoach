//
//  PlaybackFocusAreaTests.swift
//  SwingCoachTests
//

import Foundation
import SwiftData
import Testing
@testable import SwingCoach

/// PlaybackViewModel.refreshFocusArea shares the SAME baseline filter as
/// ProgressViewModel.reload (Option B, unifying the two): after a Reset,
/// reviewing an old swing must not re-seed the focus area or its
/// cross-launch anchor from pre-baseline data.
/// .serialized: shares the same process-global UserDefaults keys as
/// ProgressBaselineTests/SwingDataResetTests/ProgressViewModelTests. Nested
/// under PersistenceStateSuite so serialization also spans those suites
/// (see PersistenceStateSuite.swift).
extension PersistenceStateSuite {
    @Suite(.serialized)
    @MainActor
    struct PlaybackFocusAreaTests {

        private func makeContainer() throws -> ModelContainer {
            try ModelContainer(for: SwingSession.self, AnalysisResult.self,
                               configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        }

        private func makeSession(date: Date, in context: ModelContext) -> SwingSession {
            let session = SwingSession(cameraAngle: .faceOn,
                                       videoFileName: "\(UUID().uuidString).mov",
                                       duration: 1.0)
            session.date = date
            context.insert(session)
            return session
        }

        private func addResult(_ check: CheckName, score: Double, to session: SwingSession) {
            let result = CheckResult(checkName: check, score: score, measuredValue: 3.0,
                                     feedback: "test feedback")
            session.analysisResults.append(AnalysisResult(result: result))
        }

        @Test func refreshFocusAreaExcludesPreBaselineSwings() throws {
            let container = try makeContainer()
            let context = container.mainContext
            ProgressBaseline.date = .now
            CoachingEngine.storedPreviousFocusArea = nil
            defer {
                ProgressBaseline.date = nil
                CoachingEngine.storedPreviousFocusArea = nil
            }

            // Three pre-baseline sessions with the same check qualify for a
            // focus area if NOT filtered (>= focusAreaMinDataPoints) — proving
            // this is a real exclusion, not just insufficient data.
            var sessions: [SwingSession] = []
            for offset in 0..<3 {
                let session = makeSession(date: Date(timeIntervalSinceReferenceDate: 1_000 + Double(offset)),
                                          in: context)
                addResult(.tempo, score: 90, to: session)
                sessions.append(session)
            }

            let playbackViewModel = PlaybackViewModel(session: try #require(sessions.first))
            playbackViewModel.refreshFocusArea()

            #expect(playbackViewModel.focusArea == nil)
            #expect(CoachingEngine.storedPreviousFocusArea == nil)
        }
    }
}
