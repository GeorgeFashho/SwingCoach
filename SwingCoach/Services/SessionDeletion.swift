//
//  SessionDeletion.swift
//  SwingCoach
//

import Foundation
import SwiftData

/// Deletes a session and everything it owns: the video file, the pose JSON
/// sidecar saved next to it, and the SwiftData row. AnalysisResult rows
/// cascade via the SwingSession relationship, so removing the session is
/// enough for the database side.
enum SessionDeletion {

    static func delete(_ session: SwingSession, in context: ModelContext) {
        try? FileManager.default.removeItem(
            at: PoseDataStore.poseDataURL(forVideo: session.videoURL))
        try? FileManager.default.removeItem(at: session.videoURL)
        context.delete(session)
    }
}
