//
//  OnboardingView.swift
//  SwingCoach
//

import SwiftUI

/// The first-launch intro: what the app does, how to set up your phone, and
/// what the two camera angles mean. Replayable from Settings.
struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var currentPage = 0

    private static let lastPage = 2

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $currentPage) {
                welcomePage.tag(0)
                setupPage.tag(1)
                anglesPage.tag(2)
            }
            .tabViewStyle(.page)
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            VStack(spacing: Space.m) {
                Button {
                    if currentPage < Self.lastPage {
                        withAnimation { currentPage += 1 }
                    } else {
                        OnboardingState.markSeen()
                        dismiss()
                    }
                } label: {
                    Text(currentPage < Self.lastPage ? "Next" : "Get Started")
                }
                .buttonStyle(PrimaryButtonStyle())

                if currentPage < Self.lastPage {
                    Button("Skip") {
                        OnboardingState.markSeen()
                        dismiss()
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.brandPrimary)
                }
            }
            .padding(.horizontal, Space.xl)
            .padding(.vertical, Space.l)
        }
    }

    private var welcomePage: some View {
        page(systemImage: "figure.golf",
             title: "Meet Your Swing Coach") {
            Text("Record your golf swing with your phone, and SwingCoach will look at how your body moves — your posture, your turn, your tempo — and tell you what's working and what to practice, in plain English.")
            Text("No jargon, no guesswork. Just film a swing and see for yourself.")
        }
    }

    private var setupPage: some View {
        page(systemImage: "iphone.gen3",
             title: "Setting Up Your Phone") {
            Text("Prop your phone up at about waist height — a small tripod is great, but leaning it against your golf bag works too.")
            Text("Stand 8–10 feet away (about 3 big steps) so your whole body fits in the frame.")
            Text("Good light helps a lot: film outdoors or in a bright room, and wear clothes that show your body shape.")
        }
    }

    private var anglesPage: some View {
        page(systemImage: "camera.viewfinder",
             title: "Two Ways to Film") {
            ForEach(CameraAngle.allCases) { angle in
                VStack(alignment: .leading, spacing: 4) {
                    Text(angle.displayName)
                        .font(.headline)
                    Text(angle.explanation)
                }
            }
            Text("Try recording from both — each angle lets the app measure different things.")
        }
    }

    private func page(systemImage: String,
                      title: String,
                      @ViewBuilder content: () -> some View) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.l) {
                Image(systemName: systemImage)
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundStyle(Color.brandPrimary)
                    .frame(width: 96, height: 96)
                    .background(Color.brandPrimary.opacity(0.12), in: Circle())
                    .frame(maxWidth: .infinity)
                    .padding(.top, Space.xxl)

                Text(title)
                    .font(.largeTitle.bold())
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)

                content()
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, Space.xl)
        }
    }
}

#Preview {
    OnboardingView()
}
