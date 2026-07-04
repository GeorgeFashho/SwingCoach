//
//  PoseFrame.swift
//  SwingCoach
//

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
