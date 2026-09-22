//
//  ContentView.swift
//  SwingCoach
//
//  Created by George Fashho on 7/3/26.
//

import SwiftData
import SwiftUI

enum AppTab: Hashable {
    case record, history, progress, settings
}

extension EnvironmentValues {
    /// Lets an empty state's CTA jump the user to the Record tab.
    @Entry var switchToRecordTab: () -> Void = {}
}

struct ContentView: View {
    @State private var showOnboarding = OnboardingState.shouldShow()
    @State private var selectedTab: AppTab = .record

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Record", systemImage: "video.fill", value: AppTab.record) {
                CaptureView()
            }
            Tab("History", systemImage: "clock.arrow.circlepath", value: AppTab.history) {
                NavigationStack {
                    HistoryView()
                }
            }
            Tab("Progress", systemImage: "chart.line.uptrend.xyaxis", value: AppTab.progress) {
                NavigationStack {
                    ProgressTabView()
                }
            }
            Tab("Settings", systemImage: "gearshape.fill", value: AppTab.settings) {
                NavigationStack {
                    SettingsView()
                }
            }
        }
        .tint(.brandPrimary)
        .environment(\.switchToRecordTab) { selectedTab = .record }
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView()
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: SwingSession.self, inMemory: true)
}
