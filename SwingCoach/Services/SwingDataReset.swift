import SwiftData

/// Factory reset: delete every swing — video file, pose sidecar, and DB row —
/// by applying SessionDeletion over all sessions (mirrors HandednessChange's
/// bulk pattern), then clear the progress baseline and focus-area anchor.
/// Clearing the anchor is persisted-key hygiene: a "delete everything" action
/// should not leave an orphan previousFocusArea string in UserDefaults. (It is
/// harmless if left — the next empty reload overwrites it — but a factory reset
/// should be clean.)
enum SwingDataReset {
    static func deleteAllSwings(_ sessions: [SwingSession], in context: ModelContext) {
        for session in sessions {
            SessionDeletion.delete(session, in: context)
        }
        ProgressBaseline.date = nil
        CoachingEngine.storedPreviousFocusArea = nil
    }
}
