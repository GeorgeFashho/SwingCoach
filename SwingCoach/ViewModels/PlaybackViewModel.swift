//
//  PlaybackViewModel.swift
//  SwingCoach
//

import AVFoundation
import CoreGraphics
import Foundation
import Observation
import SwiftData

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
    /// The session's average joint confidence was low — computed once per
    /// pose-frame load (never per view), shown as a warning on the analysis.
    var isLowPoseQuality = false

    // MARK: - Swing analysis state

    /// Detected (or previously saved) phase boundaries; nil until pose data
    /// exists, or when segmentation failed.
    var phases: SwingPhases?
    /// Friendly re-record message shown when segmentation fails.
    var segmentationFailureMessage: String?
    /// Every applicable check's outcome from the latest analysis run.
    var checkOutcomes: [CheckOutcome] = []

    // MARK: - Per-swing coaching (Stage 1)

    /// The cross-session focus area, self-computed from the model context
    /// after each analysis (Stage 2). nil when the context is unavailable or
    /// history is too thin.
    var focusArea: CoachingEngine.FocusAreaResult?

    /// The single worst-scoring check to fix first — non-nil whenever any
    /// check scored, even if it's good (the view decides which card to show).
    var worstCheck: CheckResult? {
        CoachingEngine().worstCheck(from: checkOutcomes)
    }

    /// True when every scored check cleared its good band — drives the
    /// positive coaching card instead of a fault.
    var allChecksGood: Bool {
        CoachingEngine().allChecksGood(from: checkOutcomes)
    }

    /// The drill for the worst check, with the head-drift direction supplied
    /// for headStability so its drill branches lateral vs vertical.
    var worstCheckDrill: String? {
        guard let worst = worstCheck else { return nil }
        var headDisplacement: CGVector?
        if worst.checkName == .headStability, let phases {
            headDisplacement = HeadStabilityCheck.displacement(in: poseFrames ?? [],
                                                               phases: phases)?.vector
        }
        return FeedbackGenerator.drill(for: worst.checkName,
                                       measuredValue: worst.measuredValue,
                                       headDisplacement: headDisplacement)
    }

    private let session: SwingSession
    private let videoURL: URL
    private let poseDetectionService = PoseDetectionService()
    private let segmentationService = PhaseSegmentationService()
    private var timeObserver: Any?

    init(session: SwingSession) {
        self.session = session
        self.videoURL = session.videoURL
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
            if self.poseFrames == nil {
                if let saved = await self.poseDetectionService.loadSavedPoses(for: self.videoURL) {
                    self.poseFrames = PoseSmoothing.smoothed(saved)
                    self.isLowPoseQuality = PoseQuality.isLow(saved)
                    self.updateAnalysis(rawFrames: saved, reuseSavedPhases: true)
                } else {
                    // No saved poses yet (a freshly recorded or never-analyzed
                    // clip): analyze automatically so the user lands straight on
                    // their results instead of hunting for a "Detect Pose" tap.
                    // detectPose() guards against re-entrancy and persists the
                    // result, so this runs once. The manual button remains as a
                    // fallback if detection errors out.
                    self.detectPose()
                }
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
                isLowPoseQuality = PoseQuality.isLow(raw)
                isOverlayEnabled = true
                updateAnalysis(rawFrames: raw, reuseSavedPhases: false)
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

    // MARK: - Swing analysis

    /// Segments the swing (or reuses boundaries saved on the session so
    /// they're computed once, never re-derived), runs every check that
    /// applies to the session's camera angle, and persists the scored
    /// results. Called whenever pose frames become available.
    private func updateAnalysis(rawFrames: [PoseFrameData], reuseSavedPhases: Bool) {
        let result: PhaseSegmentationResult
        if reuseSavedPhases,
           let saved = session.phaseTimestamps,
           let savedPhases = SwingPhases(timestamps: saved) {
            result = .success(savedPhases)
        } else {
            result = segmentationService.segment(frames: rawFrames,
                                                 cameraAngle: session.angle,
                                                 handedness: session.hand)
        }

        switch result {
        case .success(let detected):
            phases = detected
            segmentationFailureMessage = nil
            session.phaseTimestamps = detected.timestamps
            checkOutcomes = AnalysisEngine().analyze(frames: poseFrames ?? [],
                                                     phases: detected,
                                                     cameraAngle: session.angle)
            updateShaftEstimate(addressTimestamp: detected.addressEnd)
        case .failed(let failure):
            phases = nil
            checkOutcomes = []
            segmentationFailureMessage = failure.userMessage
            session.phaseTimestamps = nil
        }
        persistResults()
        refreshFocusArea()
    }

    /// Confidence below which a shaft estimate is discarded rather than
    /// shown as a possibly-wrong number — the UI then shows the "couldn't
    /// read" state instead.
    private static let shaftConfidenceThreshold: Double = 0.5

    /// Estimates the club's shaft angle at address in the background and
    /// stores it on the session once available. ClubShaftService is
    /// @concurrent, so the estimate runs off the main actor; the Task
    /// inherits this method's MainActor context (same pattern as
    /// detectPose() above), so the result is applied back on the main actor
    /// once the await returns. Purely additive: never touches
    /// analysisResults or the checks computed above.
    private func updateShaftEstimate(addressTimestamp: TimeInterval) {
        let cameraAngle = session.angle
        let handedness = session.hand
        Task {
            let estimate = await ClubShaftService().estimateShaftAtAddress(videoURL: videoURL,
                                                                            addressTimestamp: addressTimestamp,
                                                                            cameraAngle: cameraAngle,
                                                                            handedness: handedness)
            if let estimate, estimate.confidence >= Self.shaftConfidenceThreshold {
                session.shaftAngleAtAddress = estimate.angleDegrees
                session.shaftLinePoints = [Double(estimate.gripPoint.x), Double(estimate.gripPoint.y),
                                           Double(estimate.headwardPoint.x), Double(estimate.headwardPoint.y)]
            } else {
                session.shaftAngleAtAddress = nil
                session.shaftLinePoints = nil
            }
        }
    }

    /// Replaces the session's stored AnalysisResult rows with the latest
    /// scored outcomes (empty when segmentation failed).
    private func persistResults() {
        let stale = session.analysisResults
        session.analysisResults = checkOutcomes.compactMap(\.result).map(AnalysisResult.init)
        for old in stale {
            session.modelContext?.delete(old)
        }
    }

    /// Recomputes the cross-session focus area from all persisted results —
    /// self-computed here (HistoryView stays decoupled) using the SAME shared
    /// projection + anchor as ProgressViewModel, so the two never disagree. A
    /// nil model context yields a nil focus area, gracefully.
    func refreshFocusArea() {
        guard let context = session.modelContext else {
            focusArea = nil
            return
        }
        let rows = (try? context.fetch(FetchDescriptor<AnalysisResult>())) ?? []
        let baseline = ProgressBaseline.date
        let samples = rows.compactMap { row -> CoachingEngine.CheckSample? in
            if let baseline, let date = row.session?.date, date < baseline { return nil }
            return CoachingEngine.CheckSample(from: row)
        }
        focusArea = CoachingEngine.focusAreaOverRecentSessions(from: samples)
    }
}
