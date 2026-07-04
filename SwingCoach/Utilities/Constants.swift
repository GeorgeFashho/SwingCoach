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

    /// Longest video that can be imported from the photo library. Keeps
    /// pose processing bounded (~20s at 120fps is ~2,400 frames).
    static let maxImportDuration: TimeInterval = 20

    /// Moving-average window (in frames) used to smooth joint jitter.
    /// 5 frames ≈ 42ms at 120fps — long enough to kill detection noise,
    /// short enough to preserve swing dynamics.
    static let poseSmoothingWindow = 5
}
