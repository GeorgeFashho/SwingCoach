//
//  SettingsView.swift
//  SwingCoach
//

import SwiftData
import SwiftUI

struct SettingsView: View {
    @AppStorage(Handedness.storageKey) private var handednessRawValue = Handedness.right.rawValue
    @Environment(\.modelContext) private var modelContext
    @Query private var sessions: [SwingSession]
    @State private var showOnboarding = false
    @State private var showResetProgressConfirm = false
    @State private var showDeleteAllConfirm = false

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    var body: some View {
        Form {
            Section {
                Picker("Handedness", selection: $handednessRawValue) {
                    ForEach(Handedness.allCases, id: \.rawValue) { hand in
                        Text(hand.displayName).tag(hand.rawValue)
                    }
                }
            } footer: {
                Text("Which hand you swing with. Changing this re-analyzes each saved swing the next time you open it, tracking the other lead wrist.")
            }

            Section {
                Button("Replay the Intro") {
                    showOnboarding = true
                }
            } footer: {
                Text("See the welcome tour again — what the app measures and how to set up your phone.")
            }

            Section {
                Button("Reset Progress") { showResetProgressConfirm = true }
                Button("Delete All Swings", role: .destructive) { showDeleteAllConfirm = true }
            } header: {
                Text("Data")
            } footer: {
                Text("Reset Progress starts your charts fresh from today — your saved swings and videos stay in History. Delete All Swings permanently removes every recording.")
            }

            Section("About") {
                LabeledContent("Version", value: appVersion)
                LabeledContent("Privacy", value: "Stays on your phone")
            }
        }
        .tint(.brandPrimary)
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView()
        }
        .navigationTitle("Settings")
        .onChange(of: handednessRawValue) { _, newValue in
            guard let handedness = Handedness(rawValue: newValue) else { return }
            HandednessChange.apply(handedness, to: sessions, in: modelContext)
        }
        .confirmationDialog("Reset your progress?", isPresented: $showResetProgressConfirm, titleVisibility: .visible) {
            Button("Reset Progress") { ProgressBaseline.date = .now }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your progress charts start fresh from today. Your swings and videos stay in History.")
        }
        .confirmationDialog("Delete all swings?", isPresented: $showDeleteAllConfirm, titleVisibility: .visible) {
            Button("Delete All Swings", role: .destructive) {
                SwingDataReset.deleteAllSwings(sessions, in: modelContext)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently deletes every recording, video, and result. This can't be undone.")
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
    .modelContainer(for: SwingSession.self, inMemory: true)
}
