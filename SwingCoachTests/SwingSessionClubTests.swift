//
//  SwingSessionClubTests.swift
//  SwingCoachTests
//

import SwiftData
import Testing
@testable import SwingCoach

/// Coverage for the `club`/`golfClub` accessor and its column persistence
/// under the CURRENT schema. This proves accessor behavior and round-trip
/// through SwiftData, NOT the v1→v2 lightweight migration (see plan Risk
/// "SwiftData migration failure" — that's a manual smoke test, not a unit
/// test). .serialized: shares no process-global state with other suites,
/// but keeps this suite's own persistence tests from interleaving.
@Suite(.serialized)
@MainActor
struct SwingSessionClubTests {

    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(for: SwingSession.self, AnalysisResult.self,
                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }

    @Test func initWithClubSetsGolfClub() {
        let session = SwingSession(cameraAngle: .faceOn,
                                   videoFileName: "swing.mov",
                                   duration: 1.0,
                                   club: .iron7)
        #expect(session.golfClub == .iron7)
    }

    @Test func defaultInitLeavesGolfClubNil() {
        let session = SwingSession(cameraAngle: .faceOn,
                                   videoFileName: "swing.mov",
                                   duration: 1.0)
        #expect(session.golfClub == nil)
    }

    @Test func unknownRawStringReadsAsNil() {
        let session = SwingSession(cameraAngle: .faceOn,
                                   videoFileName: "swing.mov",
                                   duration: 1.0)
        session.club = "some-old-unrecognized-value"
        #expect(session.golfClub == nil)
    }

    @Test func settingGolfClubWritesTheRawValue() {
        let session = SwingSession(cameraAngle: .faceOn,
                                   videoFileName: "swing.mov",
                                   duration: 1.0)
        session.golfClub = .driver
        #expect(session.club == "driver")

        session.golfClub = nil
        #expect(session.club == nil)
    }

    @Test func setClubRoundTripsThroughAModelContainer() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let session = SwingSession(cameraAngle: .faceOn,
                                   videoFileName: "swing.mov",
                                   duration: 1.0,
                                   club: .sandWedge)
        context.insert(session)
        try context.save()

        let refetched = try #require(try context.fetch(FetchDescriptor<SwingSession>()).first)
        #expect(refetched.golfClub == .sandWedge)
    }
}
