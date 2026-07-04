//
//  HistoryView.swift
//  SwingCoach
//

import AVFoundation
import PhotosUI
import SwiftData
import SwiftUI

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SwingSession.date, order: .reverse) private var sessions: [SwingSession]

    @State private var pickedVideo: PhotosPickerItem?
    @State private var isImporting = false
    /// An imported video already filed into Documents/Videos, waiting for
    /// the user to say which camera angle it was filmed from.
    @State private var pendingImport: (fileName: String, duration: TimeInterval)?
    @State private var importErrorMessage: String?

    var body: some View {
        Group {
            if sessions.isEmpty {
                ContentUnavailableView(
                    "No Swings Yet",
                    systemImage: "figure.golf",
                    description: Text("Record your first swing from the Record tab, or import a video with the button above.")
                )
            } else {
                List {
                    ForEach(sessions) { session in
                        NavigationLink {
                            PlaybackView(session: session)
                        } label: {
                            SessionRow(session: session)
                        }
                    }
                    .onDelete(perform: deleteSessions)
                }
            }
        }
        .navigationTitle("History")
        .toolbar {
            if isImporting {
                ProgressView()
            } else {
                PhotosPicker(selection: $pickedVideo, matching: .videos) {
                    Label("Import Video", systemImage: "square.and.arrow.down")
                }
            }
        }
        .onChange(of: pickedVideo) { _, item in
            guard let item else { return }
            Task { await importVideo(from: item) }
        }
        .confirmationDialog(
            "Which angle was this filmed from?",
            isPresented: Binding(
                get: { pendingImport != nil },
                set: { if !$0 { cancelPendingImport() } }
            ),
            titleVisibility: .visible
        ) {
            ForEach(CameraAngle.allCases) { angle in
                Button(angle.displayName) { savePendingImport(angle: angle) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Face-On: the camera faced your chest. Down-the-Line: the camera was behind you, looking toward the target.")
        }
        .alert("Couldn't Import Video", isPresented: Binding(
            get: { importErrorMessage != nil },
            set: { if !$0 { importErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importErrorMessage ?? "")
        }
    }

    // MARK: - Import

    private func importVideo(from item: PhotosPickerItem) async {
        isImporting = true
        defer {
            isImporting = false
            pickedVideo = nil
        }
        do {
            guard let video = try await item.loadTransferable(type: ImportedVideo.self) else {
                throw VideoImportService.ImportError.unreadable
            }
            pendingImport = try await VideoImportService.finalizeImport(of: video.url)
        } catch {
            importErrorMessage = error.localizedDescription
        }
    }

    private func savePendingImport(angle: CameraAngle) {
        guard let pendingImport else { return }
        let session = SwingSession(cameraAngle: angle,
                                   videoFileName: pendingImport.fileName,
                                   duration: pendingImport.duration)
        modelContext.insert(session)
        self.pendingImport = nil
    }

    /// The user backed out of the angle question: remove the already-filed
    /// video so no orphaned file is left behind.
    private func cancelPendingImport() {
        guard let pendingImport else { return }
        try? FileManager.default.removeItem(
            at: SwingSession.videosDirectory.appendingPathComponent(pendingImport.fileName))
        self.pendingImport = nil
    }

    private func deleteSessions(offsets: IndexSet) {
        for index in offsets {
            let session = sessions[index]
            try? FileManager.default.removeItem(at: session.videoURL)
            modelContext.delete(session)
        }
    }
}

private struct SessionRow: View {
    let session: SwingSession

    var body: some View {
        HStack(spacing: 12) {
            VideoThumbnailView(videoURL: session.videoURL)

            VStack(alignment: .leading, spacing: 4) {
                Text(session.date, format: .dateTime.month().day().hour().minute())
                    .font(.headline)
                HStack(spacing: 8) {
                    Text(session.angle.displayName)
                    Text("·")
                    Text(String(format: "%.1fs", session.duration))
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
        }
    }
}

/// Loads the first frame of a video as a thumbnail image, off the main thread.
private struct VideoThumbnailView: View {
    let videoURL: URL

    @State private var thumbnail: UIImage?

    var body: some View {
        Group {
            if let thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .scaledToFill()
            } else {
                Rectangle()
                    .fill(.quaternary)
                    .overlay {
                        Image(systemName: "video")
                            .foregroundStyle(.secondary)
                    }
            }
        }
        .frame(width: 64, height: 64)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .task {
            guard thumbnail == nil else { return }
            let generator = AVAssetImageGenerator(asset: AVURLAsset(url: videoURL))
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: 200, height: 200)
            if let result = try? await generator.image(at: .zero) {
                thumbnail = UIImage(cgImage: result.image)
            }
        }
    }
}

#Preview {
    NavigationStack {
        HistoryView()
    }
    .modelContainer(for: SwingSession.self, inMemory: true)
}
