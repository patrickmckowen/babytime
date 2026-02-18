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
        Canvas { context, size in
            let rect = CGRect(origin: .zero, size: size)
            let shape = RoundedRectangle(cornerRadius: cornerRadius)
            let path = shape.path(in: rect)

            // Background track
            context.fill(path, with: .color(Color.btBackgroundSecondary))

            // Draw colored segments clipped to the rounded rect
            for segment in day.segments where segment.kind != .awake {
                let y1 = yPosition(for: segment.start)
                let y2 = yPosition(for: segment.end)
                let segHeight = max(0, y2 - y1)
                guard segHeight > 0 else { continue }

                let segRect = CGRect(x: 0, y: y1, width: size.width, height: segHeight)
                let segPath = Path(segRect).intersection(path)
                context.fill(segPath, with: .color(color(for: segment.kind)))
            }
        }
        .frame(width: barWidth, height: totalHeight)
    }

    // MARK: - Helpers

    private func yPosition(for time: Date) -> CGFloat {
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
