//
//  ContentView.swift
//  SwingCoach
//
//  Created by George Fashho on 7/3/26.
//

import SwiftData
import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            Tab("Record", systemImage: "video.fill") {
                CaptureView()
            }
            Tab("History", systemImage: "clock.arrow.circlepath") {
                NavigationStack {
                    HistoryView()
                }
            }
            Tab("Progress", systemImage: "chart.line.uptrend.xyaxis") {
                NavigationStack {
                    ContentUnavailableView(
                        "Progress Coming Soon",
                        systemImage: "chart.line.uptrend.xyaxis",
                        description: Text("Once swing analysis is built, your score trends will appear here.")
                    )
                    .navigationTitle("Progress")
                }
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: SwingSession.self, inMemory: true)
}
