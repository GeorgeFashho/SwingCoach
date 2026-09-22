//
//  FeedbackGenerator.swift
//  SwingCoach
//

import CoreGraphics
import Foundation

/// The single home for the plain-English coaching copy (plan section 3
/// feedback examples). Checks measure and score; this maps what they found
/// to something a beginner can act on.
nonisolated enum FeedbackGenerator {

    static func setupPosture(score: Double, tilt: Double) -> String {
        if Severity(score: score) == .good {
            return "Your setup posture looks solid. You have a nice athletic bend from the hips."
        }
        if tilt < Constants.setupPostureGoodBand.lowerBound {
            return "You're standing too tall at address. Try bending more from your hips (not your back) — imagine you're about to sit on a tall bar stool."
        }
        return "You're bending over too much at address. Stand a bit taller and feel the bend coming from your hip joints, not your upper back."
    }

    static func headStability(score: Double, displacement: CGVector) -> String {
        if Severity(score: score) == .good {
            return "Great head stability! Your head stayed nice and steady throughout the swing."
        }
        if abs(displacement.dx) >= abs(displacement.dy) {
            return "Your head is moving sideways during the swing. Try to feel like your head stays over the ball. A good drill: put a headcover under your trail foot and keep pressure on it during the backswing."
        }
        return "Your head is changing height during the swing — often a sign of lunging at the ball or standing up. Try to maintain your height from address all the way through impact."
    }

    static func hipSway(score: Double) -> String {
        if Severity(score: score) == .good {
            return "Nice hip action! Your hips are rotating rather than sliding, which is how you generate real power."
        }
        return "Your hips are sliding sideways during the backswing instead of turning. Imagine your trail hip is pinned against a wall — it should turn in place, not slide back. Try hitting balls with your trail foot against a golf bag to feel the resistance."
    }

    static func spineAngle(score: Double) -> String {
        if Severity(score: score) == .good {
            return "Excellent posture maintenance! You kept your spine angle steady through impact."
        }
        return "You're losing your spine angle during the downswing — standing up through the ball. This is called \"early extension\" and it causes inconsistent contact. Try to feel like you keep the same bend you had at setup all the way through impact."
    }

    static func shoulderTurn(score: Double) -> String {
        if Severity(score: score) == .good {
            return "Great shoulder turn! You're coiling your upper body nicely, which stores power for the downswing."
        }
        return "Your shoulders aren't turning enough in the backswing — you're using mostly your arms. Try to feel your lead shoulder pointing at the ball at the top of your backswing; that means you've turned about 90 degrees."
    }

    static func tempo(ratio: Double) -> String {
        let formatted = String(format: "%.1f", ratio)
        if ratio < Constants.tempoGoodBand.lowerBound {
            return "You're rushing your downswing. Your swing tempo is \(formatted):1 — try to smooth it out. Think \"low and slow\" on the way back, then let gravity start the downswing. A good mental rhythm is \"one-two-three\" on the backswing, \"four\" on the downswing."
        }
        if ratio > Constants.tempoGoodBand.upperBound {
            return "Your downswing is unusually slow compared to your backswing (about \(formatted):1). This can mean you're decelerating through impact. Commit to the swing — accelerate through the ball, not at it."
        }
        return "Nice tempo! Your backswing-to-downswing ratio is about \(formatted):1, right around the 3:1 rhythm the pros swing with."
    }

    /// A concrete practice drill for the coaching card, branching on fault
    /// direction where the measurement supports it. Additive to the existing
    /// feedback copy (D1): these drills are deliberately DIFFERENT from any
    /// drill already embedded in a check's feedback string, so the coaching
    /// card and the check-detail feedback complement rather than repeat each
    /// other. `headDisplacement` is only read for headStability (nil elsewhere).
    static func drill(for check: CheckName,
                      measuredValue: Double,
                      headDisplacement: CGVector? = nil) -> String {
        switch check {
        case .setupPosture:
            if measuredValue < Constants.setupPostureGoodBand.lowerBound {
                return "Stand with your arms hanging naturally, then bend forward from your hips until your hands are just above your knees. That's about the right amount of tilt. Hold a club across your hips to feel the hinge point."
            }
            return "Stand up straighter and push your hips back instead of rounding your upper back. Your arms should hang naturally — if they're reaching for the ground, you're bent too far."
        case .headStability:
            let displacement = headDisplacement ?? .zero
            if abs(displacement.dx) >= abs(displacement.dy) {
                return "With the sun behind you, take slow practice swings watching your shadow: keep your head's shadow inside an imagined square. Exaggerate the stillness at half speed, then build back up."
            }
            return "Set up next to a doorframe so the top of your head just touches it. Make slow practice swings while staying in contact — if you dip or rise, you'll feel it."
        case .hipSway:
            return "Stick a club or alignment stick in the ground just outside your trail hip. Turn back without bumping it — if your hip hits the stick, you slid instead of turning."
        case .spineAngle:
            return "Make practice swings with your backside lightly touching a wall. If you lose contact before impact, you're standing up through the ball."
        case .shoulderTurn:
            return "Cross your arms over your chest and practice backswing turns without a club. Feel your lead shoulder point at the ball at the top. Start slow — flexibility improves with practice."
        case .tempo:
            if measuredValue < Constants.tempoGoodBand.lowerBound {
                return "Try the pause drill: make your normal backswing, then pause for a full second at the top before starting down. It feels slow, but it trains patience at the transition."
            }
            return "Commit to a full finish. Swing to a balanced pose you could hold for 3 seconds. If you're decelerating, your finish will be short and off-balance."
        }
    }

    /// Banner shown over a session's analysis when its average joint
    /// confidence was low (PoseQuality.isLow) — the results still show,
    /// but the golfer should know they're shakier than usual.
    static let lowPoseQualityWarning = "We had trouble seeing your body clearly in this video, so these results may be less accurate. Try recording in better lighting, with your whole body in frame."

    /// The coaching card's positive state: shown when every scored check on a
    /// swing cleared its good band, so there's no single fault to fix first.
    /// Honest praise, plus a nudge to record the other angle for the checks
    /// this one can't see.
    static let allChecksGoodMessage = "Everything we measured looked solid on this swing — nice work. Keep it up, or record from the other angle to check the things we can't see from here."

    /// Shown when a check ran but couldn't measure confidently — an honest
    /// gap, never a made-up score (plan section 3, occlusion fallback).
    static func insufficientDataMessage(for check: CheckName) -> String {
        switch check {
        case .shoulderTurn:
            "We couldn't see your shoulders clearly at the top of your swing, so this check was skipped."
        default:
            "We couldn't see your body clearly enough to measure this. Make sure your whole body is visible and well lit."
        }
    }

    /// Why a check is missing from this session entirely: it can only be
    /// measured from the other camera angle. Nil for checks that run from
    /// both angles (tempo), which are never skipped for angle reasons.
    static func skippedMessage(for check: CheckName) -> String? {
        switch check.requiredAngle {
        case .faceOn:
            "This needs a Face-On video — one filmed with the camera facing your chest. Record from that angle and we'll measure it."
        case .downTheLine:
            "This needs a Down-the-Line video — one filmed from behind you, looking toward the target. Record from that angle and we'll measure it."
        case nil:
            nil
        }
    }

    /// The "What this means" section in the check detail view: what we
    /// measured and why someone new to golf should care.
    static func whatThisMeans(for check: CheckName) -> String {
        switch check {
        case .setupPosture:
            "A good golf swing starts before you move: bending forward from your hips puts you in a balanced, athletic position. Stand too tall or hunch too much and it becomes hard to turn properly or hit the ball solidly."
        case .headStability:
            "Your head is a good stand-in for the center of your swing. When it stays roughly in place, you're turning around a stable center — which makes it much easier to hit the ball with the middle of the club."
        case .hipSway:
            "During the backswing your hips should turn in place, not slide away from the target. Sliding (called sway) makes it hard to get back to the ball in time, costing you both solid contact and power."
        case .spineAngle:
            "Whatever forward bend you set up with, the goal is to keep it until after you've hit the ball. Standing up mid-swing — very common for beginners — changes how far you are from the ball and leads to thin or topped shots."
        case .shoulderTurn:
            "Turning your shoulders fully in the backswing winds your body up like a spring. A short, arms-only backswing feels safer, but it actually gives you less power and less consistency."
        case .tempo:
            "Tempo is the rhythm of your swing: an unhurried backswing, then a faster downswing. Pros take about three times as long going back as coming down — rushing that change of direction is one of the most common swing killers."
        }
    }

    /// The measured value next to the good range from Constants, in units
    /// a beginner can picture — the "measured value vs threshold" line in
    /// the check detail view.
    static func measurementDescription(for check: CheckName, measuredValue: Double) -> String {
        switch check {
        case .setupPosture:
            "You were tilted about \(degrees(measuredValue)) forward at address. A good range is \(degrees(Constants.setupPostureGoodBand.lowerBound)) to \(degrees(Constants.setupPostureGoodBand.upperBound))."
        case .headStability:
            "Your head drifted about \(percent(measuredValue)) of your shoulder width during the swing. Staying within \(percent(Constants.headStabilityGoodBand.upperBound)) is good."
        case .hipSway:
            "Your hips slid sideways about \(percent(measuredValue)) of your stance width during the backswing. Staying within \(percent(Constants.hipSwayGoodBand.upperBound)) is good."
        case .spineAngle:
            if measuredValue <= 0 {
                "You kept all of your setup tilt through impact — that's exactly the goal. Losing less than \(degrees(Constants.spineAngleLossGoodBand.upperBound)) counts as good."
            } else {
                "You lost about \(degrees(measuredValue)) of your setup tilt by impact. Losing less than \(degrees(Constants.spineAngleLossGoodBand.upperBound)) is good."
            }
        case .shoulderTurn:
            "At the top of your backswing, your shoulders looked about \(percent(measuredValue)) as wide as at address — smaller means more turn. \(percent(Constants.shoulderTurnGoodBand.upperBound)) or less counts as a full turn."
        case .tempo:
            "Your backswing took about \(ratio(measuredValue)) as long as your downswing. A good range is \(ratio(Constants.tempoGoodBand.lowerBound)) to \(ratio(Constants.tempoGoodBand.upperBound))."
        }
    }

    private static func degrees(_ value: Double) -> String {
        String(format: "%.0f°", value)
    }

    private static func percent(_ value: Double) -> String {
        String(format: "%.0f%%", value * 100)
    }

    private static func ratio(_ value: Double) -> String {
        String(format: "%.1f×", value)
    }
}
