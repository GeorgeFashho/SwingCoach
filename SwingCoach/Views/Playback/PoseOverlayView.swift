//
//  PoseOverlayView.swift
//  SwingCoach
//

import SwiftUI

/// Draws the detected skeleton for one pose frame on top of the video.
/// Joints below the confidence threshold (and bones touching them) are
/// hidden entirely: Vision reports occluded joints (e.g. the face in a
/// down-the-line view) at garbage positions, and even heavily dimmed
/// lines to those positions read as tracking errors on dark video.
struct PoseOverlayView: View {
    let frame: PoseFrameData
    let videoSize: CGSize

    var body: some View {
        Canvas { context, size in
            let videoRect = CoordinateTransform.videoRect(videoSize: videoSize, in: size)
            guard videoRect.width > 0 else { return }

            for (jointA, jointB) in BodyJoint.skeletonConnections {
                guard let a = frame.joint(jointA), let b = frame.joint(jointB),
                      a.confidence >= Constants.minimumJointConfidence,
                      b.confidence >= Constants.minimumJointConfidence else { continue }
                var bone = Path()
                bone.move(to: CoordinateTransform.viewPoint(fromNormalized: a.location, videoRect: videoRect))
                bone.addLine(to: CoordinateTransform.viewPoint(fromNormalized: b.location, videoRect: videoRect))
                context.stroke(bone, with: .color(.green.opacity(0.9)), lineWidth: 3)
            }

            for joint in BodyJoint.allCases {
                guard let point = frame.joint(joint),
                      point.confidence >= Constants.minimumJointConfidence else { continue }
                let center = CoordinateTransform.viewPoint(fromNormalized: point.location, videoRect: videoRect)
                let dot = CGRect(x: center.x - 5, y: center.y - 5, width: 10, height: 10)
                context.fill(Path(ellipseIn: dot), with: .color(.yellow))
            }
        }
        .allowsHitTesting(false)
    }
}
