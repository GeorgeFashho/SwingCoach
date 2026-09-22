//
//  CameraAngleGuideView.swift
//  SwingCoach
//

import SwiftUI

/// Explains where to place the phone for each camera angle, in plain English.
/// When opened from the capture screen, `focusAngle` lifts the angle the
/// user is about to record to the top and labels it.
struct CameraAngleGuideView: View {
    var focusAngle: CameraAngle?

    @Environment(\.dismiss) private var dismiss

    /// The focused angle first, then the rest in their usual order.
    private var orderedAngles: [CameraAngle] {
        guard let focusAngle else { return CameraAngle.allCases }
        return [focusAngle] + CameraAngle.allCases.filter { $0 != focusAngle }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(orderedAngles) { angle in
                    Section {
                        HStack(alignment: .top, spacing: 16) {
                            Image(systemName: angle == .faceOn ? "person.fill" : "figure.golf")
                                .font(.largeTitle)
                                .foregroundStyle(.tint)
                                .frame(width: 52)
                            Text(angle.explanation)
                                .font(.body)
                        }
                        .padding(.vertical, 4)
                    } header: {
                        if angle == focusAngle {
                            Text("\(angle.displayName) — you're set to record this")
                        } else {
                            Text(angle.displayName)
                        }
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
