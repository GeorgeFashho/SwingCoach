import Foundation

/// The "Reset Progress" baseline: Progress trends, the analyzed-session count,
/// the focus area, and the min-sessions gate all count ONLY swings on/after
/// this date. nil = no reset yet (count everything). Stored as a Double
/// (timeIntervalSinceReferenceDate) because UserDefaults/@AppStorage can't hold
/// a Date — mirrors Handedness.stored / CoachingEngine.storedPreviousFocusArea.
///
/// Accepted limitation: filtering is wall-clock-relative (session.date < date).
/// A swing recorded while the device clock was wrong could land on the wrong
/// side of the baseline. Chosen deliberately over a per-row Bool flag, which
/// would force a SwiftData migration on the user's first app and put reset
/// state inside the table that "Delete all swings" removes.
nonisolated enum ProgressBaseline {
    static let storageKey = "progressBaselineDate"

    static var date: Date? {
        get {
            // double(forKey:) returns 0 when absent. timeIntervalSinceReferenceDate
            // == 0 is a real instant (2001-01-01 UTC), but .now in 2026 is ~7.9e8
            // and can never be 0, so the sentinel collision is unreachable here.
            let raw = UserDefaults.standard.double(forKey: storageKey)
            return raw == 0 ? nil : Date(timeIntervalSinceReferenceDate: raw)
        }
        set {
            if let newValue {
                UserDefaults.standard.set(newValue.timeIntervalSinceReferenceDate, forKey: storageKey)
            } else {
                UserDefaults.standard.removeObject(forKey: storageKey)
            }
        }
    }
}
