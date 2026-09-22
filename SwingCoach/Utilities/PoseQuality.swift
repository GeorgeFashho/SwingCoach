//
//  PoseQuality.swift
//  SwingCoach
//

/// Judges whether a session's pose tracking was reliable enough to trust
/// the analysis (plan risk 3: lighting and clothing degrade detection).
/// Computed once when pose frames load, never per view.
nonisolated enum PoseQuality {

    /// Mean detection confidence across every joint of every frame, or nil
    /// when there are no joints to average.
    static func averageJointConfidence(of frames: [PoseFrameData]) -> Float? {
        var total: Float = 0
        var count = 0
        for frame in frames {
            for joint in frame.joints.values {
                total += joint.confidence
                count += 1
            }
        }
        guard count > 0 else { return nil }
        return total / Float(count)
    }

    /// True when the average is strictly below the Constants threshold —
    /// the "results may be less accurate" warning fires only then.
    static func isLow(_ frames: [PoseFrameData]) -> Bool {
        guard let average = averageJointConfidence(of: frames) else { return false }
        return average < Constants.lowPoseQualityAverageConfidence
    }
}
