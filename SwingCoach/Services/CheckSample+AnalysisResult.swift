//
//  CheckSample+AnalysisResult.swift
//  SwingCoach
//

extension CoachingEngine.CheckSample {

    /// Projects one persisted result row to a pure focus-area sample. nil when
    /// the row lacks a recognizable check or an owning session. This is the ONE
    /// row→sample projection both view models use, so their focus areas can
    /// never diverge (plan "single source of truth over the same projected
    /// samples"). Kept in its own file so CoachingEngine.swift stays
    /// SwiftData-free; @MainActor because AnalysisResult is a SwiftData model.
    @MainActor
    init?(from result: AnalysisResult) {
        guard let check = CheckName(rawValue: result.checkName),
              let session = result.session else { return nil }
        self.init(checkName: check,
                  score: result.score,
                  measuredValue: result.measuredValue,
                  sessionID: session.id,
                  date: session.date)
    }
}
