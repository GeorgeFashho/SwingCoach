//
//  ShaftOverlayView.swift
//  SwingCoach
//

import SwiftUI

/// Draws the estimated club shaft as a single grip→headward line, converted
/// from Vision-normalized coordinates. Shown only on the address frame — the
/// frame the estimate was actually computed from — so the caller is
/// responsible for gating this to that moment in playback.
struct ShaftOverlayView: View {
    let linePoints: [Double]  // [gripX, gripY, headX, headY], Vision-normalized
    let videoSize: CGSize

    var body: some View {
        Canvas { context, size in
            guard linePoints.count == 4 else { return }
            let videoRect = CoordinateTransform.videoRect(videoSize: videoSize, in: size)
            guard videoRect.width > 0 else { return }

            let grip = CGPoint(x: linePoints[0], y: linePoints[1])
            let headward = CGPoint(x: linePoints[2], y: linePoints[3])
            var line = Path()
            line.move(to: CoordinateTransform.viewPoint(fromNormalized: grip, videoRect: videoRect))
            line.addLine(to: CoordinateTransform.viewPoint(fromNormalized: headward, videoRect: videoRect))
            context.stroke(line, with: .color(Color.brandPrimary), lineWidth: 4)
        }
        .allowsHitTesting(false)
    }
}
