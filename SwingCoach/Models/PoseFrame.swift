//
//  PoseFrame.swift
//  SwingCoach
//

import CoreGraphics
import Foundation
import Vision

/// One video frame's worth of detected body pose. Pose data is saved as a
/// JSON file next to the video (see PoseDataStore), not in SwiftData — a
/// 5-second swing at 120fps is ~600 frames × 19 joints, which would bloat
/// the database.
///
/// nonisolated: pose values are produced on a background thread by
/// PoseDetectionService, so they must not inherit the project's default
/// MainActor isolation.
nonisolated struct PoseFrameData: Codable {
    let frameIndex: Int
    let timestamp: TimeInterval
    let joints: [String: JointPoint]   // BodyJoint raw value → position

    func joint(_ name: BodyJoint) -> JointPoint? {
        joints[name.rawValue]
    }
}

nonisolated extension PoseFrameData {

    /// Median distance between two joints over the frames whose timestamps
    /// fall in `range`, using only frames where both joints are confidently
    /// detected. The scale reference for displacement measurements (e.g.
    /// shoulder width, stance width). Returns nil when fewer than
    /// `minSamples` confident pairs exist or the median is degenerate.
    static func medianJointDistance(in frames: [PoseFrameData],
                                    between first: BodyJoint,
                                    and second: BodyJoint,
                                    during range: ClosedRange<TimeInterval>,
                                    minSamples: Int = 1) -> CGFloat? {
        var distances: [CGFloat] = []
        for frame in frames where range.contains(frame.timestamp) {
            guard let a = frame.joint(first),
                  let b = frame.joint(second),
                  a.confidence >= Constants.minimumJointConfidence,
                  b.confidence >= Constants.minimumJointConfidence else { continue }
            distances.append(hypot(a.x - b.x, a.y - b.y))
        }
        guard distances.count >= max(minSamples, 1) else { return nil }
        let median = distances.sorted()[distances.count / 2]
        return median > 0.01 ? median : nil
    }

    /// Median spine tilt from vertical (degrees, 0 = standing straight up)
    /// over the frames in `range`, from the root→neck vector. Returns nil
    /// when fewer than `minSamples` frames have a confident neck and root.
    static func medianSpineTilt(in frames: [PoseFrameData],
                                during range: ClosedRange<TimeInterval>,
                                minSamples: Int = Constants.minCheckSamples) -> Double? {
        var tilts: [Double] = []
        for frame in frames where range.contains(frame.timestamp) {
            guard let neck = frame.joint(.neck),
                  let root = frame.joint(.root),
                  neck.confidence >= Constants.minimumJointConfidence,
                  root.confidence >= Constants.minimumJointConfidence,
                  let tilt = AngleCalculator.angleFromVertical(from: root.location,
                                                               to: neck.location) else { continue }
            tilts.append(tilt)
        }
        guard tilts.count >= max(minSamples, 1) else { return nil }
        return tilts.sorted()[tilts.count / 2]
    }
}

/// A single joint position in Vision's normalized image coordinates
/// (0–1, origin at bottom-left) with the detection confidence.
nonisolated struct JointPoint: Codable {
    let x: CGFloat
    let y: CGFloat
    let confidence: Float

    var location: CGPoint { CGPoint(x: x, y: y) }
}

/// The 19 body joints Vision's 2D pose detection provides, using the plain
/// names the analysis checks refer to (see plan section 2).
nonisolated enum BodyJoint: String, Codable, CaseIterable {
    case nose, leftEye, rightEye, leftEar, rightEar
    case neck, leftShoulder, rightShoulder, root
    case leftElbow, rightElbow, leftWrist, rightWrist
    case leftHip, rightHip, leftKnee, rightKnee, leftAnkle, rightAnkle

    /// Vision's identifier for this joint.
    var visionName: VNHumanBodyPoseObservation.JointName {
        switch self {
        case .nose: .nose
        case .leftEye: .leftEye
        case .rightEye: .rightEye
        case .leftEar: .leftEar
        case .rightEar: .rightEar
        case .neck: .neck
        case .leftShoulder: .leftShoulder
        case .rightShoulder: .rightShoulder
        case .root: .root
        case .leftElbow: .leftElbow
        case .rightElbow: .rightElbow
        case .leftWrist: .leftWrist
        case .rightWrist: .rightWrist
        case .leftHip: .leftHip
        case .rightHip: .rightHip
        case .leftKnee: .leftKnee
        case .rightKnee: .rightKnee
        case .leftAnkle: .leftAnkle
        case .rightAnkle: .rightAnkle
        }
    }

    /// Joint pairs connected by a line when drawing the skeleton.
    static let skeletonConnections: [(BodyJoint, BodyJoint)] = [
        (.nose, .neck),
        (.leftEye, .nose), (.rightEye, .nose),
        (.leftEar, .leftEye), (.rightEar, .rightEye),
        (.neck, .leftShoulder), (.neck, .rightShoulder),
        (.leftShoulder, .leftElbow), (.leftElbow, .leftWrist),
        (.rightShoulder, .rightElbow), (.rightElbow, .rightWrist),
        (.neck, .root),
        (.root, .leftHip), (.root, .rightHip),
        (.leftHip, .leftKnee), (.leftKnee, .leftAnkle),
        (.rightHip, .rightKnee), (.rightKnee, .rightAnkle),
    ]
}
