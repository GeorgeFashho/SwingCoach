//
//  AnalysisResult.swift
//  SwingCoach
//

import Foundation
import SwiftData

/// One persisted check result for a session (plan section 4 data model).
/// The raw measured value is stored alongside the score so scores can be
/// recomputed if the formula or the thresholds in Constants change.
@Model
final class AnalysisResult {
    var id: UUID
    var checkName: String            // CheckName raw value
    var score: Double                // 0–100
    var measuredValue: Double        // angle, ratio, or displacement
    var feedback: String
    var severity: String             // Severity raw value
    var session: SwingSession?

    init(result: CheckResult) {
        self.id = UUID()
        self.checkName = result.checkName.rawValue
        self.score = result.score
        self.measuredValue = result.measuredValue
        self.feedback = result.feedback
        self.severity = result.severity.rawValue
        self.session = nil
    }
}
