//
//  ClubShaftServiceTests.swift
//  SwingCoachTests
//

import CoreGraphics
import Testing
@testable import SwingCoach

/// Coverage for the pure geometry/scoring functions `ClubShaftService`
/// factors out of its Vision/AVFoundation pipeline (see the service's "Pure
/// geometry" section). The Vision hand-pose + gradient-search path itself
/// needs a fixture video and isn't unit-tested here.
struct ClubShaftServiceTests {

    // MARK: - shaftAngleFromVertical

    @Test func verticalLineIsZeroDegrees() throws {
        let up = try #require(ClubShaftService.shaftAngleFromVertical(grip: CGPoint(x: 0, y: 0),
                                                                       headward: CGPoint(x: 0, y: 1)))
        #expect(up == 0)

        // Direction-agnostic: grip/headward swapped still reads as vertical.
        let down = try #require(ClubShaftService.shaftAngleFromVertical(grip: CGPoint(x: 0, y: 1),
                                                                         headward: CGPoint(x: 0, y: 0)))
        #expect(down == 0)
    }

    @Test func horizontalLineIsNinetyDegrees() throws {
        let rightward = try #require(ClubShaftService.shaftAngleFromVertical(grip: CGPoint(x: 0, y: 0),
                                                                              headward: CGPoint(x: 1, y: 0)))
        #expect(rightward == 90)

        let leftward = try #require(ClubShaftService.shaftAngleFromVertical(grip: CGPoint(x: 1, y: 0),
                                                                             headward: CGPoint(x: 0, y: 0)))
        #expect(leftward == 90)
    }

    @Test func fortyFiveDegreeDiagonalIsExact() throws {
        let angle = try #require(ClubShaftService.shaftAngleFromVertical(grip: CGPoint(x: 0, y: 0),
                                                                          headward: CGPoint(x: 1, y: 1)))
        #expect(angle == 45)

        // Y-flip agnostic: a negative dy (as in a top-left-origin pixel
        // buffer) gives the same undirected tilt as a positive dy.
        let flipped = try #require(ClubShaftService.shaftAngleFromVertical(grip: CGPoint(x: 0, y: 0),
                                                                            headward: CGPoint(x: 1, y: -1)))
        #expect(flipped == 45)
    }

    @Test func threeFourFiveTriangleGivesKnownAngle() throws {
        let angle = try #require(ClubShaftService.shaftAngleFromVertical(grip: CGPoint(x: 0, y: 0),
                                                                          headward: CGPoint(x: 3, y: 4)))
        #expect(abs(angle - 36.86989764584402) < 1e-9)

        let steeper = try #require(ClubShaftService.shaftAngleFromVertical(grip: CGPoint(x: 0, y: 0),
                                                                            headward: CGPoint(x: 4, y: 3)))
        #expect(abs(steeper - 53.13010235415598) < 1e-9)
    }

    @Test func coincidentPointsReturnNil() {
        let point = CGPoint(x: 0.4, y: 0.6)
        #expect(ClubShaftService.shaftAngleFromVertical(grip: point, headward: point) == nil)
    }

    // MARK: - confidence

    @Test func confidenceIsExactWeightedSumForSingleInputs() {
        #expect(ClubShaftService.confidence(edgeSupport: 1, straightness: 0, anchorProximity: 0) == 0.5)
        #expect(ClubShaftService.confidence(edgeSupport: 0, straightness: 1, anchorProximity: 0) == 0.3)
        #expect(ClubShaftService.confidence(edgeSupport: 0, straightness: 0, anchorProximity: 1) == 0.2)
        #expect(ClubShaftService.confidence(edgeSupport: 1, straightness: 1, anchorProximity: 1) == 1.0)
        #expect(ClubShaftService.confidence(edgeSupport: 0, straightness: 0, anchorProximity: 0) == 0.0)
    }

    @Test func confidenceWeightsADyadicMidValueExactly() {
        // 0.5*1 + 0.3*0 + 0.2*0.5 == 0.6, all dyadic so this is ULP-safe.
        #expect(ClubShaftService.confidence(edgeSupport: 1, straightness: 0, anchorProximity: 0.5) == 0.6)
    }

    @Test func confidenceClampsEachInputBeforeWeighting() {
        // Out-of-range edgeSupport clamps to the same result as the bound itself.
        #expect(ClubShaftService.confidence(edgeSupport: 2.0, straightness: 0.4, anchorProximity: 0.1)
                == ClubShaftService.confidence(edgeSupport: 1.0, straightness: 0.4, anchorProximity: 0.1))
        #expect(ClubShaftService.confidence(edgeSupport: -5.0, straightness: 0.4, anchorProximity: 0.1)
                == ClubShaftService.confidence(edgeSupport: 0.0, straightness: 0.4, anchorProximity: 0.1))

        // Out-of-range straightness.
        #expect(ClubShaftService.confidence(edgeSupport: 0.2, straightness: 3.0, anchorProximity: 0.1)
                == ClubShaftService.confidence(edgeSupport: 0.2, straightness: 1.0, anchorProximity: 0.1))
        #expect(ClubShaftService.confidence(edgeSupport: 0.2, straightness: -1.0, anchorProximity: 0.1)
                == ClubShaftService.confidence(edgeSupport: 0.2, straightness: 0.0, anchorProximity: 0.1))

        // Out-of-range anchorProximity.
        #expect(ClubShaftService.confidence(edgeSupport: 0.2, straightness: 0.4, anchorProximity: 9.0)
                == ClubShaftService.confidence(edgeSupport: 0.2, straightness: 0.4, anchorProximity: 1.0))
        #expect(ClubShaftService.confidence(edgeSupport: 0.2, straightness: 0.4, anchorProximity: -2.0)
                == ClubShaftService.confidence(edgeSupport: 0.2, straightness: 0.4, anchorProximity: 0.0))
    }

    @Test func confidenceStaysWithinUnitRange() {
        let value = ClubShaftService.confidence(edgeSupport: 100, straightness: 100, anchorProximity: 100)
        #expect(value >= 0 && value <= 1)
        #expect(value == 1.0)

        let floor = ClubShaftService.confidence(edgeSupport: -100, straightness: -100, anchorProximity: -100)
        #expect(floor == 0.0)
    }

    @Test func confidenceIsMonotonicInEachInput() {
        #expect(ClubShaftService.confidence(edgeSupport: 0.2, straightness: 0.5, anchorProximity: 0.5)
                < ClubShaftService.confidence(edgeSupport: 0.8, straightness: 0.5, anchorProximity: 0.5))
        #expect(ClubShaftService.confidence(edgeSupport: 0.5, straightness: 0.2, anchorProximity: 0.5)
                < ClubShaftService.confidence(edgeSupport: 0.5, straightness: 0.8, anchorProximity: 0.5))
        #expect(ClubShaftService.confidence(edgeSupport: 0.5, straightness: 0.5, anchorProximity: 0.2)
                < ClubShaftService.confidence(edgeSupport: 0.5, straightness: 0.5, anchorProximity: 0.8))
    }

    // MARK: - isPlausibleShaft

    private let plausibleLength = 0.5
    private let plausibleConfidence = 0.5

    @Test func acceptsAngleAtBothBoundariesInclusive() {
        #expect(ClubShaftService.isPlausibleShaft(angleFromVertical: ClubShaftService.minShaftAngleFromVertical,
                                                   lengthFraction: plausibleLength,
                                                   confidence: plausibleConfidence))
        #expect(ClubShaftService.isPlausibleShaft(angleFromVertical: ClubShaftService.maxShaftAngleFromVertical,
                                                   lengthFraction: plausibleLength,
                                                   confidence: plausibleConfidence))
    }

    @Test func rejectsAngleJustOutsideBoundaries() {
        #expect(!ClubShaftService.isPlausibleShaft(
            angleFromVertical: ClubShaftService.minShaftAngleFromVertical - 0.001,
            lengthFraction: plausibleLength, confidence: plausibleConfidence))
        #expect(!ClubShaftService.isPlausibleShaft(
            angleFromVertical: ClubShaftService.maxShaftAngleFromVertical + 0.001,
            lengthFraction: plausibleLength, confidence: plausibleConfidence))
    }

    @Test func rejectsTooShortLength() {
        #expect(!ClubShaftService.isPlausibleShaft(
            angleFromVertical: 45,
            lengthFraction: ClubShaftService.minShaftLengthFraction - 0.001,
            confidence: plausibleConfidence))
        #expect(ClubShaftService.isPlausibleShaft(
            angleFromVertical: 45,
            lengthFraction: ClubShaftService.minShaftLengthFraction,
            confidence: plausibleConfidence))
    }

    @Test func rejectsLowConfidence() {
        #expect(!ClubShaftService.isPlausibleShaft(
            angleFromVertical: 45, lengthFraction: plausibleLength,
            confidence: ClubShaftService.minConfidence - 0.001))
        #expect(ClubShaftService.isPlausibleShaft(
            angleFromVertical: 45, lengthFraction: plausibleLength,
            confidence: ClubShaftService.minConfidence))
    }

    @Test func acceptsAPlausibleShaft() {
        #expect(ClubShaftService.isPlausibleShaft(angleFromVertical: 45, lengthFraction: 0.5, confidence: 0.5))
    }

    // MARK: - expectedHeadwardHorizontalSign

    @Test func signDependsOnlyOnHandedness() {
        #expect(ClubShaftService.expectedHeadwardHorizontalSign(handedness: .right, cameraAngle: .faceOn) == 1)
        #expect(ClubShaftService.expectedHeadwardHorizontalSign(handedness: .right, cameraAngle: .downTheLine) == 1)
        #expect(ClubShaftService.expectedHeadwardHorizontalSign(handedness: .left, cameraAngle: .faceOn) == -1)
        #expect(ClubShaftService.expectedHeadwardHorizontalSign(handedness: .left, cameraAngle: .downTheLine) == -1)
    }
}
