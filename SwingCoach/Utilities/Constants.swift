//
//  Constants.swift
//  SwingCoach
//

import Foundation

/// Central home for tunable analysis thresholds (plan principle 5:
/// "tunable, not magic"). Adjust these based on real-world recordings.
nonisolated enum Constants {

    /// Joints below this Vision confidence are treated as unreliable:
    /// dimmed in the skeleton overlay and skipped by smoothing.
    static let minimumJointConfidence: Float = 0.3

    /// Sessions whose average joint confidence (all joints, all frames)
    /// falls strictly below this get a "results may be less accurate"
    /// warning on their analysis (plan risk 3: lighting and clothing).
    static let lowPoseQualityAverageConfidence: Float = 0.5

    /// Analyzed sessions needed before the Progress tab draws trend charts;
    /// below this it shows a friendly keep-swinging message instead.
    static let minSessionsForProgress = 3

    /// Longest video that can be imported from the photo library. Keeps
    /// pose processing bounded (~20s at 120fps is ~2,400 frames).
    static let maxImportDuration: TimeInterval = 20

    /// Moving-average window (in frames) used to smooth joint jitter.
    /// 5 frames ≈ 42ms at 120fps — long enough to kill detection noise,
    /// short enough to preserve swing dynamics.
    static let poseSmoothingWindow = 5

    // MARK: - Hands-free capture

    /// Countdown shown after the user taps record, giving them time to walk
    /// into position before recording actually starts (so clips aren't padded
    /// with "walking out" footage). Big count + a haptic per second.
    static let captureCountdownSeconds = 3

    /// Recording auto-stops after this long so a solo user never has to walk
    /// back to tap stop. Generous enough to get set up and swing after the
    /// countdown; a manual stop is always available to end sooner.
    static let maxRecordingDuration: TimeInterval = 12

    // MARK: - Phase segmentation (plan section 4)

    /// Smoothing window for the wrist track before boundary detection.
    /// Down-the-line gets a wider window because the wrist-Y signal is
    /// noisier from behind the golfer.
    static let segmentationSmoothingWindowFaceOn = 5
    static let segmentationSmoothingWindowDownTheLine = 7

    /// Wrist speed (in shoulder-widths per second) that counts as the swing
    /// starting; below this the golfer is still standing at address.
    static let motionOnsetVelocity: Double = 0.8

    /// Consecutive fast samples required before motion counts as onset, so
    /// a single noisy frame can't start the swing.
    static let motionOnsetSustainedSamples = 3

    /// Boundary plausibility floors: implausibly short phases mean the
    /// heuristic latched onto noise, so segmentation fails instead of
    /// feeding garbage boundaries to the checks.
    static let minBackswingDuration: TimeInterval = 0.2
    static let minDownswingDuration: TimeInterval = 0.08

    /// The wrist must rise at least this fraction of the golfer's torso
    /// length (neck→root) for the motion to count as a real backswing;
    /// smaller rise-and-return movements are waggles and are skipped.
    /// Torso-relative because apparent shoulder width collapses to nearly
    /// zero down-the-line, but torso length reads the same from both
    /// angles. Real swings in tuning recordings rose 0.96–1.85×torso;
    /// waggles stayed under 0.25×torso.
    static let minTopWristRiseTorsoFactor: Double = 0.5

    /// The wrist-height reference for "back at address height" is averaged
    /// over the still samples in this window just before motion onset — a
    /// local baseline, so earlier fidgeting can't skew it.
    static let addressBaselineWindow: TimeInterval = 0.75

    /// Fewer still samples than this before an onset candidate means there
    /// was no stable address stance to measure from — the candidate is
    /// junk (e.g. the recording started mid-movement) and is skipped.
    static let minAddressBaselineSamples = 5

    /// The swing has "come back down" once the wrist has given back all
    /// but this fraction of its rise above address; impact is the bottom
    /// of that descent. A fraction of the rise itself (not a
    /// shoulder-width multiple) because down-the-line the shoulders point
    /// at the camera, and any tolerance built on the foreshortened
    /// shoulder width collapses to nearly zero.
    static let impactReturnFraction: Double = 0.2

    /// Fewer confident lead-wrist samples than this → insufficient data.
    static let minimumSegmentationSamples = 30

    // MARK: - Scoring (plan section 3, "Scoring Formula")

    /// Severity cutoff for "good"; also the score at every good-band edge.
    static let severityGoodFloor: Double = 70

    /// Severity cutoff for "needs work"; also the score at every critical limit.
    static let severityNeedsWorkFloor: Double = 30

    // MARK: - Check thresholds (plan section 3)

    /// Tempo: backswing-to-downswing time ratio. ~3:1 is ideal.
    static let tempoGoodBand: ClosedRange<Double> = 2.5...3.5
    static let tempoCriticalLow: Double = 2.0
    static let tempoCriticalHigh: Double = 4.5

    /// Head stability: nose drift from address, in shoulder-widths.
    static let headStabilityGoodBand: ClosedRange<Double> = 0.0...0.15
    static let headStabilityCriticalLimit: Double = 0.30

    /// Fewer confident nose samples than this → insufficient data (nil result).
    static let minHeadStabilitySamples = 5

    /// Setup posture: forward spine tilt from vertical at address, degrees.
    static let setupPostureGoodBand: ClosedRange<Double> = 30...45
    static let setupPostureCriticalLow: Double = 20
    static let setupPostureCriticalHigh: Double = 55

    /// Hip sway: lateral hip-midpoint shift address → top, in stance-widths.
    static let hipSwayGoodBand: ClosedRange<Double> = 0.0...0.10
    static let hipSwayCriticalLimit: Double = 0.20

    /// Spine angle maintenance: degrees of address tilt lost by impact
    /// (positive = stood up; early extension).
    static let spineAngleLossGoodBand: ClosedRange<Double> = 0.0...5.0
    static let spineAngleLossCriticalLimit: Double = 12.0

    /// Shoulder turn: apparent shoulder width at the top ÷ width at address.
    /// Smaller = more turn, so lower is better.
    static let shoulderTurnGoodBand: ClosedRange<Double> = 0.0...0.70
    static let shoulderTurnCriticalLimit: Double = 0.85

    /// Half-width of the sampling window checks place around a phase
    /// boundary (top, impact) — ±50ms ≈ 12 frames at 120fps. Shoulder turn
    /// keeps this tight window: at the top of the backswing the trail shoulder
    /// is occluded, and a wider window pulls in bad detections (apparent width
    /// larger than at address), so insufficientData stays the honest answer.
    static let checkBoundarySampleWindow: TimeInterval = 0.05

    /// Wider boundary window for the checks that read reliably-visible joints
    /// at the boundary — spine tilt at impact, hip midpoint at the top. The
    /// ±50ms window is only ~3 frames at 30fps (below minCheckSamples), so on
    /// 30fps Photos imports those checks never scored; ±100ms gives ~7 frames.
    /// Validated against the exported clips (tools/replay): spine angle and hip
    /// sway produce sensible, discriminating values at this width.
    static let checkBoundarySampleWindowWide: TimeInterval = 0.10

    /// Fewer confident samples than this in a check's measurement window →
    /// insufficient data (nil result). Notably the shoulder-turn occlusion
    /// fallback: never score rotation from low-confidence keypoints.
    static let minCheckSamples = 5

    // MARK: - Cross-session focus area (plan Stage 2)

    /// How many of the most recent sessions the focus area is computed over.
    static let focusAreaSessionWindow = 5

    /// A check needs at least this many data points in the window to qualify
    /// as a focus area — filters out checks with sparse history (risk R4).
    static let focusAreaMinDataPoints = 3

    /// Hysteresis + trend dead zone (mean-score points): the focus area only
    /// switches when another check's mean is more than this much worse, and a
    /// trend only reads improving/declining when the half-split means differ
    /// by more than this — keeps the focus area from flip-flopping on noise.
    static let focusAreaTrendThreshold: Double = 5.0
}
