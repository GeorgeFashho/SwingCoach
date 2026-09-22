//
//  ClubShaftService.swift
//  SwingCoach
//

import AVFoundation
import CoreGraphics
import Foundation
import Vision

/// The shaft line estimated on a swing's address frame: its angle from
/// vertical in the image plane, a 0–1 confidence, and the two endpoints in
/// Vision-normalized coordinates (0–1, origin bottom-left).
///
/// nonisolated: produced on a background thread by ClubShaftService, so it
/// must not inherit the module's default MainActor isolation.
nonisolated struct ShaftEstimate: Sendable {
    let angleDegrees: Double    // shaft angle from vertical, image plane; 0 = vertical, 90 = horizontal
    let confidence: Double      // 0...1
    let gripPoint: CGPoint      // Vision-normalized (0..1, origin bottom-left)
    let headwardPoint: CGPoint  // Vision-normalized, down the shaft toward the club head
}

/// Estimates the club's shaft angle at address from a recorded swing.
///
/// Re-extracts the single address frame from the video, runs hand-pose
/// detection to find a grip anchor (wrist + finger-base joints), then runs a
/// constrained straight-line search down the image gradient from that anchor
/// to lock onto the shaft edge. All the number-crunching that decides the
/// reported angle, the confidence, and whether a candidate is a plausible
/// shaft is factored into pure static functions with no Vision/AVFoundation
/// dependency so it can be unit-tested deterministically.
///
/// nonisolated + @concurrent: the module default is MainActor; the Vision and
/// pixel work must run off the main actor or it would stall the UI.
nonisolated final class ClubShaftService: Sendable {

    // MARK: - Tunables

    /// Plausible shaft tilt from vertical (degrees). A club at address is
    /// never near-vertical and never near-horizontal in a usable frame.
    static let minShaftAngleFromVertical: Double = 20
    static let maxShaftAngleFromVertical: Double = 80

    /// Minimum shaft length as a fraction of image height. Anything shorter
    /// than roughly a third of a torso is noise, not a shaft.
    static let minShaftLengthFraction: Double = 0.10

    /// Below this the estimate is suppressed (the UI shows "couldn't read").
    static let minConfidence: Double = 0.35

    /// The address frame is downscaled to at most this dimension before the
    /// gradient/line search — enough detail for a straight edge, cheap to scan.
    private static let gradientMaxDimension = 320

    /// Normalized gradient magnitude above which a sample counts as "edge".
    private static let edgeSupportThreshold: Float = 0.14

    /// Minimum hand-joint confidence to include a joint in the grip anchor.
    private static let minHandJointConfidence: Float = 0.3

    // MARK: - Public analysis entry point

    /// Estimates the shaft at address, or nil when the hand pose fails, no
    /// plausible shaft line is found, or confidence is below the gate.
    @concurrent
    func estimateShaftAtAddress(videoURL: URL,
                                addressTimestamp: TimeInterval,
                                cameraAngle: CameraAngle,
                                handedness: Handedness) async -> ShaftEstimate? {
        guard let cgImage = await Self.addressFrame(videoURL: videoURL, at: addressTimestamp),
              let anchor = Self.gripAnchor(in: cgImage),
              let gradient = Self.gradientField(from: cgImage, maxDimension: Self.gradientMaxDimension),
              let fit = Self.searchShaftLine(fromGrip: anchor.point,
                                             in: gradient,
                                             cameraAngle: cameraAngle,
                                             handedness: handedness)
        else { return nil }

        let confidence = Self.confidence(edgeSupport: fit.edgeSupport,
                                         straightness: fit.straightness,
                                         anchorProximity: Double(anchor.confidence))
        guard Self.isPlausibleShaft(angleFromVertical: fit.angleDegrees,
                                    lengthFraction: fit.lengthFraction,
                                    confidence: confidence)
        else { return nil }

        return ShaftEstimate(angleDegrees: fit.angleDegrees,
                             confidence: confidence,
                             gripPoint: anchor.point,
                             headwardPoint: fit.headwardPoint)
    }

    // MARK: - Pure geometry (deterministically unit-tested)

    /// Undirected tilt of the grip→headward segment from vertical, in degrees
    /// (0 = vertical, 90 = horizontal). Direction up vs down does not matter,
    /// so it is stable regardless of the coordinate system's Y direction.
    /// Returns nil when the two points coincide.
    static func shaftAngleFromVertical(grip: CGPoint, headward: CGPoint) -> Double? {
        let dx = Double(headward.x - grip.x)
        let dy = Double(headward.y - grip.y)
        guard hypot(dx, dy) > 0 else { return nil }
        return atan2(abs(dx), abs(dy)) * 180 / .pi
    }

    /// Blends the three line-fit quality signals into a single 0...1
    /// confidence. Edge support (how much of the searched span landed on a
    /// real edge) dominates; straightness (contiguity of that support) and
    /// anchor quality (grip-joint confidence) refine it. Each input is
    /// clamped to 0...1 first, and the result is clamped to 0...1.
    static func confidence(edgeSupport: Double, straightness: Double, anchorProximity: Double) -> Double {
        let e = clamp01(edgeSupport)
        let s = clamp01(straightness)
        let a = clamp01(anchorProximity)
        return clamp01(0.5 * e + 0.3 * s + 0.2 * a)
    }

    /// The accept/reject gate for a candidate shaft line: plausible tilt,
    /// long enough, and confident enough. A candidate failing any of these
    /// is discarded rather than shown as a wrong number.
    static func isPlausibleShaft(angleFromVertical: Double,
                                 lengthFraction: Double,
                                 confidence: Double) -> Bool {
        angleFromVertical >= minShaftAngleFromVertical
            && angleFromVertical <= maxShaftAngleFromVertical
            && lengthFraction >= minShaftLengthFraction
            && confidence >= minConfidence
    }

    /// The horizontal side the club head is expected to fall toward, as a
    /// weak prior from handedness and camera angle: +1 = image right, -1 =
    /// image left. A right-handed golfer's club head sits toward the lead
    /// (target) side, which reads as image-right in both a face-on mirror
    /// view and a down-the-line view; left-handed mirrors it. Used only as a
    /// small tie-breaker — real edge support decides the shaft.
    static func expectedHeadwardHorizontalSign(handedness: Handedness, cameraAngle: CameraAngle) -> Double {
        _ = cameraAngle // same lead-side reasoning holds for both current angles
        return handedness == .right ? 1 : -1
    }

    private static func clamp01(_ x: Double) -> Double { min(max(x, 0), 1) }

    // MARK: - Address frame extraction

    /// Decodes the exact address frame as an upright CGImage. Tolerances are
    /// zero so we get the requested instant, and the preferred transform is
    /// applied so portrait recordings come out upright (Vision then runs with
    /// `.up` orientation and buffer row 0 is the top of the image).
    private static func addressFrame(videoURL: URL, at timestamp: TimeInterval) async -> CGImage? {
        let asset = AVURLAsset(url: videoURL)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        let time = CMTime(seconds: timestamp, preferredTimescale: 600)
        return try? await generator.image(at: time).image
    }

    // MARK: - Grip anchor (hand pose)

    /// Runs hand-pose detection on the address frame and returns the grip
    /// anchor: the centroid of every confidently-detected wrist and
    /// finger-base (MCP) joint across both hands, in Vision-normalized
    /// coordinates, plus the mean confidence of those joints. Both hands grip
    /// the club together, so their joints are pooled. Returns nil when no
    /// hand or no usable grip joint is detected.
    private static func gripAnchor(in cgImage: CGImage) -> (point: CGPoint, confidence: Float)? {
        let request = VNDetectHumanHandPoseRequest()
        request.maximumHandCount = 2
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up)
        guard (try? handler.perform([request])) != nil,
              let observations = request.results, !observations.isEmpty else { return nil }

        let gripJoints: [VNHumanHandPoseObservation.JointName] =
            [.wrist, .indexMCP, .middleMCP, .ringMCP, .littleMCP]

        var sumX = 0.0, sumY = 0.0, sumConfidence: Float = 0, count = 0
        for observation in observations {
            guard let recognized = try? observation.recognizedPoints(.all) else { continue }
            for name in gripJoints {
                guard let point = recognized[name],
                      point.confidence >= minHandJointConfidence else { continue }
                sumX += Double(point.location.x)
                sumY += Double(point.location.y)
                sumConfidence += point.confidence
                count += 1
            }
        }
        guard count > 0 else { return nil }
        return (CGPoint(x: sumX / Double(count), y: sumY / Double(count)),
                sumConfidence / Float(count))
    }

    // MARK: - Gradient field

    /// A downscaled grayscale gradient-magnitude image, row-major with row 0
    /// at the top of the upright frame and magnitudes normalized to 0...1.
    private struct GradientField {
        let width: Int
        let height: Int
        let magnitude: [Float]

        func magnitude(atX x: Int, y: Int) -> Float {
            guard x >= 0, x < width, y >= 0, y < height else { return 0 }
            return magnitude[y * width + x]
        }
    }

    /// Draws the frame into a tightly-packed grayscale bitmap (uniform
    /// downscale, preserving aspect ratio so image-plane angles stay true)
    /// and computes a central-difference gradient magnitude, normalized by
    /// the peak. Row 0 of a CG bitmap context is the top scanline.
    private static func gradientField(from cgImage: CGImage, maxDimension: Int) -> GradientField? {
        let scale = min(1.0, Double(maxDimension) / Double(max(cgImage.width, cgImage.height)))
        let width = max(1, Int(Double(cgImage.width) * scale))
        let height = max(1, Int(Double(cgImage.height) * scale))
        guard width >= 3, height >= 3 else { return nil }

        let count = width * height
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: count)
        defer { buffer.deallocate() }
        buffer.initialize(repeating: 0, count: count)

        guard let context = CGContext(data: buffer,
                                      width: width,
                                      height: height,
                                      bitsPerComponent: 8,
                                      bytesPerRow: width,
                                      space: CGColorSpaceCreateDeviceGray(),
                                      bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return nil }
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        var magnitude = [Float](repeating: 0, count: count)
        var peak: Float = 0
        for y in 1..<(height - 1) {
            for x in 1..<(width - 1) {
                let gx = Float(buffer[y * width + (x + 1)]) - Float(buffer[y * width + (x - 1)])
                let gy = Float(buffer[(y + 1) * width + x]) - Float(buffer[(y - 1) * width + x])
                let mag = (gx * gx + gy * gy).squareRoot()
                magnitude[y * width + x] = mag
                if mag > peak { peak = mag }
            }
        }
        if peak > 0 {
            for i in 0..<count { magnitude[i] /= peak }
        }
        return GradientField(width: width, height: height, magnitude: magnitude)
    }

    // MARK: - Constrained shaft line search

    private struct ShaftFit {
        let headwardPoint: CGPoint  // Vision-normalized
        let angleDegrees: Double
        let edgeSupport: Double
        let straightness: Double
        let lengthFraction: Double
    }

    /// Casts straight rays from the grip anchor through a downward cone
    /// (toward the club head) and keeps the one with the strongest sustained
    /// edge support, i.e. the shaft. The cone spans the plausible tilt range
    /// on both sides of vertical; a weak handedness/camera prior only breaks
    /// ties. Coordinates enter Vision-normalized (origin bottom-left) and are
    /// converted to the gradient buffer's pixel space (origin top-left).
    private static func searchShaftLine(fromGrip gripNormalized: CGPoint,
                                        in gradient: GradientField,
                                        cameraAngle: CameraAngle,
                                        handedness: Handedness) -> ShaftFit? {
        let width = Double(gradient.width)
        let height = Double(gradient.height)
        let gripX = Double(gripNormalized.x) * width
        let gripY = (1 - Double(gripNormalized.y)) * height   // normalized (y up) → buffer row (y down)

        let step = 1.0
        let minLength = 0.05 * height
        let maxLength = 0.70 * height
        guard maxLength > minLength else { return nil }
        let horizontalPrior = expectedHeadwardHorizontalSign(handedness: handedness, cameraAngle: cameraAngle)

        var best: (score: Double, eval: RayEval)?
        var angle = -85.0
        while angle <= 85.0 {
            let radians = angle * .pi / 180
            // Buffer space: +x right, +y down. cos(angle) >= 0 keeps the ray
            // pointing downward toward the club head across the whole cone.
            let dirX = sin(radians)
            let dirY = cos(radians)
            if let eval = evaluateRay(fromX: gripX, y: gripY,
                                      dirX: dirX, dirY: dirY,
                                      minLength: minLength, maxLength: maxLength, step: step,
                                      gradient: gradient) {
                // Weak prior: a small bonus when the ray leans toward the
                // expected club-head side. Never enough to override real edges.
                let prior = 1 + 0.08 * horizontalPrior * (dirX >= 0 ? 1 : -1)
                let score = eval.meanMagnitude * eval.supportFraction * prior
                if score > (best?.score ?? 0) {
                    best = (score, eval)
                }
            }
            angle += 2
        }

        guard let winner = best?.eval, winner.acceptedLength >= minLength else { return nil }

        let headX = gripX + winner.dirX * winner.acceptedLength
        let headY = gripY + winner.dirY * winner.acceptedLength
        let headwardNormalized = CGPoint(x: headX / width, y: 1 - headY / height)

        // True image-plane angle from pixel-space endpoints (aspect preserved).
        guard let angleDegrees = shaftAngleFromVertical(grip: CGPoint(x: gripX, y: gripY),
                                                        headward: CGPoint(x: headX, y: headY)) else { return nil }

        return ShaftFit(headwardPoint: headwardNormalized,
                        angleDegrees: angleDegrees,
                        edgeSupport: winner.supportFraction,
                        straightness: winner.longestRunFraction,
                        lengthFraction: winner.acceptedLength / height)
    }

    private struct RayEval {
        let dirX: Double
        let dirY: Double
        let meanMagnitude: Double
        let supportFraction: Double     // supported steps / total steps
        let longestRunFraction: Double  // longest contiguous supported run / total steps
        let acceptedLength: Double      // pixels to the farthest supported step
    }

    /// Walks one ray, sampling the gradient at each step, and summarizes how
    /// well it tracks an edge: mean magnitude, the fraction of steps on an
    /// edge, the longest unbroken on-edge run, and the distance to the last
    /// on-edge step (the shaft's headward end). Returns nil if the ray leaves
    /// the image immediately.
    private static func evaluateRay(fromX startX: Double, y startY: Double,
                                    dirX: Double, dirY: Double,
                                    minLength: Double, maxLength: Double, step: Double,
                                    gradient: GradientField) -> RayEval? {
        var total = 0
        var supported = 0
        var magnitudeSum = 0.0
        var currentRun = 0
        var longestRun = 0
        var lastSupportedLength = 0.0

        var length = minLength
        while length <= maxLength {
            let x = Int((startX + dirX * length).rounded())
            let y = Int((startY + dirY * length).rounded())
            if x < 0 || x >= gradient.width || y < 0 || y >= gradient.height { break }
            let mag = gradient.magnitude(atX: x, y: y)
            total += 1
            magnitudeSum += Double(mag)
            if mag >= edgeSupportThreshold {
                supported += 1
                currentRun += 1
                longestRun = max(longestRun, currentRun)
                lastSupportedLength = length
            } else {
                currentRun = 0
            }
            length += step
        }
        guard total > 0 else { return nil }
        return RayEval(dirX: dirX, dirY: dirY,
                       meanMagnitude: magnitudeSum / Double(total),
                       supportFraction: Double(supported) / Double(total),
                       longestRunFraction: Double(longestRun) / Double(total),
                       acceptedLength: lastSupportedLength)
    }
}
