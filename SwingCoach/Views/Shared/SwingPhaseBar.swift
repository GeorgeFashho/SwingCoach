//
//  SwingPhaseBar.swift
//  SwingCoach
//

import SwiftUI

/// Timeline bar under the video: one colored segment per swing phase plus a
/// playhead marker that tracks the current playback time.
struct SwingPhaseBar: View {
    let phases: SwingPhases
    let duration: TimeInterval
    let currentTime: TimeInterval

    private var total: TimeInterval {
        max(duration, phases.followThroughEnd, 0.01)
    }

    private var segments: [(phase: SwingPhase, start: TimeInterval, end: TimeInterval)] {
        [(.address, 0, phases.addressEnd),
         (.backswing, phases.addressEnd, phases.top),
         (.downswing, phases.top, phases.impact),
         (.followThrough, phases.impact, phases.followThroughEnd)]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            GeometryReader { geometry in
                ZStack(alignment: .topLeading) {
                    HStack(spacing: 0) {
                        ForEach(segments, id: \.phase) { segment in
                            Rectangle()
                                .fill(Self.color(for: segment.phase))
                                .frame(width: width(forStart: segment.start,
                                                    end: segment.end,
                                                    barWidth: geometry.size.width))
                        }
                        Spacer(minLength: 0)
                    }
                    Rectangle()
                        .fill(.white)
                        .frame(width: 2)
                        .offset(x: playheadOffset(barWidth: geometry.size.width))
                }
            }
            .frame(height: 14)
            .clipShape(RoundedRectangle(cornerRadius: 4))

            HStack(spacing: 12) {
                ForEach(SwingPhase.allCases, id: \.self) { phase in
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Self.color(for: phase))
                            .frame(width: 7, height: 7)
                        Text(phase.displayName)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func width(forStart start: TimeInterval, end: TimeInterval, barWidth: CGFloat) -> CGFloat {
        barWidth * CGFloat(max(0, end - start) / total)
    }

    private func playheadOffset(barWidth: CGFloat) -> CGFloat {
        barWidth * CGFloat(min(max(currentTime, 0), total) / total) - 1
    }

    static func color(for phase: SwingPhase) -> Color {
        switch phase {
        case .address: .gray
        case .backswing: .blue
        case .downswing: .orange
        case .followThrough: .green
        }
    }
}
