//
//  PlaybackViewModel.swift
//  SwingCoach
//

import AVFoundation
import Foundation
import Observation

@Observable
@MainActor
final class PlaybackViewModel {
    let player: AVPlayer

    var isPlaying = false
    var currentTime: Double = 0
    var duration: Double = 0
    var playbackRate: Float = 1.0
    var isScrubbing = false

    static let availableRates: [Float] = [0.25, 0.5, 1.0]

    // MARK: - Pose overlay state

    /// Smoothed pose frames for display; nil until detected or loaded.
    var poseFrames: [PoseFrameData]?
    var isOverlayEnabled = true
    var isDetectingPose = false
    var detectionProgress: Double = 0
    var detectionErrorMessage: String?
    /// The video's display size (naturalSize with preferredTransform
    /// applied) — needed to aspect-fit the overlay onto the player.
    var videoDisplaySize: CGSize = .zero

    private let videoURL: URL
    private let poseDetectionService = PoseDetectionService()
    private var timeObserver: Any?

    init(videoURL: URL) {
        self.videoURL = videoURL
        player = AVPlayer(url: videoURL)
    }

    func startObserving() {
        guard timeObserver == nil else { return }

        Task {
            if let duration = try? await player.currentItem?.asset.load(.duration) {
                self.duration = duration.seconds
            }
            if let track = try? await player.currentItem?.asset.loadTracks(withMediaType: .video).first,
               let (naturalSize, transform) = try? await track.load(.naturalSize, .preferredTransform) {
                self.videoDisplaySize = CoordinateTransform.orientedSize(naturalSize: naturalSize,
                                                                         preferredTransform: transform)
            }
            if self.poseFrames == nil,
               let saved = await self.poseDetectionService.loadSavedPoses(for: self.videoURL) {
                self.poseFrames = PoseSmoothing.smoothed(saved)
            }
        }

        // 1/60s updates keep the scrubber smooth during slow-motion playback.
        let interval = CMTime(value: 1, timescale: 60)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            MainActor.assumeIsolated {
                guard let self, !self.isScrubbing else { return }
                self.currentTime = time.seconds
                if self.duration > 0, time.seconds >= self.duration {
                    self.isPlaying = false
                }
            }
        }
    }

    func stopObserving() {
        if let timeObserver {
            player.removeTimeObserver(timeObserver)
            self.timeObserver = nil
        }
        player.pause()
        isPlaying = false
    }

    func togglePlayback() {
        if isPlaying {
            player.pause()
            isPlaying = false
        } else {
            // Restart from the beginning if playback already reached the end.
            if duration > 0, currentTime >= duration - 0.05 {
                player.seek(to: .zero)
                currentTime = 0
            }
            player.rate = playbackRate
            isPlaying = true
        }
    }

    func setRate(_ rate: Float) {
        playbackRate = rate
        if isPlaying {
            player.rate = rate
        }
    }

    func seek(to seconds: Double) {
        currentTime = seconds
        let time = CMTime(seconds: seconds, preferredTimescale: 600)
        player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    // MARK: - Pose detection

    /// Runs pose detection over the whole video in the background, saving
    /// the result alongside the video and enabling the skeleton overlay.
    func detectPose() {
        guard !isDetectingPose else { return }
        isDetectingPose = true
        detectionProgress = 0
        detectionErrorMessage = nil
        Task {
            do {
                let raw = try await poseDetectionService.detectPoses(in: videoURL) { value in
                    Task { @MainActor in self.detectionProgress = value }
                }
                poseFrames = PoseSmoothing.smoothed(raw)
                isOverlayEnabled = true
            } catch {
                detectionErrorMessage = error.localizedDescription
            }
            isDetectingPose = false
        }
    }

    /// The pose frame nearest to the current playback time, or nil when the
    /// overlay is hidden or no pose data exists yet.
    var currentPoseFrame: PoseFrameData? {
        guard isOverlayEnabled, let poseFrames, !poseFrames.isEmpty else { return nil }
        return Self.nearestFrame(in: poseFrames, to: currentTime)
    }

    /// Binary search for the frame whose timestamp is closest to `time`
    /// (frames are in presentation order, so timestamps are ascending).
    private static func nearestFrame(in frames: [PoseFrameData], to time: Double) -> PoseFrameData {
        var low = 0
        var high = frames.count - 1
        while low < high {
            let mid = (low + high) / 2
            if frames[mid].timestamp < time {
                low = mid + 1
            } else {
                high = mid
            }
        }
        // `low` is the first frame at/after `time`; its predecessor may be closer.
        if low > 0, abs(frames[low - 1].timestamp - time) < abs(frames[low].timestamp - time) {
            return frames[low - 1]
        }
        return frames[low]
    }
}
