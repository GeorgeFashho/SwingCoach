//
//  PlaybackView.swift
//  SwingCoach
//

import AVFoundation
import SwiftData
import SwiftUI

struct PlaybackView: View {
    let session: SwingSession

    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: PlaybackViewModel

    init(session: SwingSession) {
        self.session = session
        _viewModel = State(initialValue: PlaybackViewModel(session: session))
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                PlayerLayerView(player: viewModel.player)
                if let poseFrame = viewModel.currentPoseFrame, viewModel.videoDisplaySize != .zero {
                    PoseOverlayView(frame: poseFrame, videoSize: viewModel.videoDisplaySize)
                }
                if isAtAddressPhase, let linePoints = session.shaftLinePoints, viewModel.videoDisplaySize != .zero {
                    ShaftOverlayView(linePoints: linePoints, videoSize: viewModel.videoDisplaySize)
                }
            }
            .background(.black)
            .containerRelativeFrame(.vertical) { length, _ in length * 0.42 }

            clubRow
                .padding(.horizontal)
                .padding(.top, Space.s)

            if viewModel.phases != nil {
                shaftRow
                    .padding(.horizontal)
                    .padding(.top, Space.xs)
            }

            ScrollView {
                analysisSection
                    .padding(.horizontal)
                    .padding(.vertical, 12)
            }

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

