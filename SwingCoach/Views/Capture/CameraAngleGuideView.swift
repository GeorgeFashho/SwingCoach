//
//  CameraAngleGuideView.swift
//  SwingCoach
//

import SwiftUI

/// Explains where to place the phone for each camera angle, in plain English.
struct CameraAngleGuideView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(CameraAngle.allCases) { angle in
                    Section(angle.displayName) {
                        HStack(alignment: .top, spacing: 16) {
                            Image(systemName: angle == .faceOn ? "person.fill" : "figure.golf")
                                .font(.largeTitle)
                                .foregroundStyle(.tint)
                                .frame(width: 52)
                            Text(angle.explanation)
                                .font(.body)
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section("Tips") {
                    Label("Place the phone about waist height — a tripod or lean it against your golf bag works.", systemImage: "iphone")
                    Label("Stand 8–10 feet (3 big steps) away so your whole body is in frame.", systemImage: "figure.stand")
                    Label("Record in good light and wear clothing that shows your body shape.", systemImage: "sun.max")
                }
                .font(.callout)
            }
            .navigationTitle("Camera Setup")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    CameraAngleGuideView()
}
