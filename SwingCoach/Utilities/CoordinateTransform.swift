//
//  CoordinateTransform.swift
//  SwingCoach
//

import CoreGraphics

/// Converts between Vision's normalized image coordinates (0–1, origin at
/// bottom-left) and view coordinates (points, origin at top-left).
nonisolated enum CoordinateTransform {

    /// The rect the video actually occupies inside a view when displayed
    /// aspect-fit (the same math AVPlayerLayer uses for .resizeAspect).
    static func videoRect(videoSize: CGSize, in viewSize: CGSize) -> CGRect {
        guard videoSize.width > 0, videoSize.height > 0,
              viewSize.width > 0, viewSize.height > 0 else { return .zero }
        let scale = min(viewSize.width / videoSize.width, viewSize.height / videoSize.height)
        let size = CGSize(width: videoSize.width * scale, height: videoSize.height * scale)
        return CGRect(x: (viewSize.width - size.width) / 2,
                      y: (viewSize.height - size.height) / 2,
                      width: size.width,
                      height: size.height)
    }

    /// Vision normalized point → view point (flips the Y axis).
    static func viewPoint(fromNormalized point: CGPoint, videoRect: CGRect) -> CGPoint {
        CGPoint(x: videoRect.minX + point.x * videoRect.width,
                y: videoRect.minY + (1 - point.y) * videoRect.height)
    }

    /// View point → Vision normalized point (inverse of viewPoint).
    static func normalizedPoint(fromView point: CGPoint, videoRect: CGRect) -> CGPoint {
        guard videoRect.width > 0, videoRect.height > 0 else { return .zero }
        return CGPoint(x: (point.x - videoRect.minX) / videoRect.width,
                       y: 1 - (point.y - videoRect.minY) / videoRect.height)
    }

    /// The size a video displays at once its preferred transform is applied.
    /// Portrait recordings store landscape buffers with a 90° transform, so
    /// width and height swap.
    static func orientedSize(naturalSize: CGSize, preferredTransform: CGAffineTransform) -> CGSize {
        let rect = CGRect(origin: .zero, size: naturalSize).applying(preferredTransform)
        return CGSize(width: abs(rect.width), height: abs(rect.height))
    }
}
