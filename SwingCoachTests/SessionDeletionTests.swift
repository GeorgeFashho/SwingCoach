//
//  SessionDeletionTests.swift
//  SwingCoachTests
//

import Foundation
import SwiftData
import Testing
@testable import SwingCoach

/// Deleting a session must remove everything it owns: the video file, the
/// pose JSON sidecar next to it, and the SwiftData rows (AnalysisResults
/// cascade). Phase 5 closed the gap where the sidecar leaked.
@MainActor
struct SessionDeletionTests {

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

    @Test func deleteRemovesVideoPoseSidecarAndRows() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let session = try makeSessionWithVideoFile(in: context)
        let videoURL = session.videoURL
        let poseURL = PoseDataStore.poseDataURL(forVideo: videoURL)
        try Data("[]".utf8).write(to: poseURL)
        let tempo = CheckResult(checkName: .tempo, score: 100, measuredValue: 3.0,
                                feedback: "test feedback")
        session.analysisResults = [AnalysisResult(result: tempo)]

        SessionDeletion.delete(session, in: context)
        try context.save()

        #expect(!FileManager.default.fileExists(atPath: videoURL.path))
        #expect(!FileManager.default.fileExists(atPath: poseURL.path))
        #expect(try context.fetch(FetchDescriptor<SwingSession>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<AnalysisResult>()).isEmpty)
    }

    @Test func deleteWorksWhenNoPoseSidecarExists() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let session = try makeSessionWithVideoFile(in: context)
        let videoURL = session.videoURL

        SessionDeletion.delete(session, in: context)
        try context.save()

        #expect(!FileManager.default.fileExists(atPath: videoURL.path))
        #expect(try context.fetch(FetchDescriptor<SwingSession>()).isEmpty)
    }
}
