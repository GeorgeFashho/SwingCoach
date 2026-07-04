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

    private var timeObserver: Any?

    init(videoURL: URL) {
        player = AVPlayer(url: videoURL)
    }

    func startObserving() {
        guard timeObserver == nil else { return }

        Task {
            if let duration = try? await player.currentItem?.asset.load(.duration) {
                self.duration = duration.seconds
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
}
