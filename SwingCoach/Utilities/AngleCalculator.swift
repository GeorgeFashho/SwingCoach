//
//  AngleCalculator.swift
//  SwingCoach
//

import CoreGraphics
import Foundation

/// Pure 2D geometry helpers used by the biomechanical checks.
nonisolated enum AngleCalculator {

    /// The angle in degrees (0–180) at `vertex` formed by the segments
    /// vertex→a and vertex→b. Returns nil for degenerate input (a or b
    /// coincides with the vertex).
    static func angle(at vertex: CGPoint, between a: CGPoint, and b: CGPoint) -> Double? {
        let v1 = (dx: Double(a.x - vertex.x), dy: Double(a.y - vertex.y))
        let v2 = (dx: Double(b.x - vertex.x), dy: Double(b.y - vertex.y))
        let length1 = hypot(v1.dx, v1.dy)
        let length2 = hypot(v2.dx, v2.dy)
        guard length1 > 0, length2 > 0 else { return nil }
        let cosine = (v1.dx * v2.dx + v1.dy * v2.dy) / (length1 * length2)
        return acos(min(max(cosine, -1), 1)) * 180 / .pi
    }

    /// The angle in degrees (0–180) between the vector start→end and true
    /// vertical (straight up in Vision coordinates, where +y is up).
    /// 0 = pointing straight up, 90 = horizontal, 180 = straight down.
    /// Returns nil when start and end coincide.
    static func angleFromVertical(from start: CGPoint, to end: CGPoint) -> Double? {
        let v = (dx: Double(end.x - start.x), dy: Double(end.y - start.y))
        let length = hypot(v.dx, v.dy)
        guard length > 0 else { return nil }
        let cosine = v.dy / length
        return acos(min(max(cosine, -1), 1)) * 180 / .pi
    }
}
