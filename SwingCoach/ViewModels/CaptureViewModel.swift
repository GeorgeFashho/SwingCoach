//
//  CaptureViewModel.swift
//  SwingCoach
//

import AVFoundation
import Foundation
import Observation
import SwiftData

@Observable
@MainActor
final class CaptureViewModel {
    var selectedAngle: CameraAngle = .faceOn
    var selectedClub: GolfClub = GolfClub.storedDefault
    var isRecording = false
    var isSessionRunning = false
    var errorMessage: String?
    var showAngleGuide = false
    /// Camera permission was denied — CaptureView swaps the dead preview
    /// for an explanation with a Settings deep-link.
    var isPermissionDenied = false

    /// Non-nil during the pre-record countdown (3, 2, 1…), so a solo user can
    /// walk into position before recording starts. Drives the big on-screen
    /// count and a haptic per tick.
    var countdown: Int?

    /// The swing just recorded. CaptureView presents its result screen (which
    /// auto-analyzes) as a full-screen cover, then clears this — the "land on
    /// your result" moment instead of dead-ending on the live preview.
    var lastRecordedSession: SwingSession?

    let cameraService = CameraService()

    /// The countdown + auto-stop flow, retained so the record button can cancel
    /// the countdown or the pending auto-stop.
    private var flowTask: Task<Void, Never>?

    /// Set while the camera is torn down mid-recording (e.g. a tab switch) so
    /// the finalized clip is still saved but doesn't auto-open its result.
    private var isTearingDown = false

    /// Requests permission and starts the camera. Called when CaptureView appears.
    func startCamera() async {
        guard await cameraService.requestPermission() else {
            isPermissionDenied = true
            return
        }
        isPermissionDenied = false
        do {
            try await cameraService.start()
            isSessionRunning = true
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func stopCamera() {
        cancelFlow()
        if isRecording {
            // Finalize an in-progress clip cleanly on teardown, but don't pop
            // the result screen — the user has left the Record tab.
            isTearingDown = true
            cameraService.stopRecording()
        }
        cameraService.stop()
        isSessionRunning = false
    }

    /// Single record-button entry point:
    /// - idle → start the countdown, then record, then auto-stop
    /// - counting down → cancel before recording starts
    /// - recording → stop now (manual early finish)
    func handleRecordButton(modelContext: ModelContext) {
        if isRecording {
            stopRecordingEarly()
        } else if countdown != nil {
            cancelFlow()
        } else {
            startFlow(modelContext: modelContext)
        }
    }

    // MARK: - Capture flow

    private func startFlow(modelContext: ModelContext) {
        // Single-flight: a second tap in the sub-tick window before `countdown`
        // is set must not spawn a second flow that could stop a later clip.
        guard flowTask == nil else { return }
        let angle = selectedAngle
        let club = selectedClub
        flowTask = Task { [weak self] in
            guard let self else { return }

            // Countdown to start.
            for remaining in stride(from: Constants.captureCountdownSeconds, through: 1, by: -1) {
                self.countdown = remaining
                try? await Task.sleep(for: .seconds(1))
                if Task.isCancelled { self.countdown = nil; return }
            }
            self.countdown = nil
            if Task.isCancelled { return }

            // Record.
            self.beginRecording(angle: angle, club: club, modelContext: modelContext)

            // Auto-stop so the user never has to walk back to tap stop. A manual
            // stop cancels this task, so it won't double-fire.
            try? await Task.sleep(for: .seconds(Constants.maxRecordingDuration))
            if Task.isCancelled { return }
            if self.isRecording { self.cameraService.stopRecording() }
        }
    }

    private func beginRecording(angle: CameraAngle, club: GolfClub, modelContext: ModelContext) {
        errorMessage = nil
        cameraService.startRecording { [weak self] result in
            Task { @MainActor in
                await self?.finishRecording(result: result, angle: angle, club: club, modelContext: modelContext)
            }
        }
        isRecording = true
    }

    /// Manual early stop: end the clip now. The recording delegate fires
    /// `finishRecording`, which navigates to the result.
    private func stopRecordingEarly() {
        flowTask?.cancel()
        cameraService.stopRecording()
    }

    /// Cancel a countdown (before recording started), leaving the camera idle.
    private func cancelFlow() {
        flowTask?.cancel()
        flowTask = nil
        countdown = nil
    }

    // internal (not private): CaptureClubTests calls this directly with a
    // synthetic Result, bypassing the real camera — see plan Step 7 test
    // spec, which requires finishRecording to be test-reachable.
    func finishRecording(result: Result<URL, Error>,
                         angle: CameraAngle,
                         club: GolfClub,
                         modelContext: ModelContext) async {
        isRecording = false
        flowTask = nil
        let wasTearingDown = isTearingDown
        isTearingDown = false
        switch result {
        case .success(let url):
            let asset = AVURLAsset(url: url)
            let duration = (try? await asset.load(.duration).seconds) ?? 0
            let session = SwingSession(cameraAngle: angle,
                                       videoFileName: url.lastPathComponent,
                                       duration: duration,
                                       handedness: .stored,
                                       club: club)
            modelContext.insert(session)
            GolfClub.setStoredDefault(club)
            if !wasTearingDown {
                lastRecordedSession = session
            }
        case .failure:
            // Friendlier than the raw AVFoundation error description.
            errorMessage = "That recording couldn't be saved. Check that you have free storage space and try again."
        }
    }
}
