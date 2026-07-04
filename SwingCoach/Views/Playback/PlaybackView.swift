//
//  PlaybackView.swift
//  SwingCoach
//

import AVFoundation
import SwiftUI

struct PlaybackView: View {
    let session: SwingSession

    @State private var viewModel: PlaybackViewModel

    init(session: SwingSession) {
        self.session = session
        _viewModel = State(initialValue: PlaybackViewModel(videoURL: session.videoURL))
    }

    var body: some View {
        VStack(spacing: 0) {
            PlayerLayerView(player: viewModel.player)
                .background(.black)

            controls
                .padding()
        }
        .navigationTitle(session.angle.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.startObserving()
        }
        .onDisappear {
            viewModel.stopObserving()
        }
    }

    private var controls: some View {
        VStack(spacing: 16) {
            HStack(spacing: 8) {
                Text(timeString(viewModel.currentTime))
                    .font(.caption.monospacedDigit())
                Slider(
                    value: Binding(
                        get: { viewModel.currentTime },
                        set: { viewModel.seek(to: $0) }
                    ),
                    in: 0...max(viewModel.duration, 0.01)
                ) { editing in
                    viewModel.isScrubbing = editing
                }
                Text(timeString(viewModel.duration))
                    .font(.caption.monospacedDigit())
            }

            HStack(spacing: 32) {
                Picker("Speed", selection: Binding(
                    get: { viewModel.playbackRate },
                    set: { viewModel.setRate($0) }
                )) {
                    ForEach(PlaybackViewModel.availableRates, id: \.self) { rate in
                        Text(rate == 1.0 ? "1x" : String(format: "%g×", rate)).tag(rate)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 200)

                Button {
                    viewModel.togglePlayback()
                } label: {
                    Image(systemName: viewModel.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 52))
                }
            }
        }
    }

    private func timeString(_ seconds: Double) -> String {
        guard seconds.isFinite else { return "0:00" }
        let total = Int(seconds)
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

/// Hosts an AVPlayerLayer so we can show video with fully custom controls.
struct PlayerLayerView: UIViewRepresentable {
    let player: AVPlayer

    final class PlayerView: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    }

    func makeUIView(context: Context) -> PlayerView {
        let view = PlayerView()
        view.playerLayer.player = player
        view.playerLayer.videoGravity = .resizeAspect
        return view
    }

    func updateUIView(_ uiView: PlayerView, context: Context) {}
}
