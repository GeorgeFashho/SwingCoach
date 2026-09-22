//
//  CoachingEngine.swift
//  SwingCoach
//

import Foundation

/// Pure coaching logic over a swing's check outcomes (plan D4): pick the one
/// fault to fix first, and decide whether every scored check cleared its good
/// band. A nonisolated struct like AnalysisEngine — no SwiftData, no view
/// state — so the selection rule and its tie-break are unit-testable in
/// isolation. Views render; this decides.
nonisolated struct CoachingEngine {

    /// The worst-scoring scored check — the swing's "fix this first". Returned
    /// REGARDLESS of whether its score is good (critic fix C1: selection and
    /// severity are separate questions; the view decides which card to show).
    /// Ties break by CheckName.allCases order (fundamentals first). nil when
    /// no check produced a score.
    func worstCheck(from outcomes: [CheckOutcome]) -> CheckResult? {
        outcomes.compactMap(\.result).min { lhs, rhs in
            if lhs.score != rhs.score { return lhs.score < rhs.score }
            return order(lhs.checkName) < order(rhs.checkName)
        }
    }

    /// True iff at least one check scored AND every scored check cleared its
    /// good band. The all-good state is a SEPARATE signal from a nil worst
    /// check: it drives the positive coaching card.
    func allChecksGood(from outcomes: [CheckOutcome]) -> Bool {
        let scored = outcomes.compactMap(\.result)
        guard !scored.isEmpty else { return false }
        return scored.allSatisfy { $0.score >= Constants.severityGoodFloor }
    }

    private func order(_ name: CheckName) -> Int {
        CheckName.allCases.firstIndex(of: name) ?? Int.max
    }

    // MARK: - Cross-session focus area (Stage 2)

    /// A plain projection of one persisted AnalysisResult row (critic fix M6):
    /// callers flatten @Model rows to this value type first so the focusArea
    /// function stays SwiftData-free and unit-testable without a container.
    /// `measuredValue` rides along so the card's drill can branch on the most
    /// recent fault direction.
    nonisolated struct CheckSample {
        let checkName: CheckName
        let score: Double
        let measuredValue: Double
        let sessionID: UUID
        let date: Date
    }

    /// Which direction a check's score is heading over the recent window.
    nonisolated enum Trend {
        case improving
        case steady
        case declining
    }

    /// The cross-session focus area: the check with the lowest mean score over
    /// the recent window, its severity, its trend, and a representative
    /// measured value (the most recent) for the drill's fault direction.
    nonisolated struct FocusAreaResult {
        let checkName: CheckName
        let meanScore: Double
        let measuredValue: Double
        let severity: Severity
        let trend: Trend
    }

    /// The focus area over a window of recent sessions (plan Stage 2). Pure:
    /// plain value types only, no @Model and no UserDefaults — `previousFocusArea`
    /// (the hysteresis anchor) is passed in explicitly.
    ///
    /// Rule: keep only samples from `recentSessionIDs`, group by check, drop
    /// checks with fewer than `focusAreaMinDataPoints`, take the lowest mean
    /// score (ties by CheckName.allCases order). Hysteresis: keep
    /// `previousFocusArea` unless another check's mean is more than
    /// `focusAreaTrendThreshold` points worse; if the previous area is no
    /// longer among the qualified checks, ignore it (architect A4). nil when
    /// no check qualifies.
    static func focusArea(from samples: [CheckSample],
                          recentSessionIDs: Set<UUID>,
                          previousFocusArea: CheckName?) -> FocusAreaResult? {
        var byCheck: [CheckName: [CheckSample]] = [:]
        for sample in samples where recentSessionIDs.contains(sample.sessionID) {
            byCheck[sample.checkName, default: []].append(sample)
        }
        let qualified = byCheck.filter { $0.value.count >= Constants.focusAreaMinDataPoints }
        guard !qualified.isEmpty else { return nil }

        let means = qualified.mapValues { group in
            group.reduce(0) { $0 + $1.score } / Double(group.count)
        }
        let lowest = means.min { lhs, rhs in
            if lhs.value != rhs.value { return lhs.value < rhs.value }
            return (CheckName.allCases.firstIndex(of: lhs.key) ?? .max)
                 < (CheckName.allCases.firstIndex(of: rhs.key) ?? .max)
        }!.key

        // Hysteresis: keep the previous area unless the current lowest is more
        // than the threshold worse. An unqualified previous area is ignored.
        var chosen = lowest
        if let previousFocusArea, let previousMean = means[previousFocusArea] {
            if previousMean - means[lowest]! <= Constants.focusAreaTrendThreshold {
                chosen = previousFocusArea
            }
        }

        let group = qualified[chosen]!
        let latest = group.max { $0.date < $1.date }!
        return FocusAreaResult(checkName: chosen,
                               meanScore: means[chosen]!,
                               measuredValue: latest.measuredValue,
                               severity: Severity(score: means[chosen]!),
                               trend: trend(for: group))
    }

    /// Trend over a check's samples: compare the mean of the older half to the
    /// mean of the newer half, with a ±`focusAreaTrendThreshold` dead zone so
    /// noise doesn't flip the label. Simpler than regression and robust at small N.
    private static func trend(for samples: [CheckSample]) -> Trend {
        let sorted = samples.sorted { $0.date < $1.date }
        guard sorted.count >= 2 else { return .steady }
        let mid = sorted.count / 2
        let firstHalf = sorted[..<mid]
        let secondHalf = sorted[mid...]
        let firstMean = firstHalf.reduce(0) { $0 + $1.score } / Double(firstHalf.count)
        let secondMean = secondHalf.reduce(0) { $0 + $1.score } / Double(secondHalf.count)
        if secondMean > firstMean + Constants.focusAreaTrendThreshold { return .improving }
        if secondMean < firstMean - Constants.focusAreaTrendThreshold { return .declining }
        return .steady
    }

    /// The shared, cross-launch hysteresis anchor (architect synthesis, critic
    /// fix M1): one UserDefaults string, following the Handedness.stored
    /// precedent, so both view models agree on the "previous" focus area. The
    /// pure `focusArea` function never touches this — callers read it before
    /// and write the result back after.
    static let previousFocusAreaKey = "previousFocusArea"

    static var storedPreviousFocusArea: CheckName? {
        get { UserDefaults.standard.string(forKey: previousFocusAreaKey).flatMap(CheckName.init) }
        set {
            if let newValue {
                UserDefaults.standard.set(newValue.rawValue, forKey: previousFocusAreaKey)
            } else {
                UserDefaults.standard.removeObject(forKey: previousFocusAreaKey)
            }
        }
    }

    /// The impure convenience both view models share: pick the most recent
    /// `focusAreaSessionWindow` sessions from the samples, read the stored
    /// hysteresis anchor, run the pure `focusArea`, and write the result back
    /// as the new anchor. The per-@Model row projection stays in each view
    /// model; this owns everything downstream of `[CheckSample]` so the two
    /// can never disagree. The pure `focusArea` above stays UserDefaults-free.
    static func focusAreaOverRecentSessions(from samples: [CheckSample]) -> FocusAreaResult? {
        var latestDateBySession: [UUID: Date] = [:]
        for sample in samples {
            latestDateBySession[sample.sessionID] = sample.date
        }
        let recentIDs = Set(latestDateBySession.sorted { $0.value > $1.value }
            .prefix(Constants.focusAreaSessionWindow)
            .map(\.key))

        let result = focusArea(from: samples,
                               recentSessionIDs: recentIDs,
                               previousFocusArea: storedPreviousFocusArea)
        storedPreviousFocusArea = result?.checkName
        return result
    }
}
