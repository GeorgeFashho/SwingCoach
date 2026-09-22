//
//  SwingSession.swift
//  SwingCoach
//

import Foundation
import SwiftData

@Model
final class SwingSession {
    var id: UUID
    var date: Date
    var cameraAngle: String          // CameraAngle raw value
    var videoFileName: String        // file name inside Documents/Videos
    var duration: TimeInterval
    var handedness: String           // Handedness raw value
    var notes: String?
    var phaseTimestamps: [Double]?   // [addressEnd, top, impact, followThroughEnd]; nil until segmentation runs
    var club: String?                // GolfClub raw value; nil for pre-existing swings
    var shaftAngleAtAddress: Double? // shaft tilt from vertical (deg) at address; nil until club analysis runs or when unreadable
    var shaftLinePoints: [Double]?   // [gripX, gripY, headX, headY], Vision-normalized; nil when no confident shaft line

    /// Persisted check results from the most recent analysis run.
    @Relationship(deleteRule: .cascade, inverse: \AnalysisResult.session)
    var analysisResults: [AnalysisResult]

    init(cameraAngle: CameraAngle,
         videoFileName: String,
         duration: TimeInterval,
         handedness: Handedness = .right,
         club: GolfClub? = nil,
         shaftAngleAtAddress: Double? = nil,
         shaftLinePoints: [Double]? = nil) {
        self.id = UUID()
        self.date = Date()
        self.cameraAngle = cameraAngle.rawValue
        self.videoFileName = videoFileName
        self.duration = duration
        self.handedness = handedness.rawValue
        self.notes = nil
        self.phaseTimestamps = nil
        self.club = club?.rawValue
        self.shaftAngleAtAddress = shaftAngleAtAddress
        self.shaftLinePoints = shaftLinePoints
        self.analysisResults = []
    }

    var angle: CameraAngle {
        CameraAngle(rawValue: cameraAngle) ?? .faceOn
    }

    var hand: Handedness {
        Handedness(rawValue: handedness) ?? .right
    }

    var golfClub: GolfClub? {
        get { club.flatMap(GolfClub.init(rawValue:)) }
        set { club = newValue?.rawValue }
    }

    var clubLabel: String {
        guard let club else { return "Unspecified" }
        return GolfClub(rawValue: club)?.displayName ?? "Other"
    }

    var videoURL: URL {
        Self.videosDirectory.appendingPathComponent(videoFileName)
    }

    /// Directory inside the app's Documents folder where all swing videos live.
    static var videosDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Videos", isDirectory: true)
    }
}
