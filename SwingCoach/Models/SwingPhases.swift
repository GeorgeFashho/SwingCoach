//
//  SwingPhases.swift
//  SwingCoach
//

import Foundation

/// The phase boundary timestamps (seconds from the start of the video)
/// produced by PhaseSegmentationService. Address runs from 0 to addressEnd,
/// backswing to top, downswing to impact, follow-through to followThroughEnd.
nonisolated struct SwingPhases {
    let addressEnd: TimeInterval
    let top: TimeInterval
    let impact: TimeInterval
    let followThroughEnd: TimeInterval

    var backswingDuration: TimeInterval { top - addressEnd }
    var downswingDuration: TimeInterval { impact - top }

    /// The array persisted in SwingSession.phaseTimestamps.
    var timestamps: [Double] { [addressEnd, top, impact, followThroughEnd] }

    init(addressEnd: TimeInterval,
         top: TimeInterval,
         impact: TimeInterval,
         followThroughEnd: TimeInterval) {
        self.addressEnd = addressEnd
        self.top = top
        self.impact = impact
        self.followThroughEnd = followThroughEnd
    }

    /// Rebuilds phases from a persisted timestamp array; nil if the array
    /// is malformed (wrong count or out of order).
    init?(timestamps: [Double]) {
        guard timestamps.count == 4,
              timestamps[0] < timestamps[1],
              timestamps[1] < timestamps[2],
              timestamps[2] <= timestamps[3] else { return nil }
        self.init(addressEnd: timestamps[0],
                  top: timestamps[1],
                  impact: timestamps[2],
                  followThroughEnd: timestamps[3])
    }
}
