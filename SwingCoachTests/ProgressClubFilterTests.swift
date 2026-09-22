//
//  ProgressClubFilterTests.swift
//  SwingCoachTests
//

import Foundation
import SwiftData
import Testing
@testable import SwingCoach

/// Progress's (stretch) club filter narrows aggregation to only the
/// AnalysisResults whose session.golfClub matches — implemented as a single
/// guard in ProgressViewModel.reload's results loop. See ProgressViewModelTests
/// for why this suite is nested under PersistenceStateSuite and .serialized:
/// reload(from:) writes CoachingEngine's process-global storedPreviousFocusArea
/// as a side effect, which races across concurrent tests sharing that key.
extension PersistenceStateSuite {
@Suite(.serialized)
@MainActor
struct ProgressClubFilterTests {

    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(for: SwingSession.self, AnalysisResult.self,
                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }

    private func makeSession(club: GolfClub?, date: Date, in context: ModelContext) -> SwingSession {
        let session = SwingSession(cameraAngle: .faceOn,
                                   videoFileName: "\(UUID().uuidString).mov",
                                   duration: 1.0,
                                   club: club)
        session.date = date
        context.insert(session)
        return session
    }

    private func addResult(_ check: CheckName, score: Double, to session: SwingSession) {
        let result = CheckResult(checkName: check, score: score, measuredValue: 3.0,
                                 feedback: "test feedback")
        session.analysisResults.append(AnalysisResult(result: result))
    }

    @Test func clubFilterIncludesOnlyMatchingSessions() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let driverSession = makeSession(club: .driver, date: Date(timeIntervalSinceReferenceDate: 1_000), in: context)
        addResult(.tempo, score: 90, to: driverSession)
        let putterSession = makeSession(club: .putter, date: Date(timeIntervalSinceReferenceDate: 2_000), in: context)
        addResult(.tempo, score: 40, to: putterSession)

        let viewModel = ProgressViewModel()
        viewModel.reload(from: context, clubFilter: .driver)

        let tempo = try #require(viewModel.trends.first { $0.check == .tempo })
        #expect(tempo.points.map(\.score) == [90])
        #expect(viewModel.analyzedSessionCount == 1)
    }

    @Test func nilClubFilterAggregatesEverySession() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let driverSession = makeSession(club: .driver, date: Date(timeIntervalSinceReferenceDate: 1_000), in: context)
        addResult(.tempo, score: 90, to: driverSession)
        let putterSession = makeSession(club: .putter, date: Date(timeIntervalSinceReferenceDate: 2_000), in: context)
        addResult(.tempo, score: 40, to: putterSession)
        let unspecifiedSession = makeSession(club: nil, date: Date(timeIntervalSinceReferenceDate: 3_000), in: context)
        addResult(.tempo, score: 60, to: unspecifiedSession)

        let viewModel = ProgressViewModel()
        viewModel.reload(from: context, clubFilter: nil)

        let tempo = try #require(viewModel.trends.first { $0.check == .tempo })
        #expect(tempo.points.map(\.score) == [90, 40, 60])
        #expect(viewModel.analyzedSessionCount == 3)
    }

    @Test func clubFilterExcludesSessionsWithNoClub() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let driverSession = makeSession(club: .driver, date: Date(timeIntervalSinceReferenceDate: 1_000), in: context)
        addResult(.tempo, score: 90, to: driverSession)
        let unspecifiedSession = makeSession(club: nil, date: Date(timeIntervalSinceReferenceDate: 2_000), in: context)
        addResult(.tempo, score: 20, to: unspecifiedSession)

        let viewModel = ProgressViewModel()
        viewModel.reload(from: context, clubFilter: .driver)

        let tempo = try #require(viewModel.trends.first { $0.check == .tempo })
        #expect(tempo.points.map(\.score) == [90])
        #expect(viewModel.analyzedSessionCount == 1)
    }
}
}
