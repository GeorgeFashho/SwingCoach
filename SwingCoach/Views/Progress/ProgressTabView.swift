//
//  ProgressTabView.swift
//  SwingCoach
//

import Charts
import SwiftData
import SwiftUI

/// The Progress tab: one line chart per check showing score trends across
/// analyzed sessions. Named ProgressTabView (not ProgressView) so it doesn't
/// shadow SwiftUI.ProgressView, which other screens use for spinners.
struct ProgressTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.switchToRecordTab) private var switchToRecordTab
    @State private var viewModel = ProgressViewModel()
    @State private var granularity: ProgressGranularity = .session
    @State private var clubFilter: GolfClub?

    var body: some View {
        Group {
            if viewModel.analyzedSessionCount < Constants.minSessionsForProgress {
                emptyState
            } else {
                List {
                    Section {
                        Picker("View", selection: $granularity) {
                            ForEach(ProgressGranularity.allCases) { g in Text(g.label).tag(g) }
                        }
                        .pickerStyle(.segmented)
                    }
                    if let focusArea = viewModel.focusArea {
                        Section {
                            FocusAreaCardView(focusArea: focusArea)
                                .listRowInsets(EdgeInsets())
                                .listRowBackground(Color.clear)
                        }
                    }
                    ForEach(ProgressViewModel.bucketed(viewModel.trends, by: granularity)) { trend in
                        Section(trend.check.displayName) {
                            trendChart(trend)
                        }
                    }
                }
            }
        }
        .navigationTitle("Progress")
        .toolbar {
            Menu {
                Button("All Clubs") { clubFilter = nil }
                ForEach(GolfClub.allCases) { club in
                    Button(club.displayName) { clubFilter = club }
                }
            } label: {
                Label(clubFilter?.displayName ?? "All Clubs", systemImage: "line.3.horizontal.decrease.circle")
            }
        }
        .onAppear {
            viewModel.reload(from: modelContext, baseline: ProgressBaseline.date, clubFilter: clubFilter)
        }
        .onChange(of: clubFilter) { _, newValue in
            viewModel.reload(from: modelContext, baseline: ProgressBaseline.date, clubFilter: newValue)
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("Your Progress Starts Here", systemImage: "chart.line.uptrend.xyaxis")
        } description: {
            Text("Once you've analyzed \(Constants.minSessionsForProgress) swings, your score trends and focus area show up here. You've analyzed \(viewModel.analyzedSessionCount) so far — keep swinging!")
        } actions: {
            Button("Record a Swing") { switchToRecordTab() }
                .buttonStyle(PrimaryButtonStyle())
                .frame(maxWidth: 260)
        }
    }

    private func trendChart(_ trend: ProgressViewModel.CheckTrend) -> some View {
        Chart(trend.points) { point in
            LineMark(
                x: .value("Date", point.date),
                y: .value("Score", point.score)
            )
            .foregroundStyle(.secondary)

            PointMark(
                x: .value("Date", point.date),
                y: .value("Score", point.score)
            )
            .foregroundStyle(point.severity.color)
        }
        .chartYScale(domain: 0...100)
        .frame(height: 160)
        .padding(.vertical, 8)
    }
}

#Preview {
    NavigationStack {
        ProgressTabView()
    }
    .modelContainer(for: SwingSession.self, inMemory: true)
}
