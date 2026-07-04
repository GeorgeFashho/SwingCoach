//
//  CameraService.swift
//  SwingCoach
//

import AVFoundation
import Foundation

/// Owns the AVFoundation capture session: configures the back camera for
/// high-frame-rate (120fps) video and records clips into Documents/Videos.
///
/// All session work happens on a private serial queue; the session object
/// itself is exposed so the preview layer can attach to it.
/// @unchecked Sendable: all mutable state is confined to `sessionQueue`.
nonisolated final class CameraService: NSObject, @unchecked Sendable {

    enum CameraError: LocalizedError {
        case permissionDenied
        case noCameraAvailable
        case configurationFailed

        var errorDescription: String? {
            switch self {
            case .permissionDenied:
                "Camera access is turned off. Enable it in Settings > SwingCoach to record your swing."
            case .noCameraAvailable:
                "No camera was found on this device."
            case .configurationFailed:
                "The camera could not be set up. Try restarting the app."
            }
        }
    }

    let session = AVCaptureSession()

    private let movieOutput = AVCaptureMovieFileOutput()
    private let sessionQueue = DispatchQueue(label: "com.swingcoach.camera.session")
    private var isConfigured = false
    private var recordingCompletion: ((Result<URL, Error>) -> Void)?

    // MARK: - Permission

    func requestPermission() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .video)
        default:
            return false
        }
    }

    // MARK: - Session lifecycle

    /// Configures (once) and starts the capture session. Throws if no camera
    /// is available or configuration fails.
    func start() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            sessionQueue.async {
                do {
                    if !self.isConfigured {
                        try self.configureSession()
                        self.isConfigured = true
                    }
                    if !self.session.isRunning {
                        self.session.startRunning()
                    }
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func stop() {
        sessionQueue.async {
            if self.session.isRunning {
                self.session.stopRunning()
            }
        }
    }

    // MARK: - Recording

    /// Starts recording to a new file in Documents/Videos. The completion
    /// fires when recording finishes (after `stopRecording()` is called).
    func startRecording(completion: @escaping (Result<URL, Error>) -> Void) {
        sessionQueue.async {
            guard !self.movieOutput.isRecording else { return }
            do {
                let directory = SwingSession.videosDirectory
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                let url = directory.appendingPathComponent("\(UUID().uuidString).mov")
                self.recordingCompletion = completion
                self.movieOutput.startRecording(to: url, recordingDelegate: self)
            } catch {
                completion(.failure(error))
            }
        }
    }

    func stopRecording() {
        sessionQueue.async {
            if self.movieOutput.isRecording {
                self.movieOutput.stopRecording()
            }
        }
    }

    // MARK: - Configuration

    private func configureSession() throws {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            throw CameraError.noCameraAvailable
        }

        session.beginConfiguration()
        defer { session.commitConfiguration() }

        let input = try AVCaptureDeviceInput(device: device)
        guard session.canAddInput(input), session.canAddOutput(movieOutput) else {
            throw CameraError.configurationFailed
        }
        session.addInput(input)
        session.addOutput(movieOutput)

        configureFrameRate(for: device)
    }

    /// Selects the highest-resolution format (capped at 1080p) that supports
    /// 120fps and locks the frame duration to 1/120s. If the device has no
    /// 120fps format (older phones, simulator), the default format is kept.
    private func configureFrameRate(for device: AVCaptureDevice) {
        var bestFormat: AVCaptureDevice.Format?
        var bestHeight: Int32 = 0

        for format in device.formats {
            guard format.videoSupportedFrameRateRanges.contains(where: { $0.maxFrameRate >= 120 }) else {
                continue
            }
            let dimensions = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
            if dimensions.height <= 1080 && dimensions.height > bestHeight {
                bestFormat = format
                bestHeight = dimensions.height
            }
        }

        guard let format = bestFormat else { return }

        do {
            // Setting activeFormat directly requires inputPriority, otherwise
            // the session preset would override our 120fps format.
            session.sessionPreset = .inputPriority
            try device.lockForConfiguration()
            device.activeFormat = format
            let frameDuration = CMTime(value: 1, timescale: 120)
            device.activeVideoMinFrameDuration = frameDuration
            device.activeVideoMaxFrameDuration = frameDuration
            device.unlockForConfiguration()
        } catch {
            // Locking failed: the device keeps its default format, which still
            // records — just not at 120fps.
        }
    }
}

// MARK: - AVCaptureFileOutputRecordingDelegate

nonisolated extension CameraService: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput,
                    didFinishRecordingTo outputFileURL: URL,
                    from connections: [AVCaptureConnection],
                    error: Error?) {
        let completion = recordingCompletion
        recordingCompletion = nil
        if let error {
            completion?(.failure(error))
        } else {
            completion?(.success(outputFileURL))
        }
    }
}
