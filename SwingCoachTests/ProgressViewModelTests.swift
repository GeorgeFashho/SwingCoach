//
//  ProgressViewModelTests.swift
//  SwingCoachTests
//

import Foundation
import SwiftData
import Testing
@testable import SwingCoach

/// The Progress tab aggregates persisted AnalysisResult rows — it must
/// order points by session date, follow CheckName.allCases order, and
/// return stored scores/severities untouched (never re-derived).
/// .serialized: reload(from:) always writes CoachingEngine's process-global
/// storedPreviousFocusArea as a side effect, which races across concurrent
/// tests in this suite (and the other suites that share that key). Nested
/// under PersistenceStateSuite so serialization also spans those suites
/// (see PersistenceStateSuite.swift).
extension PersistenceStateSuite {
@Suite(.serialized)
@MainActor
struct ProgressViewModelTests {

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

    private func addResult(_ check: CheckName, score: Double, to session: SwingSession) -> AnalysisResult {
        let result = CheckResult(checkName: check, score: score, measuredValue: 3.0,
                                 feedback: "test feedback")
        let row = AnalysisResult(result: result)
        session.analysisResults.append(row)
        return row
    }

    @Test func pointsAreOrderedBySessionDateAcrossSessions() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let older = Date(timeIntervalSinceReferenceDate: 1_000)
        let newer = Date(timeIntervalSinceReferenceDate: 2_000)

        // Insert the newer session's row first: ordering must come from the
        // session dates, not insertion order.
        let newerSession = makeSession(date: newer, in: context)
        _ = addResult(.tempo, score: 50, to: newerSession)
        let olderSession = makeSession(date: older, in: context)
        _ = addResult(.tempo, score: 100, to: olderSession)

        let viewModel = ProgressViewModel()
        viewModel.reload(from: context)

        let tempo = try #require(viewModel.trends.first { $0.check == .tempo })
        #expect(tempo.points.map(\.date) == [older, newer])
        #expect(tempo.points.map(\.score) == [100, 50])
    }

    @Test func trendsFollowCheckNameOrderAndOmitChecksWithoutRows() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let session = makeSession(date: Date(timeIntervalSinceReferenceDate: 1_000), in: context)
        // Insert in the reverse of CheckName.allCases order.
        _ = addResult(.tempo, score: 75, to: session)
        _ = addResult(.headStability, score: 75, to: session)

        let viewModel = ProgressViewModel()
        viewModel.reload(from: context)

