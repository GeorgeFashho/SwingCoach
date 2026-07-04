//
//  PoseDataStore.swift
//  SwingCoach
//

import Foundation

/// Saves and loads a session's detected pose frames as a JSON file next to
/// its video (Documents/Videos/<video>.pose.json).
nonisolated enum PoseDataStore {

    /// The pose JSON URL for a given video file URL.
    static func poseDataURL(forVideo videoURL: URL) -> URL {
        videoURL.deletingPathExtension().appendingPathExtension("pose.json")
    }

    static func exists(forVideo videoURL: URL) -> Bool {
        FileManager.default.fileExists(atPath: poseDataURL(forVideo: videoURL).path)
    }

    static func save(_ frames: [PoseFrameData], forVideo videoURL: URL) throws {
        let data = try JSONEncoder().encode(frames)
        try data.write(to: poseDataURL(forVideo: videoURL), options: .atomic)
    }

    static func load(forVideo videoURL: URL) throws -> [PoseFrameData] {
        let data = try Data(contentsOf: poseDataURL(forVideo: videoURL))
        return try JSONDecoder().decode([PoseFrameData].self, from: data)
    }
}
