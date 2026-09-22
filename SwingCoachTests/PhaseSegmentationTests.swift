//
//  PhaseSegmentationTests.swift
//  SwingCoachTests
//

import Testing
@testable import SwingCoach

struct PhaseSegmentationTests {
    private let service = PhaseSegmentationService()

    @Test func detectsBoundariesOfNormalSwing() throws {
        let result = service.segment(frames: SwingFixtures.normalSwing(),
                                     cameraAngle: .faceOn,
                                     handedness: .right)
        let phases = try #require(result.phases)
        // Onset trips slightly after the true 0.5s start because the wrist
        // eases into motion before crossing the velocity threshold.
        #expect(phases.addressEnd >= 0.45 && phases.addressEnd <= 0.65)
        #expect(abs(phases.top - 1.25) <= 0.05)
        #expect(abs(phases.impact - 1.5) <= 0.07)
        #expect(phases.followThroughEnd > phases.impact)
    }

    @Test func downTheLineAngleAlsoSegments() {
        let result = service.segment(frames: SwingFixtures.normalSwing(),
                                     cameraAngle: .downTheLine,
                                     handedness: .right)
        #expect(result.phases != nil)
    }

    @Test func leftHandedGolferUsesTrailingWrist() {
        // The fixture moves both wrists identically, so a left-handed
        // golfer (lead wrist = rightWrist) must segment the same swing.
        let result = service.segment(frames: SwingFixtures.normalSwing(),
                                     cameraAngle: .faceOn,
                                     handedness: .left)
        #expect(result.phases != nil)
    }

    @Test func waggleBeforeSwingIsSkipped() throws {
        let result = service.segment(frames: SwingFixtures.waggleThenSwing(),
                                     cameraAngle: .faceOn,
                                     handedness: .right)
        let phases = try #require(result.phases)
        // The waggle (0.5–1.0s) trips the velocity threshold but never
        // rises like a backswing — boundaries must land on the real swing.
        #expect(phases.addressEnd >= 1.9 && phases.addressEnd <= 2.2)
        #expect(abs(phases.top - 2.75) <= 0.05)
        #expect(abs(phases.impact - 3.0) <= 0.07)
    }

    @Test func movingStartWithoutStableAddressIsSkipped() throws {
        let result = service.segment(frames: SwingFixtures.movingStartThenSwing(),
                                     cameraAngle: .faceOn,
                                     handedness: .right)
        let phases = try #require(result.phases)
        // The clip opens mid-movement with no still address before it —
        // that candidate is junk; boundaries must land on the real swing.
        #expect(phases.addressEnd >= 1.4 && phases.addressEnd <= 1.7)
        #expect(abs(phases.top - 2.25) <= 0.05)
        #expect(abs(phases.impact - 2.5) <= 0.07)
    }

    @Test func waggleAloneIsNotASwing() {
        let result = service.segment(frames: SwingFixtures.waggleOnly(),
                                     cameraAngle: .faceOn,
                                     handedness: .right)
        #expect(result.phases == nil)
        #expect(result.failure == .noSwingDetected)
    }

    @Test func noMotionFailsAsNoSwingDetected() {
        let result = service.segment(frames: SwingFixtures.noMotion(),
                                     cameraAngle: .faceOn,
                                     handedness: .right)
        #expect(result.phases == nil)
        #expect(result.failure == .noSwingDetected)
    }

    @Test func tooFastDownswingFailsValidation() {
        // A 40ms downswing is below the 80ms plausibility floor, so this is
        // the required segmentationFailed fixture: motion is detected but
        // the boundaries are rejected instead of producing check results.
        let result = service.segment(frames: SwingFixtures.normalSwing(downswingDuration: 0.04),
                                     cameraAngle: .faceOn,
                                     handedness: .right)
        #expect(result.phases == nil)
        #expect(result.failure == .implausibleBoundaries)
    }

    @Test func emptyInputFailsAsInsufficientData() {
        let result = service.segment(frames: [], cameraAngle: .faceOn, handedness: .right)
        #expect(result.failure == .insufficientPoseData)
    }

    @Test func lowConfidenceInputFailsAsInsufficientData() {
        let result = service.segment(frames: SwingFixtures.lowConfidence(),
                                     cameraAngle: .faceOn,
                                     handedness: .right)
        #expect(result.failure == .insufficientPoseData)
    }

    @Test func failureCarriesFriendlyRecordAgainMessage() {
        #expect(PhaseSegmentationFailure.implausibleBoundaries.userMessage.contains("try re-recording"))
    }

    @Test func segmentedPhasesFeedTempoCheckEndToEnd() throws {
        let result = service.segment(frames: SwingFixtures.normalSwing(),
                                     cameraAngle: .faceOn,
                                     handedness: .right)
        let phases = try #require(result.phases)
        let tempo = try #require(TempoCheck().run(phases: phases))
        // The fixture is a true 3:1 swing; detection tolerances shift the
        // measured ratio slightly but it must stay in the good band.
        #expect(tempo.measuredValue >= 2.5 && tempo.measuredValue <= 3.6)
        #expect(tempo.severity == .good)
    }
}
