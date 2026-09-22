//
//  SwingDataResetTests.swift
//  SwingCoachTests
//

import Foundation
import SwiftData
import Testing
@testable import SwingCoach

/// "Delete All Swings" is the factory reset: every video, pose sidecar, and
/// DB row goes (mirrors SessionDeletionTests, applied in bulk like
/// HandednessChangeTests), then the progress baseline and focus-area anchor
/// are cleared as persisted-key hygiene.
/// .serialized: deleteAllClearsProgressBaselineAndAnchor touches the same
/// process-global UserDefaults keys as ProgressBaselineTests/
/// PlaybackFocusAreaTests/ProgressViewModelTests — serialize within this
/// suite to avoid racing with its own tests. Nested under
/// PersistenceStateSuite so serialization also spans those suites (see
/// PersistenceStateSuite.swift).
extension PersistenceStateSuite {
    @Suite(.serialized)
    @MainActor
    struct SwingDataResetTests {

        private func makeContainer() throws -> ModelContainer {
            try ModelContainer(for: SwingSession.self, AnalysisResult.self,
                               configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        }

        /// A session whose video file really exists on disk, with a UUID name
        /// so parallel test runs can't collide.
        private func makeSessionWithVideoFile(in context: ModelContext) throws -> SwingSession {
            let fileName = "\(UUID().uuidString).mov"
            try FileManager.default.createDirectory(at: SwingSession.videosDirectory,
                                                    withIntermediateDirectories: true)
            let session = SwingSession(cameraAngle: .faceOn,
                                       videoFileName: fileName,
                                       duration: 1.0)
            try Data("video".utf8).write(to: session.videoURL)
            context.insert(session)
            return session
        }

        @Test func deleteAllRemovesEveryVideoPoseSidecarAndRow() throws {
            let container = try makeContainer()
            let context = container.mainContext

            let first = try makeSessionWithVideoFile(in: context)
            let firstVideoURL = first.videoURL
            let firstPoseURL = PoseDataStore.poseDataURL(forVideo: firstVideoURL)
            try Data("[]".utf8).write(to: firstPoseURL)
            first.analysisResults = [AnalysisResult(result: CheckResult(checkName: .tempo, score: 100,
                                                                         measuredValue: 3.0, feedback: "test feedback"))]

            let second = try makeSessionWithVideoFile(in: context)
            let secondVideoURL = second.videoURL
            let secondPoseURL = PoseDataStore.poseDataURL(forVideo: secondVideoURL)
            try Data("[]".utf8).write(to: secondPoseURL)
            second.analysisResults = [AnalysisResult(result: CheckResult(checkName: .tempo, score: 50,
                                                                          measuredValue: 3.0, feedback: "test feedback"))]

            let sessions = try context.fetch(FetchDescriptor<SwingSession>())
            SwingDataReset.deleteAllSwings(sessions, in: context)
            try context.save()

            #expect(!FileManager.default.fileExists(atPath: firstVideoURL.path))
            #expect(!FileManager.default.fileExists(atPath: secondVideoURL.path))
            #expect(!FileManager.default.fileExists(atPath: firstPoseURL.path))
            #expect(!FileManager.default.fileExists(atPath: secondPoseURL.path))
            #expect(try context.fetch(FetchDescriptor<SwingSession>()).isEmpty)
            #expect(try context.fetch(FetchDescriptor<AnalysisResult>()).isEmpty)
        }

        @Test func deleteAllClearsProgressBaselineAndAnchor() throws {
            let container = try makeContainer()
            let context = container.mainContext
            ProgressBaseline.date = .now
            CoachingEngine.storedPreviousFocusArea = .tempo
            defer {
                ProgressBaseline.date = nil
                CoachingEngine.storedPreviousFocusArea = nil
            }

            SwingDataReset.deleteAllSwings([], in: context)

            #expect(ProgressBaseline.date == nil)
            #expect(CoachingEngine.storedPreviousFocusArea == nil)
        }

        @Test func deleteAllOnEmptyIsNoOp() throws {
            let container = try makeContainer()
            let context = container.mainContext

            SwingDataReset.deleteAllSwings([], in: context)

            #expect(try context.fetch(FetchDescriptor<SwingSession>()).isEmpty)
            #expect(try context.fetch(FetchDescriptor<AnalysisResult>()).isEmpty)
        }
    }
}
