//
//  Enums.swift
//  SwingCoach
//

import Foundation

/// The camera angle a swing was recorded from. Each angle enables a
/// different set of biomechanical checks (see plan section 3).
nonisolated enum CameraAngle: String, Codable, CaseIterable, Identifiable {
    case faceOn
    case downTheLine

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .faceOn: "Face-On"
        case .downTheLine: "Down-the-Line"
        }
    }

    var explanation: String {
        switch self {
        case .faceOn:
            "The camera faces your chest, about 8–10 feet away at hand height. Best for seeing side-to-side movement: head stability, hip motion, and shoulder turn."
        case .downTheLine:
            "The camera sits behind you, looking toward the target, about 8–10 feet away at hand height. Best for seeing your posture and how well you keep it during the swing."
        }
    }
}

nonisolated enum Handedness: String, Codable, CaseIterable {
    case right
    case left

    var displayName: String {
        switch self {
        case .right: "Right-handed"
        case .left: "Left-handed"
        }
    }

    /// UserDefaults key for the user's handedness setting (Settings tab).
    static let storageKey = "handedness"

    /// The stored setting, used when creating new sessions. Right-handed
    /// by default, matching the plan's default lead wrist.
    static var stored: Handedness {
        UserDefaults.standard.string(forKey: storageKey).flatMap(Handedness.init) ?? .right
    }
}

/// The club used for a swing, from a fixed standard set (plan:
/// club-tracking ADR). Raw values are the implicit case names, pinned by
/// GolfClubTests' golden test — never rename a case without a data backfill.
nonisolated enum GolfClub: String, Codable, CaseIterable, Identifiable {
    case driver, wood3, wood5, hybrid,
         iron4, iron5, iron6, iron7, iron8, iron9,
         pitchingWedge, gapWedge, sandWedge, lobWedge, putter

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .driver: "Driver"
        case .wood3: "3-Wood"
        case .wood5: "5-Wood"
        case .hybrid: "Hybrid"
        case .iron4: "4-Iron"
        case .iron5: "5-Iron"
        case .iron6: "6-Iron"
        case .iron7: "7-Iron"
        case .iron8: "8-Iron"
        case .iron9: "9-Iron"
        case .pitchingWedge: "Pitching Wedge"
        case .gapWedge: "Gap Wedge"
        case .sandWedge: "Sand Wedge"
        case .lobWedge: "Lob Wedge"
        case .putter: "Putter"
        }
    }

    /// UserDefaults key for the last-used club (Capture screen default).
    static let storageKey = "lastUsedClub"

    /// The stored setting, used to default the capture club picker.
    /// 7-Iron by default, before the user has ever recorded.
    static var storedDefault: GolfClub {
        UserDefaults.standard.string(forKey: storageKey).flatMap(GolfClub.init) ?? .iron7
    }

    static func setStoredDefault(_ club: GolfClub) {
        UserDefaults.standard.set(club.rawValue, forKey: storageKey)
    }
}

/// The swing phases, in order. The boundaries between them are detected by
/// PhaseSegmentationService (plan section 4). "Top of backswing" is the
/// instant between backswing and downswing, not a phase of its own.
nonisolated enum SwingPhase: String, CaseIterable {
    case address
    case backswing
    case downswing
    case followThrough

    var displayName: String {
        switch self {
        case .address: "Address"
        case .backswing: "Backswing"
        case .downswing: "Downswing"
        case .followThrough: "Follow-Through"
        }
    }
}

/// How a check's result reads for the golfer. Always derived from the score
/// via init(score:) so severity and score can never disagree (plan section 3).
nonisolated enum Severity: String {
    case good
    case needsWork
    case critical

    init(score: Double) {
        if score >= Constants.severityGoodFloor {
            self = .good
        } else if score >= Constants.severityNeedsWorkFloor {
            self = .needsWork
        } else {
            self = .critical
        }
    }
}

/// The six biomechanical checks from plan section 3, orchestrated per
/// camera angle by AnalysisEngine.
nonisolated enum CheckName: String, CaseIterable {
    case setupPosture
    case headStability
    case hipSway
    case spineAngle
    case shoulderTurn
    case tempo

    var displayName: String {
        switch self {
        case .setupPosture: "Setup Posture"
        case .headStability: "Head Stability"
        case .hipSway: "Hip Sway"
        case .spineAngle: "Spine Angle"
        case .shoulderTurn: "Shoulder Turn"
        case .tempo: "Tempo"
        }
    }

    /// The camera angle this check can be measured from; nil when it works
    /// from either angle. Must agree with AnalysisEngine's per-angle matrix
    /// (guarded by SkippedCheckTests so the two can never drift).
    var requiredAngle: CameraAngle? {
        switch self {
        case .setupPosture, .spineAngle: .downTheLine
        case .headStability, .hipSway, .shoulderTurn: .faceOn
        case .tempo: nil
        }
    }

    func isApplicable(to angle: CameraAngle) -> Bool {
        requiredAngle == nil || requiredAngle == angle
    }
}
