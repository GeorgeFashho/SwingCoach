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

    init(cameraAngle: CameraAngle,
         videoFileName: String,
         duration: TimeInterval,
         handedness: Handedness = .right) {
        self.id = UUID()
        self.date = Date()
        self.cameraAngle = cameraAngle.rawValue
        self.videoFileName = videoFileName
        self.duration = duration
        self.handedness = handedness.rawValue
        self.notes = nil
        self.phaseTimestamps = nil
    }

    var angle: CameraAngle {
        CameraAngle(rawValue: cameraAngle) ?? .faceOn
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
