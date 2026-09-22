//
//  CaptureView.swift
//  SwingCoach
//

import AVFoundation
import SwiftData
import SwiftUI

struct CaptureView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = CaptureViewModel()

    var body: some View {
        ZStack {
            if viewModel.isSessionRunning {
                CameraPreviewView(session: viewModel.cameraService.session)
                    .ignoresSafeArea()
            } else {
                Color.black.ignoresSafeArea()
            }

            if viewModel.isPermissionDenied {
                permissionDeniedView
            } else {
                VStack {
                    if viewModel.isRecording {
                        recordingPill
                    }

                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .font(.callout)
                            .foregroundStyle(.white)
                            .padding()
                            .background(.red.opacity(0.85),
                                        in: RoundedRectangle(cornerRadius: Radius.m, style: .continuous))
                            .padding()
                    }

                    Spacer()

                    controls
                }
            }
        }
        .task {
            await viewModel.startCamera()
        }
        .onDisappear {
            viewModel.stopCamera()
        }
        .sheet(isPresented: $viewModel.showAngleGuide) {
            CameraAngleGuideView(focusAngle: viewModel.selectedAngle)
        }
        .overlay {
            if let countdown = viewModel.countdown {
                ZStack {
                    Color.black.opacity(0.35).ignoresSafeArea()
                    VStack(spacing: Space.m) {
                        Text("\(countdown)")
                            .font(.metric(128, .bold))
                            .monospacedDigit()
                            .foregroundStyle(.white)
                            .contentTransition(.numericText(countsDown: true))
                        Text("Walk to your ball and get set")
                            .font(.headline)
                            .foregroundStyle(.white.opacity(0.9))
                    }
                    .shadow(radius: 8)
                }
                .transition(.opacity)
            }
        }
        .animation(.snappy, value: viewModel.countdown)
        .sensoryFeedback(.impact(weight: .medium), trigger: viewModel.countdown)
        .fullScreenCover(isPresented: Binding(
            get: { viewModel.lastRecordedSession != nil },
            set: { if !$0 { viewModel.lastRecordedSession = nil } }
        )) {
            if let session = viewModel.lastRecordedSession {
                NavigationStack {
                    PlaybackView(session: session)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Done") { viewModel.lastRecordedSession = nil }
                            }
                        }
                }
            }
        }
    }

    /// Shown instead of the dead black preview when camera access is off:
    /// explains why and deep-links straight to the app's Settings page.
    private var permissionDeniedView: some View {
        ContentUnavailableView {
            Label("Camera Access Is Off", systemImage: "video.slash")
        } description: {
            Text("SwingCoach needs the camera to record your swing. Turn it on in Settings and come back — your swings stay on your phone.")
        } actions: {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .colorScheme(.dark)
    }

    private var isIdle: Bool { !viewModel.isRecording && viewModel.countdown == nil }

    private var controls: some View {
        VStack(spacing: Space.l) {
            if isIdle {
                statusHint

                Picker("Camera Angle", selection: $viewModel.selectedAngle) {
                    ForEach(CameraAngle.allCases) { angle in
                        Text(angle.displayName).tag(angle)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, Space.xxl)

                clubPicker

                Button {
                    viewModel.showAngleGuide = true
                } label: {
                    Label("Where do I put my phone?", systemImage: "questionmark.circle")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.white)
                }
            }

            recordButton
        }
        .padding(.bottom, Space.xl)
    }

    /// `.menu` style (not segmented, like the angle picker) since 15 clubs
    /// would overflow a segmented control.
    private var clubPicker: some View {
        Picker("Club", selection: $viewModel.selectedClub) {
            ForEach(GolfClub.allCases) { club in
                Text(club.displayName).tag(club)
            }
        }
        .pickerStyle(.menu)
        .tint(.white)
    }

    /// One-line reassurance so a solo beginner knows what to do before tapping.
    private var statusHint: some View {
        Text("Prop your phone so it can see you head to toe, then tap — I'll count you in.")
            .font(.footnote)
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .padding(.horizontal, Space.l)
            .padding(.vertical, Space.s)
            .background(.ultraThinMaterial,
                        in: RoundedRectangle(cornerRadius: Radius.l, style: .continuous))
            .padding(.horizontal, Space.xl)
    }

    /// Fairway-green "start" when idle; the universal red rounded-square when
    /// recording (red here means "recording", never "critical" — severity
    /// colors never appear on this screen).
    private var recordButton: some View {
        Button {
            viewModel.handleRecordButton(modelContext: modelContext)
        } label: {
            ZStack {
                Circle()
                    .stroke(.white, lineWidth: 4)
                    .frame(width: 76, height: 76)
                if viewModel.isRecording {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color(.systemRed))
                        .frame(width: 32, height: 32)
                } else {
                    Circle()
                        .fill(Color.brandPrimary)
                        .frame(width: 62, height: 62)
                        .overlay {
                            Image(systemName: "figure.golf")
                                .font(.title2)
                                .foregroundStyle(.white)
                        }
                }
            }
        }
        .disabled(!viewModel.isSessionRunning)
        .animation(.snappy, value: viewModel.isRecording)
    }

    /// HIG-style recording indicator shown while capturing.
    private var recordingPill: some View {
        HStack(spacing: Space.s) {
            Circle()
                .fill(Color(.systemRed))
                .frame(width: 10, height: 10)
            Text("Recording — take your normal swing")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, Space.m)
        .padding(.vertical, Space.s)
        .background(.ultraThinMaterial, in: Capsule())
        .padding(.top, Space.s)
    }
}

/// Hosts an AVCaptureVideoPreviewLayer so SwiftUI can show the live camera feed.
struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {}
}

#Preview {
    CaptureView()
        .modelContainer(for: SwingSession.self, inMemory: true)
}
