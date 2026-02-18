//
//  TimelineStripView.swift
//  BabyTime
//
//  Purely visual timeline bar with proportional colored segments
//  for sleep, feed, and awake periods. No labels — time info
//  comes from the event rows in the right column.
//

import SwiftUI

struct TimelineStripView: View {
    let day: TimelineDay
    let totalHeight: CGFloat

    private let barWidth: CGFloat = 12
    private let cornerRadius: CGFloat = 6

    var body: some View {
        ZStack(alignment: .top) {
            // Background track
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(Color.btBackgroundSecondary)

            // Colored segments
            ForEach(day.segments) { segment in
                let y1 = yOffset(for: segment.start)
                let y2 = yOffset(for: segment.end)
                let height = max(0, y2 - y1)

                if segment.kind != .awake && height > 0 {
                    color(for: segment.kind)
                        .frame(height: height)
                        .offset(y: y1)
                        .frame(maxHeight: .infinity, alignment: .top)
                }
            }
        }
        .frame(width: barWidth, height: totalHeight)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }

    // MARK: - Helpers

    private func yOffset(for time: Date) -> CGFloat {
        let total = day.dayEnd.timeIntervalSince(day.dayStart)
        guard total > 0 else { return 0 }
        let elapsed = time.timeIntervalSince(day.dayStart)
        let fraction = max(0, min(1, elapsed / total))
        return fraction * totalHeight
    }

    private func color(for kind: SegmentKind) -> Color {
        switch kind {
        case .sleep: return Color.btSleepAccent
        case .feed: return Color.btFeedAccent
        case .awake: return Color.btBackgroundSecondary
        }
    }
}
