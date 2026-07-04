//
//  PoseDetectionService.swift
//  SwingCoach
//

import AVFoundation
import Foundation
import ImageIO
import Vision

/// Runs Vision 2D body-pose detection over every frame of a recorded swing.
///
/// Frames are read sequentially with AVAssetReader and each decoded pixel
/// buffer is released (autoreleasepool) before the next one is read — only
/// the extracted joint data is kept. 600 uncompressed 1080p frames would be
/// several GB, so decoded frames must never accumulate in memory.
nonisolated final class PoseDetectionService: Sendable {

    enum PoseDetectionError: LocalizedError {
        case videoNotReadable

        var errorDescription: String? {
            "This video could not be analyzed. Try recording a new swing."
        }
    }

    /// Detects body pose in every frame of the video, saves the raw result
    /// as JSON alongside the video, and returns the frames.
    ///
    /// `progress` (0–1) is called on an arbitrary background thread.
    /// @concurrent: with SWIFT_APPROACHABLE_CONCURRENCY a plain nonisolated
    /// async method would run on the caller's actor — here the main actor —
    /// and stall the UI for the whole detection pass.
    @concurrent
    func detectPoses(in videoURL: URL,
                     progress: @escaping @Sendable (Double) -> Void) async throws -> [PoseFrameData] {
        let asset = AVURLAsset(url: videoURL)
        guard let track = try await asset.loadTracks(withMediaType: .video).first else {
            throw PoseDetectionError.videoNotReadable
        }
        let (preferredTransform, nominalFrameRate) = try await track.load(.preferredTransform, .nominalFrameRate)
        let duration = try await asset.load(.duration)
        let estimatedFrameCount = max(1, Int(duration.seconds * Double(nominalFrameRate)))

        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
        ])
        output.alwaysCopiesSampleData = false
        guard reader.canAdd(output) else { throw PoseDetectionError.videoNotReadable }
        reader.add(output)
        guard reader.startReading() else { throw PoseDetectionError.videoNotReadable }

        let orientation = Self.orientation(from: preferredTransform)
        var frames: [PoseFrameData] = []

        while let sampleBuffer = output.copyNextSampleBuffer() {
            try autoreleasepool {
                guard let pixelBuffer = sampleBuffer.imageBuffer else { return }
                let request = VNDetectHumanBodyPoseRequest()
                let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: orientation)
                try handler.perform([request])
                frames.append(PoseFrameData(frameIndex: frames.count,
                                            timestamp: sampleBuffer.presentationTimeStamp.seconds,
                                            joints: Self.joints(from: request.results?.first)))
            }
            if frames.count % 12 == 0 {
                progress(min(1, Double(frames.count) / Double(estimatedFrameCount)))
            }
        }
        if reader.status == .failed {
            throw reader.error ?? PoseDetectionError.videoNotReadable
        }

        try PoseDataStore.save(frames, forVideo: videoURL)
        progress(1)
        return frames
    }

    /// Loads pose data previously saved for this video, or nil if none
    /// exists (or the file is unreadable — detection can simply re-run).
    @concurrent
    func loadSavedPoses(for videoURL: URL) async -> [PoseFrameData]? {
        guard PoseDataStore.exists(forVideo: videoURL) else { return nil }
        return try? PoseDataStore.load(forVideo: videoURL)
    }

    // MARK: - Helpers

    private static func joints(from observation: VNHumanBodyPoseObservation?) -> [String: JointPoint] {
        guard let observation,
              let recognized = try? observation.recognizedPoints(.all) else { return [:] }
        var joints: [String: JointPoint] = [:]
        for joint in BodyJoint.allCases {
            guard let point = recognized[joint.visionName] else { continue }
            joints[joint.rawValue] = JointPoint(x: point.location.x,
                                                y: point.location.y,
                                                confidence: point.confidence)
        }
        return joints
    }

    /// Vision needs to know how raw buffers rotate to display upright:
    /// portrait phone recordings store landscape buffers with a 90° transform.
    private static func orientation(from transform: CGAffineTransform) -> CGImagePropertyOrientation {
        switch (transform.a, transform.b, transform.c, transform.d) {
        case (0, 1, -1, 0): .right
        case (0, -1, 1, 0): .left
        case (-1, 0, 0, -1): .down
        default: .up
        }
    }
}
