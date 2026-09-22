//
//  PhaseSegmentationService.swift
//  SwingCoach
//

import CoreGraphics
import Foundation
import os

/// Why segmentation could not produce usable phase boundaries.
nonisolated enum PhaseSegmentationFailure: Equatable {
    /// Too few frames with a confidently detected lead wrist or shoulders.
    case insufficientPoseData
    /// The wrist never moved fast enough to look like a swing.
    case noSwingDetected
    /// Boundaries were found but fail the plausibility rules (phase
    /// durations, wrist displacement at the top).
    case implausibleBoundaries

    /// Four of the six checks depend on correct phases, so confidently
    /// wrong feedback is worse than no feedback — ask for a re-record.
    var userMessage: String {
        "Couldn't analyze this swing — try re-recording. Make sure your whole body is visible and well lit."
    }
}

nonisolated enum PhaseSegmentationResult {
    case success(SwingPhases)
    case failed(PhaseSegmentationFailure)

    var phases: SwingPhases? {
        if case .success(let phases) = self { phases } else { nil }
    }

    var failure: PhaseSegmentationFailure? {
        if case .failed(let failure) = self { failure } else { nil }
    }
}

/// Detects the swing's phase boundaries from the lead wrist's vertical
/// motion (plan section 4): smooth the wrist track, find the motion onset
/// (address ends), the highest wrist point (top of backswing), and the
/// return to address height (impact). All displacements are measured in
/// shoulder-widths so thresholds are independent of camera distance.
nonisolated struct PhaseSegmentationService {

    /// Diagnostic trail for tuning thresholds against real recordings —
    /// filter the console for "Segmentation" while running from Xcode.
    private static let log = Logger(subsystem: "SwingCoach", category: "Segmentation")

    private struct WristSample {
        let timestamp: TimeInterval
        let y: CGFloat
    }

    func segment(frames: [PoseFrameData],
                 cameraAngle: CameraAngle,
                 handedness: Handedness) -> PhaseSegmentationResult {
        let window = cameraAngle == .downTheLine
            ? Constants.segmentationSmoothingWindowDownTheLine
            : Constants.segmentationSmoothingWindowFaceOn
        let smoothed = PoseSmoothing.smoothed(frames, window: window)

        // Right-handed golfers lead with the left wrist, and vice versa.
        let leadWrist: BodyJoint = handedness == .right ? .leftWrist : .rightWrist
        let samples: [WristSample] = smoothed.compactMap { frame in
            guard let wrist = frame.joint(leadWrist),
                  wrist.confidence >= Constants.minimumJointConfidence else { return nil }
            return WristSample(timestamp: frame.timestamp, y: wrist.y)
        }
        // Scale references as medians over the WHOLE clip, so junk at the
        // start (walking into frame, a hand near the lens) can't poison
        // them. Shoulder width normalizes velocities; torso length (which
        // doesn't foreshorten down-the-line the way shoulder width does)
        // sets the rise floor that separates real backswings from waggles.
        let clipEnd = smoothed.last?.timestamp ?? 0
        let shoulderWidth = PoseFrameData.medianJointDistance(
            in: smoothed,
            between: .leftShoulder, and: .rightShoulder,
            during: 0...clipEnd)
        let torsoLength = PoseFrameData.medianJointDistance(
            in: smoothed,
            between: .neck, and: .root,
            during: 0...clipEnd)
        guard samples.count >= Constants.minimumSegmentationSamples,
              let shoulderWidth, let torsoLength else {
            Self.log.warning("insufficientPoseData: \(samples.count)/\(frames.count) confident \(leadWrist.rawValue) samples (need \(Constants.minimumSegmentationSamples)), shoulderWidth=\(shoulderWidth.map { "\($0)" } ?? "nil"), torso=\(torsoLength.map { "\($0)" } ?? "nil")")
            return .failed(.insufficientPoseData)
        }

        // Wrist vertical velocity in shoulder-widths per second, by central
        // difference (robust to occasional dropped low-confidence frames).
        let velocities = samples.indices.map { index -> Double in
            let earlier = samples[max(samples.startIndex, index - 1)]
            let later = samples[min(samples.endIndex - 1, index + 1)]
            let dt = later.timestamp - earlier.timestamp
            guard dt > 0 else { return 0 }
            return Double(later.y - earlier.y) / dt / Double(shoulderWidth)
        }

        let riseFloor = torsoLength * CGFloat(Constants.minTopWristRiseTorsoFactor)

        // Scan onset candidates in order. Each candidate must have a stable
        // address stance just before it, and its motion must rise at least
        // riseFloor before returning — otherwise it's a waggle (or junk)
        // and scanning resumes after it. Real recordings routinely contain
        // several waggles and setup adjustments before the actual swing.
        var scanFrom = samples.startIndex
        candidates: while true {
            var onsetIndex: Int?
            var runLength = 0
            for index in scanFrom..<samples.endIndex {
                if abs(velocities[index]) >= Constants.motionOnsetVelocity {
                    runLength += 1
                    if runLength == Constants.motionOnsetSustainedSamples {
                        onsetIndex = index - runLength + 1
                        break
                    }
                } else {
                    runLength = 0
                }
            }
            guard let onsetIndex else {
                let maxSpeed = velocities.map(abs).max() ?? 0
                Self.log.warning("noSwingDetected: no onset candidate led to a real backswing (peak wrist speed \(maxSpeed, format: .fixed(precision: 2)) sw/s, riseFloor \(riseFloor, format: .fixed(precision: 3)), samples=\(samples.count))")
                return .failed(.noSwingDetected)
            }

            // Local address baseline: the still samples just before onset.
            // Not the whole prefix — earlier movement would skew it.
            let onsetTime = samples[onsetIndex].timestamp
            let baseline = (samples.startIndex..<onsetIndex).filter { index in
                samples[index].timestamp >= onsetTime - Constants.addressBaselineWindow
                    && abs(velocities[index]) < Constants.motionOnsetVelocity
            }
            guard baseline.count >= Constants.minAddressBaselineSamples else {
                Self.log.debug("candidate at \(onsetTime, format: .fixed(precision: 2))s skipped: no stable address before onset")
                scanFrom = onsetIndex + 1
                while scanFrom < samples.endIndex,
                      abs(velocities[scanFrom]) >= Constants.motionOnsetVelocity {
                    scanFrom += 1
                }
                continue
            }
            let addressY = baseline.reduce(CGFloat.zero) { $0 + samples[$1].y } / CGFloat(baseline.count)

            // Walk forward tracking the highest wrist point so far (Vision's
            // normalized Y axis points up). The top of the backswing is the
            // running max at the moment the wrist first gives back most of
            // its rise — a global max would latch onto the follow-through
            // finish, where the hands are often held higher than the top of
            // the backswing was. If the motion returns to address height
            // without ever reaching riseFloor, it was a waggle: abandon the
            // candidate and keep scanning.
            var topIndex = onsetIndex
            var crossingIndex: Int?
            var abandonedIndex: Int?
            for index in samples.indices[(onsetIndex + 1)...] {
                if samples[index].y > samples[topIndex].y {
                    topIndex = index
                    continue
                }
                let rise = samples[topIndex].y - addressY
                if rise < riseFloor {
                    if samples[index].y <= addressY + max(rise, 0) * CGFloat(Constants.impactReturnFraction) {
                        abandonedIndex = index
                        break
                    }
                    continue
                }
                if samples[index].y <= addressY + rise * CGFloat(Constants.impactReturnFraction) {
                    crossingIndex = index
                    break
                }
            }
            if let abandonedIndex {
                Self.log.debug("candidate at \(onsetTime, format: .fixed(precision: 2))s skipped: waggle (rise \(samples[topIndex].y - addressY, format: .fixed(precision: 3)) < floor \(riseFloor, format: .fixed(precision: 3)))")
                scanFrom = abandonedIndex
                continue
            }
            guard let crossingIndex else {
                let rise = samples[topIndex].y - addressY
                Self.log.warning("implausibleBoundaries: wrist rose \(rise, format: .fixed(precision: 3)) (floor \(riseFloor, format: .fixed(precision: 3))) to top at \(samples[topIndex].timestamp, format: .fixed(precision: 2))s but never gave back \(Int((1 - Constants.impactReturnFraction) * 100))% of the rise")
                return .failed(.implausibleBoundaries)
            }

            // Impact = the bottom of that descent.
            var impactIndex = crossingIndex
            while impactIndex + 1 < samples.endIndex,
                  samples[impactIndex + 1].y < samples[impactIndex].y {
                impactIndex += 1
            }

            let phases = SwingPhases(addressEnd: samples[onsetIndex].timestamp,
                                     top: samples[topIndex].timestamp,
                                     impact: samples[impactIndex].timestamp,
                                     followThroughEnd: samples[samples.endIndex - 1].timestamp)

            // Plausibility rules (plan section 4, "Boundary validation").
            // A real-sized rise with implausible timing is a malformed
            // detection, not a waggle — fail rather than risk latching
            // onto something later that isn't the swing either.
            guard phases.backswingDuration > Constants.minBackswingDuration,
                  phases.downswingDuration > Constants.minDownswingDuration else {
                Self.log.warning("implausibleBoundaries: backswing \(phases.backswingDuration, format: .fixed(precision: 2))s (min \(Constants.minBackswingDuration)), downswing \(phases.downswingDuration, format: .fixed(precision: 3))s (min \(Constants.minDownswingDuration)) — boundaries addressEnd=\(phases.addressEnd, format: .fixed(precision: 2)) top=\(phases.top, format: .fixed(precision: 2)) impact=\(phases.impact, format: .fixed(precision: 2))")
                return .failed(.implausibleBoundaries)
            }

            Self.log.info("success: addressEnd=\(phases.addressEnd, format: .fixed(precision: 2)) top=\(phases.top, format: .fixed(precision: 2)) impact=\(phases.impact, format: .fixed(precision: 2)) end=\(phases.followThroughEnd, format: .fixed(precision: 2)), rise \(samples[topIndex].y - addressY, format: .fixed(precision: 3)) (floor \(riseFloor, format: .fixed(precision: 3)))")
            return .success(phases)
        }
    }
}
