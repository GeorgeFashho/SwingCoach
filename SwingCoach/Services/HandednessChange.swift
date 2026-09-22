//
//  HandednessChange.swift
//  SwingCoach
//

import SwiftData

/// Applies a new handedness setting to existing sessions. Segmentation
/// tracks the lead wrist, which flips with handedness, so saved phase
/// boundaries and the check results built on them go stale the moment the
/// setting changes: clear them so the next open of each session re-segments
/// with the new lead wrist.
enum HandednessChange {

    static func apply(_ handedness: Handedness,
                      to sessions: [SwingSession],
                      in context: ModelContext) {
        for session in sessions where session.hand != handedness {
            session.handedness = handedness.rawValue
            session.phaseTimestamps = nil
            let stale = session.analysisResults
            session.analysisResults = []
            for result in stale {
                context.delete(result)
            }
        }
    }
}
