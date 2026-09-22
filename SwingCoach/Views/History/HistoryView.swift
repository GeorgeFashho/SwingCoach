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
    @Environment(\.switchToRecordTab) private var switchToRecordTab
    @Query(sort: \SwingSession.date, order: .reverse) private var sessions: [SwingSession]

    @State private var pickedVideo: PhotosPickerItem?
    @State private var isImporting = false
    /// An imported video already filed into Documents/Videos, waiting for
    /// the user to say which camera angle it was filmed from.
    @State private var pendingImport: (fileName: String, duration: TimeInterval)?
    @State private var importErrorMessage: String?
    @State private var clubFilter: GolfClub?

    var body: some View {
        Group {
            if sessions.isEmpty {
                ContentUnavailableView {
                    Label("No Swings Yet", systemImage: "figure.golf")
                } description: {
                    Text("Record your first swing and it'll show up here — every swing saved, so you can look back and see how far you've come.")
                } actions: {
                    Button("Record a Swing") { switchToRecordTab() }
                        .buttonStyle(PrimaryButtonStyle())
                        .frame(maxWidth: 260)
                }
            } else {
                List {
                    ForEach(filteredGroupedSessions, id: \.day) { group in
                        Section {
                            ForEach(group.sessions) { session in
                                NavigationLink {
                                    PlaybackView(session: session)
                                } label: {
                                    SessionRow(session: session)
                                }
                            }
                            .onDelete { offsets in
                                deleteSessions(at: offsets, in: group.sessions)
                            }
                        } header: {
                            Text(group.day, format: .dateTime.weekday(.wide).month().day())
                        }
                    }
                }
            }
        }
        .navigationTitle("History")
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Menu {
                    Button("All Clubs") { clubFilter = nil }
                    Divider()
                    ForEach(GolfClub.allCases) { club in
                        Button(club.displayName) { clubFilter = club }
                    }
                } label: {
                    Label(clubFilter?.displayName ?? "All Clubs", systemImage: "line.3.horizontal.decrease.circle")
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                if isImporting {
                    ProgressView()
                } else {
                    PhotosPicker(selection: $pickedVideo, matching: .videos) {
                        Label("Import Video", systemImage: "square.and.arrow.down")
                    }
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
        } catch let error as VideoImportService.ImportError {
            importErrorMessage = error.localizedDescription
        } catch {
            // Unexpected write failures (e.g. disk full) — friendlier than
            // the raw Cocoa error string.
            importErrorMessage = "That video couldn't be saved. Check that you have free storage space and try again."
        }
    }

    private func savePendingImport(angle: CameraAngle) {
        guard let pendingImport else { return }
        let session = SwingSession(cameraAngle: angle,
                                   videoFileName: pendingImport.fileName,
                                   duration: pendingImport.duration,
                                   handedness: .stored)
        session.golfClub = GolfClub.storedDefault
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

    /// Sessions grouped by calendar day, newest day first, after applying
    /// `clubFilter`. Within a day the sessions keep the query's newest-first
    /// order.
    private var filteredGroupedSessions: [(day: Date, sessions: [SwingSession])] {
        let calendar = Calendar.current
        let groups = Dictionary(grouping: Self.filter(sessions, by: clubFilter)) { calendar.startOfDay(for: $0.date) }
        return groups.keys.sorted(by: >).map { (day: $0, sessions: groups[$0]!) }
    }

    /// Pure, testable club filter: `nil` returns every session; a specific
    /// club returns only sessions whose `golfClub` matches (nil-club and
    /// unrecognized-raw sessions are excluded, and only appear under "All").
    static func filter(_ sessions: [SwingSession], by club: GolfClub?) -> [SwingSession] {
        guard let club else { return sessions }
        return sessions.filter { $0.golfClub == club }
    }

    private func deleteSessions(at offsets: IndexSet, in daySessions: [SwingSession]) {
        for index in offsets {
            SessionDeletion.delete(daySessions[index], in: modelContext)
        }
    }
}

private struct SessionRow: View {
    let session: SwingSession

    var body: some View {
        HStack(spacing: 12) {
            VideoThumbnailView(videoURL: session.videoURL)

            VStack(alignment: .leading, spacing: 4) {
                Text(session.date, format: .dateTime.hour().minute())
                    .font(.headline)
                HStack(spacing: 8) {
                    Text(session.angle.displayName)
                    Text("·")
                    Text(String(format: "%.1fs", session.duration))
                    Text("·")
                    Text(session.clubLabel)
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
