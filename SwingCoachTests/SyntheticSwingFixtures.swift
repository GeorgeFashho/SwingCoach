//
//  SyntheticSwingFixtures.swift
//  SwingCoachTests
//

import CoreGraphics
@testable import SwingCoach

/// Hand-crafted pose sequences with mathematically known properties (plan
/// section 6, step 0): a 120fps swing whose true phase boundaries, tempo
/// ratio, head movement, hip sway, shoulder turn, and spine tilt are chosen
/// exactly, so tests can assert exact scores without any real recordings.
///
/// Exactness rules (the Phase 3a lesson): every value on the path from
/// fixture to an asserted band-edge score is dyadic or an exact
/// power-of-two scaling. Hence the left shoulder sits at x = 0 (apparent
/// width = right shoulder's x, no subtraction rounding), the two hips are
/// coincident (midpoint == the value itself), and shoulder/stance widths
/// are powers of two. Spine tilts travel through acos, which is never
/// exact — angle tests assert with tolerances, away from severity cutoffs.
nonisolated enum SwingFixtures {

    static let frameRate: Double = 120
    /// A power of two, so drift × width ÷ width round-trips exactly and
    /// boundary tests (e.g. drift of exactly 0.30 shoulder-widths) don't
    /// land a rounding error past the critical limit.
    static let shoulderWidth: CGFloat = 0.125
    /// Ankle spacing — also a power of two so hip sway in stance-widths
    /// round-trips exactly.
    static let stanceWidth: CGFloat = 0.25
    static let addressWristY: CGFloat = 0.35
    /// 2.4 shoulder-widths of wrist rise from address to the top.
    static let wristRise: CGFloat = 0.30
    static let followThroughRise: CGFloat = 0.20
    /// x = 0 so a horizontal drift d gives nose.x == d with no addition
    /// rounding (0 + d is exact), and y = 0.75 (dyadic) so the address
    /// average is exact — boundary drifts like exactly 0.15 shoulder-widths
    /// must not pick up ULP errors on their way through the check.
    static let addressNose = CGPoint(x: 0, y: 0.75)
    /// Band-center setup tilt: scores ~100 so engine tests read "good".
    static let defaultSpineTilt = 37.5

    // True boundaries of the standard fixture swing (seconds). Backswing
    // 0.75s / downswing 0.25s = an exact 3:1 tempo.
    static let addressDuration = 0.5
    static let backswingDuration = 0.75
    static let standardDownswingDuration = 0.25
    static let followThroughDuration = 0.4

    /// Everything that varies frame to frame. Defaults are the address
    /// state of a well-formed swing.
    private struct FrameState {
        var wristY = addressWristY
        var nose = addressNose
        var noseConfidence: Float = 0.9
        var spineTiltDegrees = defaultSpineTilt
        var hipX: CGFloat = 0
        var apparentShoulderWidth = shoulderWidth
        var trailShoulderConfidence: Float = 0.9
    }

    /// A clean swing with cosine-eased wrist motion. Optionally drifts the
    /// nose or hips by an exact fraction (held as a plateau during the
    /// swing so the measured displacement is exact), narrows the apparent
    /// shoulder width to an exact ratio around the top, degrades the nose
    /// or trail-shoulder confidence, and changes the spine tilt between
    /// address and impact.
    static func normalSwing(downswingDuration: Double = standardDownswingDuration,
                            noseDriftInShoulderWidths: CGFloat = 0,
                            noseDriftIsVertical: Bool = false,
                            noseConfidence: Float = 0.9,
                            spineTiltAtAddress: Double = defaultSpineTilt,
                            spineTiltAtImpact: Double = defaultSpineTilt,
                            hipSwayInStanceWidths: CGFloat = 0,
                            shoulderTurnRatio: CGFloat = 0.5,
                            trailShoulderConfidenceAtTop: Float = 0.9) -> [PoseFrameData] {
        let topTime = addressDuration + backswingDuration
        let impactTime = topTime + downswingDuration
        let totalDuration = impactTime + followThroughDuration
        // Generously wider than the checks' ±checkBoundarySampleWindow so
        // the plateau still covers the window when the end-to-end tests
        // use detected (not known-true) boundaries.
        let shoulderPlateau = (topTime - 0.1)...(topTime + 0.1)

        return frames(totalDuration: totalDuration) { t in
            var state = FrameState()

            switch t {
            case ..<addressDuration:
                state.wristY = addressWristY
            case ..<topTime:
                let progress = (t - addressDuration) / backswingDuration
                state.wristY = addressWristY + wristRise * CGFloat(1 - cos(.pi * progress)) / 2
            case ..<impactTime:
                let progress = (t - topTime) / downswingDuration
                state.wristY = addressWristY + wristRise * CGFloat(1 + cos(.pi * progress)) / 2
            default:
                let progress = min(1, (t - impactTime) / followThroughDuration)
                state.wristY = addressWristY + followThroughRise * CGFloat(1 - cos(.pi * progress)) / 2
            }

            // Nose and hip plateaus span the middle of the swing, well
            // clear of the address frames used as reference positions.
            if t > addressDuration + 0.2, t <= impactTime {
                let drift = noseDriftInShoulderWidths * shoulderWidth
                if noseDriftIsVertical {
                    state.nose.y += drift
                } else {
                    state.nose.x += drift
                }
                state.hipX = hipSwayInStanceWidths * stanceWidth
            }

            if shoulderPlateau.contains(t) {
                state.apparentShoulderWidth = shoulderTurnRatio * shoulderWidth
                state.trailShoulderConfidence = trailShoulderConfidenceAtTop
            }

            state.spineTiltDegrees = t <= topTime ? spineTiltAtAddress : spineTiltAtImpact
            state.noseConfidence = noseConfidence
            return state
        }
    }

    /// A golfer who stands at address and never swings.
    static func noMotion() -> [PoseFrameData] {
        frames(totalDuration: 2.0) { _ in FrameState() }
    }

    /// Wrist rise of a waggle: 0.5 shoulder-widths (dyadic) — enough to
    /// trip the onset velocity threshold, far below the torso-scaled rise
    /// floor (0.15625×torso vs the 0.5×torso minimum).
    static let waggleRise: CGFloat = 0.0625

    /// One smooth up-and-down waggle of the wrists over `duration`.
    private static func waggleY(progress: Double) -> CGFloat {
        addressWristY + waggleRise * CGFloat(1 - cos(2 * .pi * progress)) / 2
    }

    /// Address, one waggle, a still pause, then the standard swing — the
    /// segmenter must skip the waggle and land on the real swing.
    /// True boundaries: addressEnd 2.0, top 2.75, impact 3.0.
    static func waggleThenSwing() -> [PoseFrameData] {
        let swingStart = 2.0
        let topTime = swingStart + backswingDuration
        let impactTime = topTime + standardDownswingDuration
        return frames(totalDuration: impactTime + followThroughDuration) { t in
            var state = FrameState()
            switch t {
            case ..<0.5:
                state.wristY = addressWristY
            case ..<1.0:
                state.wristY = waggleY(progress: (t - 0.5) / 0.5)
            case ..<swingStart:
                state.wristY = addressWristY
            case ..<topTime:
                let progress = (t - swingStart) / backswingDuration
                state.wristY = addressWristY + wristRise * CGFloat(1 - cos(.pi * progress)) / 2
            case ..<impactTime:
                let progress = (t - topTime) / standardDownswingDuration
                state.wristY = addressWristY + wristRise * CGFloat(1 + cos(.pi * progress)) / 2
            default:
                let progress = min(1, (t - impactTime) / followThroughDuration)
                state.wristY = addressWristY + followThroughRise * CGFloat(1 - cos(.pi * progress)) / 2
            }
            return state
        }
    }

    /// The clip starts mid-movement (wrist descending fast, as when the
    /// recording catches the golfer still getting set), then a still
    /// address, then the standard swing. The moving start has no stable
    /// address before it, so the segmenter must skip it.
    /// True boundaries: addressEnd 1.5, top 2.25, impact 2.5.
    static func movingStartThenSwing() -> [PoseFrameData] {
        let swingStart = 1.5
        let topTime = swingStart + backswingDuration
        let impactTime = topTime + standardDownswingDuration
        return frames(totalDuration: impactTime + followThroughDuration) { t in
            var state = FrameState()
            switch t {
            case ..<0.5:
                let progress = t / 0.5
                state.wristY = addressWristY + 0.4 * CGFloat(1 + cos(.pi * progress)) / 2
            case ..<swingStart:
                state.wristY = addressWristY
            case ..<topTime:
                let progress = (t - swingStart) / backswingDuration
                state.wristY = addressWristY + wristRise * CGFloat(1 - cos(.pi * progress)) / 2
            case ..<impactTime:
                let progress = (t - topTime) / standardDownswingDuration
                state.wristY = addressWristY + wristRise * CGFloat(1 + cos(.pi * progress)) / 2
            default:
                let progress = min(1, (t - impactTime) / followThroughDuration)
                state.wristY = addressWristY + followThroughRise * CGFloat(1 - cos(.pi * progress)) / 2
            }
            return state
        }
    }

    /// Address, one waggle, address again — motion that trips the velocity
    /// threshold but never makes a real backswing. Not a swing.
    static func waggleOnly() -> [PoseFrameData] {
        frames(totalDuration: 1.5) { t in
            var state = FrameState()
            if (0.5..<1.0).contains(t) {
                state.wristY = waggleY(progress: (t - 0.5) / 0.5)
            }
            return state
        }
    }

    /// The standard swing but with every joint below the confidence floor.
    static func lowConfidence() -> [PoseFrameData] {
        normalSwing().map { frame in
            PoseFrameData(frameIndex: frame.frameIndex,
                          timestamp: frame.timestamp,
                          joints: frame.joints.mapValues {
                              JointPoint(x: $0.x, y: $0.y, confidence: 0.1)
                          })
        }
    }

    /// The phase boundaries the standard fixture is built around, for tests
    /// that exercise checks without running segmentation first.
    static func knownPhases() -> SwingPhases {
        let topTime = addressDuration + backswingDuration
        let impactTime = topTime + standardDownswingDuration
        return SwingPhases(addressEnd: addressDuration,
                           top: topTime,
                           impact: impactTime,
                           followThroughEnd: impactTime + followThroughDuration)
    }

    private static func frames(
        totalDuration: Double,
        sample: (Double) -> FrameState
    ) -> [PoseFrameData] {
        let frameCount = Int(totalDuration * frameRate)
        return (0..<frameCount).map { index in
            let t = Double(index) / frameRate
            let state = sample(t)
            let tilt = state.spineTiltDegrees * .pi / 180
            let joints: [String: JointPoint] = [
                BodyJoint.nose.rawValue:
                    JointPoint(x: state.nose.x, y: state.nose.y, confidence: state.noseConfidence),
                // Left shoulder at x = 0 so the apparent width equals the
                // right shoulder's x exactly (no subtraction rounding).
                BodyJoint.leftShoulder.rawValue:
                    JointPoint(x: 0, y: 0.6, confidence: 0.9),
                BodyJoint.rightShoulder.rawValue:
                    JointPoint(x: state.apparentShoulderWidth, y: 0.6,
                               confidence: state.trailShoulderConfidence),
                BodyJoint.leftWrist.rawValue:
                    JointPoint(x: 0.45, y: state.wristY, confidence: 0.9),
                BodyJoint.rightWrist.rawValue:
                    JointPoint(x: 0.55, y: state.wristY, confidence: 0.9),
                BodyJoint.neck.rawValue:
                    JointPoint(x: 0.5 + 0.4 * CGFloat(sin(tilt)),
                               y: 0.2 + 0.4 * CGFloat(cos(tilt)),
                               confidence: 0.9),
                BodyJoint.root.rawValue:
                    JointPoint(x: 0.5, y: 0.2, confidence: 0.9),
                // Coincident hips: the checks only use the midpoint, and
                // (x + x) / 2 == x exactly for any x, so a sway of exactly
                // 0.10 stance-widths survives to the band edge untouched.
                BodyJoint.leftHip.rawValue:
                    JointPoint(x: state.hipX, y: 0.45, confidence: 0.9),
                BodyJoint.rightHip.rawValue:
                    JointPoint(x: state.hipX, y: 0.45, confidence: 0.9),
                BodyJoint.leftAnkle.rawValue:
                    JointPoint(x: -0.125, y: 0.1, confidence: 0.9),
                BodyJoint.rightAnkle.rawValue:
                    JointPoint(x: 0.125, y: 0.1, confidence: 0.9),
            ]
            return PoseFrameData(frameIndex: index, timestamp: t, joints: joints)
        }
    }
}
