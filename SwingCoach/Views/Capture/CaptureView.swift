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

            VStack {
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(.callout)
                        .foregroundStyle(.white)
                        .padding()
                        .background(.red.opacity(0.8), in: RoundedRectangle(cornerRadius: 12))
                        .padding()
                }

                Spacer()

                controls
            }
        }
        .task {
            await viewModel.startCamera()
        }
        .onDisappear {
            viewModel.stopCamera()
        }
        .sheet(isPresented: $viewModel.showAngleGuide) {
            CameraAngleGuideView()
        }
    }

    private var controls: some View {
        VStack(spacing: 16) {
            if !viewModel.isRecording {
                Picker("Camera Angle", selection: $viewModel.selectedAngle) {
                    ForEach(CameraAngle.allCases) { angle in
                        Text(angle.displayName).tag(angle)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 40)

                Button {
                    viewModel.showAngleGuide = true
                } label: {
                    Label("Where do I put my phone?", systemImage: "questionmark.circle")
                        .font(.footnote)
                        .foregroundStyle(.white)
                }
            }

            Button {
                viewModel.toggleRecording(modelContext: modelContext)
            } label: {
                ZStack {
                    Circle()
                        .stroke(.white, lineWidth: 4)
                        .frame(width: 72, height: 72)
                    if viewModel.isRecording {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(.red)
                            .frame(width: 32, height: 32)
                    } else {
                        Circle()
                            .fill(.red)
                            .frame(width: 58, height: 58)
                    }
                }
            }
            .disabled(!viewModel.isSessionRunning)
        }
        .padding(.bottom, 24)
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
