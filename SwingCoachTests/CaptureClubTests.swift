//
//  CaptureClubTests.swift
//  SwingCoachTests
//

import Foundation
import SwiftData
import Testing
@testable import SwingCoach

/// Exercises CaptureViewModel.finishRecording directly with a synthetic
/// Result, bypassing the real camera (AVCaptureSession isn't available in a
/// unit test host). finishRecording was relaxed from `private` to `internal`
/// (visibility only — no other change) specifically to make this reachable;
/// see plan Step 7's test spec. The synthetic URL doesn't exist on disk —
/// AVURLAsset's async duration load fails gracefully there (finishRecording
/// already swallows that via `try?`, defaulting to 0), so no camera/file I/O
/// is actually exercised. .serialized: shares the "lastUsedClub" UserDefaults
/// key with ClubDefaultStoreTests. Nested under PersistenceStateSuite (whose
/// .serialized applies recursively) because per-suite .serialized only
/// serializes WITHIN a suite, not across it and a sibling suite — both must
/// nest under the same serialized parent (see PersistenceStateSuite.swift).
extension PersistenceStateSuite {
@Suite(.serialized)
@MainActor
struct CaptureClubTests {

    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(for: SwingSession.self, AnalysisResult.self,
                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }

    private func clearStoredDefault() {
        UserDefaults.standard.removeObject(forKey: GolfClub.storageKey)
    }

    private var syntheticURL: URL {
        URL(fileURLWithPath: "/tmp/nonexistent-\(UUID().uuidString).mov")
    }

    @Test func finishRecordingPersistsSelectedClubOnTheSession() async throws {
        clearStoredDefault()
        defer { clearStoredDefault() }

        let container = try makeContainer()
        let context = container.mainContext
        let viewModel = CaptureViewModel()
        viewModel.selectedClub = .driver

        await viewModel.finishRecording(result: .success(syntheticURL),
                                        angle: .faceOn,
                                        club: viewModel.selectedClub,
                                        modelContext: context)
        try context.save()

        let session = try #require(try context.fetch(FetchDescriptor<SwingSession>()).first)
        #expect(session.golfClub == .driver)
    }

    @Test func finishRecordingUpdatesStoredDefault() async throws {
        clearStoredDefault()
        defer { clearStoredDefault() }

        let container = try makeContainer()
        let context = container.mainContext
        let viewModel = CaptureViewModel()
        viewModel.selectedClub = .sandWedge

        await viewModel.finishRecording(result: .success(syntheticURL),
                                        angle: .faceOn,
                                        club: viewModel.selectedClub,
                                        modelContext: context)

        #expect(GolfClub.storedDefault == .sandWedge)
    }
}
}