    /// The club used for this swing, with a prominent inline control to
    /// correct it. Editing club is metadata-only: it never touches
    /// `analysisResults` or triggers a recompute (scores are club-agnostic).
    private var clubRow: some View {
        HStack {
            Label(session.clubLabel, systemImage: "figure.golf")
                .font(.subheadline.weight(.medium))
            Spacer()
            Menu {
                ForEach(GolfClub.allCases) { club in
                    Button(club.displayName) { updateClub(to: club) }
                }
            } label: {
                Label("Change Club", systemImage: "pencil.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.brandPrimary)
            }
        }
    }

    private func updateClub(to club: GolfClub) {
        session.golfClub = club
        try? modelContext.save()
    }

    /// True while the scrubber is within the address phase — the phase the
    /// shaft estimate was actually computed from, so the overlay only makes
    /// sense here.
    private var isAtAddressPhase: Bool {
        guard let phases = viewModel.phases else { return false }
        return viewModel.currentTime <= phases.addressEnd
    }

    /// The shaft-angle-at-address readout, metadata-only like clubRow: no
    /// recompute, no analysisResults changes. Low confidence (or an
    /// unreadable frame) shows an honest message instead of a number.
    private var shaftRow: some View {
        Group {
            if let angle = session.shaftAngleAtAddress {
                Label("Shaft angle at address: \(Int(angle.rounded()))°", systemImage: "figure.golf")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            } else {
                Label("Shaft angle: couldn't read the club — try a down-the-line angle in good light.",
                      systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(Severity.needsWork.text)
            }
        }
    }

    private var controls: some View {
        VStack(spacing: 16) {
            poseControls

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

    /// Pose detection entry point: a "Detect Pose" button until joint data
    /// exists, a progress bar while Vision processes the video, and a
    /// show/hide toggle once the skeleton is available.
    @ViewBuilder
    private var poseControls: some View {
        if viewModel.isDetectingPose {
            VStack(spacing: 4) {
                ProgressView(value: viewModel.detectionProgress)
                Text("Detecting pose… \(Int(viewModel.detectionProgress * 100))%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } else if viewModel.poseFrames != nil {
            Toggle(isOn: Binding(
                get: { viewModel.isOverlayEnabled },
                set: { viewModel.isOverlayEnabled = $0 }
            )) {
                Label("Skeleton overlay", systemImage: "figure.golf")
            }
        } else {
            VStack(spacing: 4) {
                Button {
                    viewModel.detectPose()
                } label: {
                    Label("Detect Pose", systemImage: "figure.golf")
                }
                .buttonStyle(.borderedProminent)

                if let message = viewModel.detectionErrorMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
    }

    /// The session detail content under the video: the phase timeline plus
    /// the full analysis summary, or a friendly re-record message when
    /// segmentation fails.
    @ViewBuilder
    private var analysisSection: some View {
        if viewModel.isDetectingPose {
            analyzingState
        } else if let phases = viewModel.phases {
            VStack(alignment: .leading, spacing: Space.l) {
                if viewModel.isLowPoseQuality {
                    lowPoseQualityBanner
                }
                // Hero: the one thing to fix first (or honest praise).
                coachingCard

                // Everything else is one tap deeper (progressive disclosure).
                DisclosureGroup {
                    VStack(alignment: .leading, spacing: Space.l) {
                        SwingPhaseBar(phases: phases,
                                      duration: viewModel.duration,
                                      currentTime: viewModel.currentTime)
                        AnalysisView(outcomes: viewModel.checkOutcomes,
                                     cameraAngle: session.angle)
                    }
                    .padding(.top, Space.s)
                } label: {
                    Text("See full breakdown")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.brandPrimary)
                }
            }
        } else if let message = viewModel.segmentationFailureMessage {
            reRecordCard(message)
        }
    }

    /// The payoff-is-coming state while Vision analyzes a fresh swing — a real
    /// moment, not a bare spinner.
    private var analyzingState: some View {
        VStack(spacing: Space.m) {
            ProgressView(value: viewModel.detectionProgress)
                .tint(Color.brandPrimary)
                .frame(maxWidth: 220)
            Text("Analyzing your swing…")
                .font(.headline)
            Text("Looking at your posture, turn, and tempo.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Space.xxl)
    }

    /// Friendly, on-brand "couldn't read that one" state.
    private func reRecordCard(_ message: String) -> some View {
        VStack(spacing: Space.m) {
            Image(systemName: "arrow.counterclockwise.circle")
                .font(.largeTitle)
                .foregroundStyle(Color.brandPrimary)
            Text(message)
                .font(.callout)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .cardSurface()
    }

    /// The per-swing coaching card, in three unambiguous states (plan Stage 1):
    /// all checks good → positive card; else a worst check exists → "fix this
    /// first" card; else (no scored checks) → nothing. Below it, the
    /// cross-session focus-area reminder shows when it adds something new
    /// (plan Stage 2): in the all-good branch always (the card names no check);
    /// in the worst-check branch only when the focus differs from this swing's
    /// worst check, to avoid duplicating it.
    @ViewBuilder
    private var coachingCard: some View {
        if viewModel.allChecksGood {
            AllChecksGoodCardView(message: FeedbackGenerator.allChecksGoodMessage)
            if let focusArea = viewModel.focusArea {
                focusReminder(focusArea)
            }
        } else if let worst = viewModel.worstCheck, let drill = viewModel.worstCheckDrill {
            CoachingCardView(result: worst, drill: drill)
            if let focusArea = viewModel.focusArea, focusArea.checkName != worst.checkName {
                focusReminder(focusArea)
            }
        }
    }

    private func focusReminder(_ focusArea: CoachingEngine.FocusAreaResult) -> some View {
        HStack(alignment: .top, spacing: Space.s) {
            Image(systemName: "scope")
                .foregroundStyle(Color.brandPrimary)
            VStack(alignment: .leading, spacing: Space.xs / 2) {
                Text("Your overall focus: \(focusArea.checkName.displayName)")
                    .font(.caption.weight(.semibold))
                Text(FeedbackGenerator.drill(for: focusArea.checkName,
                                             measuredValue: focusArea.measuredValue))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(Space.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: Radius.m, style: .continuous))
    }

    private var lowPoseQualityBanner: some View {
        Label(FeedbackGenerator.lowPoseQualityWarning,
              systemImage: "exclamationmark.triangle.fill")
            .font(.footnote)
            .foregroundStyle(Severity.needsWork.text)
            .padding(Space.m)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Severity.needsWork.fill.opacity(0.15),
                        in: RoundedRectangle(cornerRadius: Radius.m, style: .continuous))
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
