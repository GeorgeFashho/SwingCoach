//
//  HistoryClubFilterTests.swift
//  SwingCoachTests
//

import Foundation
import SwiftData
import Testing
@testable import SwingCoach

/// HistoryView.filter is the pinned, pure club filter used by the History
/// tab's toolbar Menu: nil shows every session, a specific club narrows to
/// matches only. Sessions with no club (never set) or an unrecognized raw
/// value must be excluded from a specific-club filter and only ever appear
/// under "All Clubs" (plan Risk "Known MVP limitation").
@MainActor
struct HistoryClubFilterTests {

    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(for: SwingSession.self, AnalysisResult.self,
                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }

    private func makeSession(club: GolfClub?, in context: ModelContext) -> SwingSession {
        let session = SwingSession(cameraAngle: .faceOn,
                                   videoFileName: "\(UUID().uuidString).mov",
                                   duration: 1.0,
                                   club: club)
        context.insert(session)
        return session
    }

    @Test func nilFilterReturnsAllSessions() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let driver = makeSession(club: .driver, in: context)
        let putter = makeSession(club: .putter, in: context)
        let unspecified = makeSession(club: nil, in: context)

        let result = HistoryView.filter([driver, putter, unspecified], by: nil)

        #expect(Set(result.map(\.id)) == Set([driver, putter, unspecified].map(\.id)))
    }

    @Test func specificClubReturnsOnlyMatchingSessions() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let driverOne = makeSession(club: .driver, in: context)
        let driverTwo = makeSession(club: .driver, in: context)
        let putter = makeSession(club: .putter, in: context)

        let result = HistoryView.filter([driverOne, driverTwo, putter], by: .driver)

        #expect(Set(result.map(\.id)) == Set([driverOne, driverTwo].map(\.id)))
    }

    @Test func nilClubSessionExcludedFromSpecificFilterButIncludedInAll() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let driver = makeSession(club: .driver, in: context)
        let unspecified = makeSession(club: nil, in: context)

        let filtered = HistoryView.filter([driver, unspecified], by: .driver)
        let all = HistoryView.filter([driver, unspecified], by: nil)

        #expect(filtered.map(\.id) == [driver.id])
        #expect(Set(all.map(\.id)) == Set([driver, unspecified].map(\.id)))
    }

    @Test func unrecognizedRawSessionExcludedFromSpecificFilterButIncludedInAll() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let driver = makeSession(club: .driver, in: context)
        let other = makeSession(club: nil, in: context)
        other.club = "some-old-unrecognized-value"

        let filtered = HistoryView.filter([driver, other], by: .driver)
        let all = HistoryView.filter([driver, other], by: nil)

        #expect(filtered.map(\.id) == [driver.id])
        #expect(Set(all.map(\.id)) == Set([driver, other].map(\.id)))
    }
}
