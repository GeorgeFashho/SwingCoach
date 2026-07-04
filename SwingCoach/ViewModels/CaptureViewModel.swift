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
    var isRecording = false
    var isSessionRunning = false
    var errorMessage: String?
    var showAngleGuide = false

    let cameraService = CameraService()

    /// Requests permission and starts the camera. Called when CaptureView appears.
    func startCamera() async {
        guard await cameraService.requestPermission() else {
            errorMessage = CameraService.CameraError.permissionDenied.errorDescription
            return
        }
        do {
            try await cameraService.start()
            isSessionRunning = true
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func stopCamera() {
        cameraService.stop()
        isSessionRunning = false
    }

    func toggleRecording(modelContext: ModelContext) {
        if isRecording {
            cameraService.stopRecording()
        } else {
            let angle = selectedAngle
            cameraService.startRecording { [weak self] result in
                Task { @MainActor in
                    await self?.finishRecording(result: result, angle: angle, modelContext: modelContext)
                }
            }
            isRecording = true
        }
    }

    private func finishRecording(result: Result<URL, Error>,
                                 angle: CameraAngle,
                                 modelContext: ModelContext) async {
        isRecording = false
        switch result {
        case .success(let url):
            let asset = AVURLAsset(url: url)
            let duration = (try? await asset.load(.duration).seconds) ?? 0
            let session = SwingSession(cameraAngle: angle,
                                       videoFileName: url.lastPathComponent,
                                       duration: duration)
            modelContext.insert(session)
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }
}
