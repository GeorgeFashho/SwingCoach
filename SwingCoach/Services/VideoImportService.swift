//
//  VideoImportService.swift
//  SwingCoach
//

import AVFoundation
import CoreTransferable
import Foundation
import UniformTypeIdentifiers

/// A video picked from the photo library, copied to a temporary file.
/// The picker's source file only exists for the duration of the importing
/// closure, so it must be copied out synchronously there.
nonisolated struct ImportedVideo: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .movie) { received in
            let destination = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(received.file.pathExtension)
            try FileManager.default.copyItem(at: received.file, to: destination)
            return ImportedVideo(url: destination)
        }
    }
}

/// Validates a picked video and files it into Documents/Videos so it
/// behaves exactly like a recorded session (playback, pose detection,
/// and analysis all work unchanged).
nonisolated enum VideoImportService {

    enum ImportError: LocalizedError {
        case tooLong(seconds: Int)
        case unreadable

        var errorDescription: String? {
            switch self {
            case .tooLong(let seconds):
                "That video is \(seconds) seconds long. Imports are capped at \(Int(Constants.maxImportDuration)) seconds so analysis stays fast. Trim the clip in Photos (Edit, then drag the ends in) and try again."
            case .unreadable:
                "That video could not be read. Try a different clip."
            }
        }
    }

    /// Checks the duration cap and moves the temp file into Documents/Videos.
    /// Returns the stored file name and duration for the new SwingSession.
    /// The temp file is always removed on failure.
    static func finalizeImport(of tempURL: URL) async throws -> (fileName: String, duration: TimeInterval) {
        do {
            let asset = AVURLAsset(url: tempURL)
            guard let duration = try? await asset.load(.duration).seconds, duration > 0 else {
                throw ImportError.unreadable
            }
            guard duration <= Constants.maxImportDuration else {
                throw ImportError.tooLong(seconds: Int(duration.rounded()))
            }

            let directory = SwingSession.videosDirectory
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let fileExtension = tempURL.pathExtension.isEmpty ? "mov" : tempURL.pathExtension
            let fileName = "\(UUID().uuidString).\(fileExtension)"
            try FileManager.default.moveItem(at: tempURL, to: directory.appendingPathComponent(fileName))
            return (fileName, duration)
        } catch {
            try? FileManager.default.removeItem(at: tempURL)
            throw error
        }
    }
}
