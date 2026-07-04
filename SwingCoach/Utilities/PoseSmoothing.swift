//
//  PoseSmoothing.swift
//  SwingCoach
//

import CoreGraphics

/// Moving-average filter over joint positions across frames, to reduce
/// Vision's frame-to-frame jitter (plan section 7, risk 2). The raw
/// detection data stays on disk untouched; smoothing is applied when the
/// frames are loaded, so the filter can be re-tuned without re-detecting.
nonisolated enum PoseSmoothing {

    /// Returns a copy of `frames` where each reliable joint position is
    /// replaced by the average of that joint's position over a centered
    /// window. Low-confidence joints are left as-is (never fabricated from
    /// neighbors) and are excluded from neighbors' averages. Confidence
    /// values are preserved from the original frame.
    static func smoothed(_ frames: [PoseFrameData],
                         window: Int = Constants.poseSmoothingWindow) -> [PoseFrameData] {
        guard frames.count > 1, window > 1 else { return frames }
        let halfWindow = window / 2

        return frames.enumerated().map { index, frame in
            var smoothedJoints: [String: JointPoint] = [:]
            for (name, joint) in frame.joints {
                guard joint.confidence >= Constants.minimumJointConfidence else {
                    smoothedJoints[name] = joint
                    continue
                }
                var sumX: CGFloat = 0
                var sumY: CGFloat = 0
                var count = 0
                for neighborIndex in max(0, index - halfWindow)...min(frames.count - 1, index + halfWindow) {
                    guard let neighbor = frames[neighborIndex].joints[name],
                          neighbor.confidence >= Constants.minimumJointConfidence else { continue }
                    sumX += neighbor.x
                    sumY += neighbor.y
                    count += 1
                }
                smoothedJoints[name] = count > 0
                    ? JointPoint(x: sumX / CGFloat(count), y: sumY / CGFloat(count), confidence: joint.confidence)
                    : joint
            }
            return PoseFrameData(frameIndex: frame.frameIndex,
                                 timestamp: frame.timestamp,
                                 joints: smoothedJoints)
        }
    }
}
