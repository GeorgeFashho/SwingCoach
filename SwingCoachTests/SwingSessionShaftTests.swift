//
//  SwingSessionShaftTests.swift
//  SwingCoachTests
//

import SwiftData
import Testing
@testable import SwingCoach

/// Coverage for the `shaftAngleAtAddress`/`shaftLinePoints` additive
/// optionals and their column persistence under the CURRENT schema, mirroring
/// SwingSessionClubTests. .serialized: keeps this suite's own persistence
/// tests from interleaving (it shares no process-global state with other
/// suites, so it doesn't need to nest under PersistenceStateSuite).
@Suite(.serialized)
@MainActor
struct SwingSessionShaftTests {

    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(for: SwingSession.self, AnalysisResult.self,
                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }

    @Test func initWithShaftValuesSetsBothFields() {
        let session = SwingSession(cameraAngle: .faceOn,
                                   videoFileName: "swing.mov",
                                   duration: 1.0,
                                   shaftAngleAtAddress: 42.5,
                                   shaftLinePoints: [0.1, 0.2, 0.3, 0.4])
        #expect(session.shaftAngleAtAddress == 42.5)
        #expect(session.shaftLinePoints == [0.1, 0.2, 0.3, 0.4])
    }

    @Test func defaultInitLeavesShaftFieldsNil() {
        let session = SwingSession(cameraAngle: .faceOn,
                                   videoFileName: "swing.mov",
                                   duration: 1.0)
        #expect(session.shaftAngleAtAddress == nil)
        #expect(session.shaftLinePoints == nil)
    }

    @Test func settingShaftFieldsAfterInitRoundTrips() {
        let session = SwingSession(cameraAngle: .faceOn,
                                   videoFileName: "swing.mov",
                                   duration: 1.0)

        session.shaftAngleAtAddress = 67.25
        session.shaftLinePoints = [0.05, 0.9, 0.5, 0.15]
        #expect(session.shaftAngleAtAddress == 67.25)
        #expect(session.shaftLinePoints == [0.05, 0.9, 0.5, 0.15])

        session.shaftAngleAtAddress = nil
        session.shaftLinePoints = nil
        #expect(session.shaftAngleAtAddress == nil)
        #expect(session.shaftLinePoints == nil)
    }

    @Test func setShaftValuesRoundTripsThroughAModelContainer() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let session = SwingSession(cameraAngle: .faceOn,
                                   videoFileName: "swing.mov",
                                   duration: 1.0,
                                   shaftAngleAtAddress: 51.5,
                                   shaftLinePoints: [0.2, 0.8, 0.6, 0.3])
        context.insert(session)
        try context.save()

        let refetched = try #require(try context.fetch(FetchDescriptor<SwingSession>()).first)
        #expect(refetched.shaftAngleAtAddress == 51.5)
        #expect(refetched.shaftLinePoints == [0.2, 0.8, 0.6, 0.3])
    }
}
