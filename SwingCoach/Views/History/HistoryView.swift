//
//  HistoryView.swift
//  SwingCoach
//

import AVFoundation
import SwiftData
import SwiftUI

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SwingSession.date, order: .reverse) private var sessions: [SwingSession]

    var body: some View {
        Group {
            if sessions.isEmpty {
                ContentUnavailableView(
                    "No Swings Yet",
                    systemImage: "figure.golf",
                    description: Text("Record your first swing from the Record tab and it will show up here.")
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