        #expect(viewModel.trends.map(\.check) == [.headStability, .tempo])
    }

    @Test func analyzedSessionCountCountsOnlySessionsWithRows() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let first = makeSession(date: Date(timeIntervalSinceReferenceDate: 1_000), in: context)
        _ = addResult(.tempo, score: 100, to: first)
        let second = makeSession(date: Date(timeIntervalSinceReferenceDate: 2_000), in: context)
        _ = addResult(.tempo, score: 50, to: second)
        _ = addResult(.headStability, score: 50, to: second)
        _ = makeSession(date: Date(timeIntervalSinceReferenceDate: 3_000), in: context)

        let viewModel = ProgressViewModel()
        viewModel.reload(from: context)

        #expect(viewModel.analyzedSessionCount == 2)
    }

    @Test func storedSeverityIsReturnedWithoutReDerivation() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let session = makeSession(date: Date(timeIntervalSinceReferenceDate: 1_000), in: context)
        let row = addResult(.tempo, score: 100, to: session)
        // Deliberately disagree with the score: aggregation must hand back
        // the STORED severity, proving it never re-derives from the score.
        row.severity = Severity.critical.rawValue

        let viewModel = ProgressViewModel()
        viewModel.reload(from: context)

        let tempo = try #require(viewModel.trends.first { $0.check == .tempo })
        let point = try #require(tempo.points.first)
        #expect(point.score == 100)
        #expect(point.severity == .critical)
    }

    // MARK: - Baseline filtering (Reset Progress)

    @Test func baselineExcludesTrendsCountAndFocusAreaBeforeCutoff() throws {
        let container = try makeContainer()
        let context = container.mainContext
        CoachingEngine.storedPreviousFocusArea = nil
        defer { CoachingEngine.storedPreviousFocusArea = nil }

        // Pre-cutoff sessions score badly; if they leaked into the focus
        // area's mean, the assertion below would catch it.
        for offset in 0..<3 {
            let old = makeSession(date: Date(timeIntervalSinceReferenceDate: 1_000 + Double(offset)), in: context)
            _ = addResult(.tempo, score: 10, to: old)
        }
        for offset in 0..<3 {
            let newer = makeSession(date: Date(timeIntervalSinceReferenceDate: 2_000 + Double(offset)), in: context)
            _ = addResult(.tempo, score: 90, to: newer)
        }

        let viewModel = ProgressViewModel()
        viewModel.reload(from: context, baseline: Date(timeIntervalSinceReferenceDate: 1_500))

        let tempo = try #require(viewModel.trends.first { $0.check == .tempo })
        #expect(tempo.points.map(\.score) == [90, 90, 90])
        #expect(viewModel.analyzedSessionCount == 3)
        #expect(viewModel.focusArea?.checkName == .tempo)
        #expect(viewModel.focusArea?.meanScore == 90)
    }

    @Test func resetToNowEmptiesProgress() throws {
        let container = try makeContainer()
        let context = container.mainContext
        CoachingEngine.storedPreviousFocusArea = nil
        defer { CoachingEngine.storedPreviousFocusArea = nil }

        let session = makeSession(date: Date(timeIntervalSinceReferenceDate: 1_000), in: context)
        _ = addResult(.tempo, score: 90, to: session)

        let viewModel = ProgressViewModel()
        viewModel.reload(from: context, baseline: .now)

        #expect(viewModel.trends.isEmpty)
        #expect(viewModel.analyzedSessionCount == 0)
        #expect(viewModel.focusArea == nil)
    }

    @Test func nilBaselineIncludesEverything() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let older = Date(timeIntervalSinceReferenceDate: 1_000)
        let newer = Date(timeIntervalSinceReferenceDate: 2_000)

        let olderSession = makeSession(date: older, in: context)
        _ = addResult(.tempo, score: 100, to: olderSession)
        let newerSession = makeSession(date: newer, in: context)
        _ = addResult(.tempo, score: 50, to: newerSession)

        let viewModel = ProgressViewModel()
        viewModel.reload(from: context, baseline: nil)

        let tempo = try #require(viewModel.trends.first { $0.check == .tempo })
        #expect(tempo.points.map(\.date) == [older, newer])
        #expect(tempo.points.map(\.score) == [100, 50])
        #expect(viewModel.analyzedSessionCount == 2)
    }

    // MARK: - Bucketing (Daily/Monthly granularity)

    @Test func dailyBucketingAveragesSameDayScores() throws {
        let calendar = Calendar.current
        let baseDay = calendar.startOfDay(for: Date(timeIntervalSinceReferenceDate: 800_000_000))
        let morning = calendar.date(byAdding: .hour, value: 1, to: baseDay)!
        let evening = calendar.date(byAdding: .hour, value: 20, to: baseDay)!
        let points = [
            ProgressViewModel.TrendPoint(id: UUID(), date: morning, score: 40, severity: .critical),
            ProgressViewModel.TrendPoint(id: UUID(), date: evening, score: 80, severity: .good),
        ]
        let trends = [ProgressViewModel.CheckTrend(check: .tempo, points: points)]

        let bucketed = ProgressViewModel.bucketed(trends, by: .day)

        let tempo = try #require(bucketed.first { $0.check == .tempo })
        #expect(tempo.points.count == 1)
        let point = try #require(tempo.points.first)
        #expect(point.score == 60)
        #expect(point.date == baseDay)
    }

    @Test func monthlyBucketingAveragesSameMonthScores() throws {
        let calendar = Calendar.current
        let monthStart = calendar.dateInterval(of: .month, for: Date(timeIntervalSinceReferenceDate: 800_000_000))!.start
        let dayOne = calendar.date(byAdding: .day, value: 2, to: monthStart)!
        let dayTwo = calendar.date(byAdding: .day, value: 10, to: monthStart)!
        let nextMonth = calendar.date(byAdding: .month, value: 1, to: monthStart)!
        let nextMonthPoint = calendar.date(byAdding: .day, value: 3, to: nextMonth)!
        let points = [
            ProgressViewModel.TrendPoint(id: UUID(), date: dayOne, score: 60, severity: .needsWork),
            ProgressViewModel.TrendPoint(id: UUID(), date: dayTwo, score: 80, severity: .good),
            ProgressViewModel.TrendPoint(id: UUID(), date: nextMonthPoint, score: 50, severity: .needsWork),
        ]
        let trends = [ProgressViewModel.CheckTrend(check: .tempo, points: points)]

        let bucketed = ProgressViewModel.bucketed(trends, by: .month)

        let tempo = try #require(bucketed.first { $0.check == .tempo })
        #expect(tempo.points.count == 2)
        #expect(tempo.points[0].date == monthStart)
        #expect(tempo.points[0].score == 70)
        #expect(tempo.points[1].date == nextMonth)
        #expect(tempo.points[1].score == 50)
    }

    @Test func sessionGranularityIsIdentityAndKeepsStoredSeverity() throws {
        // Score and severity deliberately disagree: .session must hand back
        // the STORED severity, never re-deriving it from the score.
        let point = ProgressViewModel.TrendPoint(id: UUID(), date: Date(timeIntervalSinceReferenceDate: 1_000),
                                                 score: 100, severity: .critical)
        let trends = [ProgressViewModel.CheckTrend(check: .tempo, points: [point])]

        let bucketed = ProgressViewModel.bucketed(trends, by: .session)

        let tempo = try #require(bucketed.first { $0.check == .tempo })
        #expect(tempo.points.map(\.score) == [100])
        #expect(tempo.points.map(\.severity) == [.critical])
    }

    @Test func averagedBucketSeverityDerivedFromMean() throws {
        let calendar = Calendar.current
        let baseDay = calendar.startOfDay(for: Date(timeIntervalSinceReferenceDate: 800_000_000))
        let morning = calendar.date(byAdding: .hour, value: 1, to: baseDay)!
        let evening = calendar.date(byAdding: .hour, value: 12, to: baseDay)!

        func sameDayTrend(_ check: CheckName, _ first: Double, _ second: Double) -> ProgressViewModel.CheckTrend {
            ProgressViewModel.CheckTrend(check: check, points: [
                ProgressViewModel.TrendPoint(id: UUID(), date: morning, score: first, severity: .needsWork),
                ProgressViewModel.TrendPoint(id: UUID(), date: evening, score: second, severity: .needsWork),
            ])
        }
        let trends = [
            sameDayTrend(.tempo, 60, 80),          // mean 70 → .good (>= floor)
            sameDayTrend(.headStability, 20, 40),  // mean 30 → .needsWork (>= floor, not .good)
            sameDayTrend(.hipSway, 10, 20),         // mean 15 → .critical
        ]

        let bucketed = ProgressViewModel.bucketed(trends, by: .day)

        #expect(bucketed.first { $0.check == .tempo }?.points.first?.severity == .good)
        #expect(bucketed.first { $0.check == .headStability }?.points.first?.severity == .needsWork)
        #expect(bucketed.first { $0.check == .hipSway }?.points.first?.severity == .critical)
    }

    @Test func singlePointBucketReturnsThatScore() throws {
        let date = Calendar.current.startOfDay(for: Date(timeIntervalSinceReferenceDate: 800_000_000))
        let point = ProgressViewModel.TrendPoint(id: UUID(), date: date, score: 77, severity: .needsWork)
        let trends = [ProgressViewModel.CheckTrend(check: .tempo, points: [point])]

        let bucketed = ProgressViewModel.bucketed(trends, by: .day)

        let tempo = try #require(bucketed.first { $0.check == .tempo })
        let resultPoint = try #require(tempo.points.first)
        #expect(resultPoint.score == 77)
        #expect(resultPoint.date == date)
    }
}
}
