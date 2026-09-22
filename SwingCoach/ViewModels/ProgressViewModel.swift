//
//  ProgressViewModel.swift
//  SwingCoach
//

import Foundation
import Observation
import SwiftData

nonisolated enum ProgressGranularity: String, CaseIterable, Identifiable {
    case session, day, month
    var id: String { rawValue }
    var label: String {
        switch self {
        case .session: "Per Swing"
        case .day:     "Daily"
        case .month:   "Monthly"
        }
    }
}

/// Aggregates the persisted AnalysisResult rows into per-check score trends
/// for the Progress tab. Pure aggregation: scores and severities come
/// straight from the stored rows — analysis is never re-run and scores are
/// never re-derived here.
@Observable
@MainActor
final class ProgressViewModel {

    struct TrendPoint: Identifiable {
        let id: UUID
        let date: Date
        let score: Double
        let severity: Severity
    }

    struct CheckTrend: Identifiable {
        let check: CheckName
        let points: [TrendPoint]

        var id: CheckName { check }
    }

    /// One trend per check that has at least one stored result, in
    /// CheckName.allCases order; points sorted oldest-first.
    private(set) var trends: [CheckTrend] = []

    /// How many distinct sessions have stored analysis results.
    private(set) var analyzedSessionCount = 0

    /// The cross-session focus area over the recent window, or nil until
    /// enough history exists. Derived at reload; no new stored state.
    private(set) var focusArea: CoachingEngine.FocusAreaResult?

    func reload(from context: ModelContext, baseline: Date? = nil, clubFilter: GolfClub? = nil) {
        let results = (try? context.fetch(FetchDescriptor<AnalysisResult>())) ?? []

        var pointsByCheck: [CheckName: [TrendPoint]] = [:]
        var analyzedSessions: Set<UUID> = []
        var samples: [CoachingEngine.CheckSample] = []
        for result in results {
            if let baseline, let date = result.session?.date, date < baseline { continue }
            if let clubFilter, result.session?.golfClub != clubFilter { continue }
            if let sample = CoachingEngine.CheckSample(from: result) {
                samples.append(sample)
            }
            guard let check = CheckName(rawValue: result.checkName),
                  let severity = Severity(rawValue: result.severity),
                  let session = result.session else { continue }
            analyzedSessions.insert(session.id)
            pointsByCheck[check, default: []].append(
                TrendPoint(id: result.id,
                           date: session.date,
                           score: result.score,
                           severity: severity))
        }

        analyzedSessionCount = analyzedSessions.count
        trends = CheckName.allCases.compactMap { check in
            guard let points = pointsByCheck[check] else { return nil }
            return CheckTrend(check: check,
                              points: points.sorted { $0.date < $1.date })
        }
        focusArea = CoachingEngine.focusAreaOverRecentSessions(from: samples)
    }

    /// Buckets raw per-session trend points into daily or monthly averages.
    /// .session is the identity (returns trends unchanged, stored severities
    /// intact); .day/.month average scores per calendar bucket and derive
    /// severity from the mean via Severity(score:).
    static func bucketed(_ trends: [CheckTrend], by granularity: ProgressGranularity) -> [CheckTrend] {
        guard granularity != .session else { return trends }        // identity: keep stored severities
        let calendar = Calendar.current
        return trends.map { trend in
            let groups = Dictionary(grouping: trend.points) { point -> Date in
                switch granularity {
                case .day: calendar.startOfDay(for: point.date)
                default:   calendar.dateInterval(of: .month, for: point.date)?.start
                            ?? calendar.startOfDay(for: point.date)   // .month (.session unreachable past the guard)
                }
            }
            let points = groups.map { bucketStart, pts -> TrendPoint in
                let avg = pts.reduce(0) { $0 + $1.score } / Double(pts.count)
                let id  = pts.min { $0.date < $1.date }!.id          // stable id → no chart flicker
                return TrendPoint(id: id, date: bucketStart, score: avg, severity: Severity(score: avg))
            }
            .sorted { $0.date < $1.date }
            return CheckTrend(check: trend.check, points: points)
        }
    }
}
