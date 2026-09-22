//
//  AnalysisEngine.swift
//  SwingCoach
//

/// One check's outcome from an analysis run: a scored result, or an honest
/// "couldn't measure this" with a user-facing explanation (e.g. the
/// shoulder-turn occlusion fallback). Checks that don't apply to the
/// session's camera angle are simply absent.
nonisolated enum CheckOutcome {
    case scored(CheckResult)
    case insufficientData(CheckName, message: String)

    var result: CheckResult? {
        if case .scored(let result) = self { result } else { nil }
    }

    var checkName: CheckName {
        switch self {
        case .scored(let result): result.checkName
        case .insufficientData(let name, _): name
        }
    }
}

/// Orchestrates the biomechanical checks for one segmented swing (plan
/// section 3, check-to-camera-angle matrix): face-on recordings run head
/// stability, hip sway, shoulder turn, and tempo; down-the-line recordings
/// run setup posture, spine angle maintenance, and tempo. Pure and
/// synchronous — persistence is the caller's job.
nonisolated struct AnalysisEngine {

    func analyze(frames: [PoseFrameData],
                 phases: SwingPhases,
                 cameraAngle: CameraAngle) -> [CheckOutcome] {
        let checks: [(CheckName, () -> CheckResult?)] = switch cameraAngle {
        case .faceOn:
            [(.headStability, { HeadStabilityCheck().run(frames: frames, phases: phases) }),
             (.hipSway, { HipSwayCheck().run(frames: frames, phases: phases) }),
             (.shoulderTurn, { ShoulderTurnCheck().run(frames: frames, phases: phases) }),
             (.tempo, { TempoCheck().run(phases: phases) })]
        case .downTheLine:
            [(.setupPosture, { SetupPostureCheck().run(frames: frames, phases: phases) }),
             (.spineAngle, { SpineAngleCheck().run(frames: frames, phases: phases) }),
             (.tempo, { TempoCheck().run(phases: phases) })]
        }
        return checks.map { name, run in
            if let result = run() {
                .scored(result)
            } else {
                .insufficientData(name, message: FeedbackGenerator.insufficientDataMessage(for: name))
            }
        }
    }
}
