//
//  DayRhythmBar.swift
//  BabyTime
//
//  Horizontal day-rhythm bar: wake-to-bedtime with color bands
//  for sleep and feed activities. Tick marks every 2 hours.
//  "Now" indicator line for today.
//

import SwiftUI

struct DayRhythmBar: View {
    let day: TimelineDay

    private let barHeight: CGFloat = 32
    private let cornerRadius: CGFloat = 6
    private let tickHeight: CGFloat = 6
    private let tickLabelGap: CGFloat = 4

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Canvas { context, size in
                drawBar(context: context, size: size)
            }
            .frame(height: barHeight)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))

            // Tick marks and labels
            Canvas { context, size in
                drawTicks(context: context, size: size)
            }
            .frame(height: tickHeight + tickLabelGap + 14) // tick + gap + label height
        }
    }

    // MARK: - Bar Drawing

    private func drawBar(context: GraphicsContext, size: CGSize) {
        let total = day.dayEnd.timeIntervalSince(day.dayStart)
        guard total > 0 else { return }

        // Background track
        let rect = CGRect(origin: .zero, size: size)
        context.fill(Path(roundedRect: rect, cornerRadius: cornerRadius), with: .color(Color.btBackgroundSecondary))

        // Color bands
        let clipPath = Path(roundedRect: rect, cornerRadius: cornerRadius)
        for segment in day.segments where segment.kind != .awake {
            let x1 = xPosition(for: segment.start, in: size.width, total: total)
            let x2 = xPosition(for: segment.end, in: size.width, total: total)
            let bandWidth = max(0, x2 - x1)
            guard bandWidth > 0 else { continue }

            let bandRect = CGRect(x: x1, y: 0, width: bandWidth, height: size.height)
            let bandPath = Path(bandRect).intersection(clipPath)
            context.fill(bandPath, with: .color(color(for: segment.kind)))
        }

        // "Now" indicator line (today only)
        if day.isToday {
            let nowX = xPosition(for: Date(), in: size.width, total: total)
            let linePath = Path { path in
                path.move(to: CGPoint(x: nowX, y: 0))
                path.addLine(to: CGPoint(x: nowX, y: size.height))
            }
            context.stroke(linePath, with: .color(Color.btTextSecondary), lineWidth: 1)
        }
    }

    // MARK: - Tick Drawing

    private func drawTicks(context: GraphicsContext, size: CGSize) {
        let total = day.dayEnd.timeIntervalSince(day.dayStart)
        guard total > 0 else { return }

        let calendar = Calendar.current

        // Find the first even hour at or after dayStart
        let startHour = calendar.component(.hour, from: day.dayStart)
        let startMinute = calendar.component(.minute, from: day.dayStart)
        var firstTickHour = startHour
        if startMinute > 0 { firstTickHour += 1 }
        // Round up to next even hour
        if firstTickHour % 2 != 0 { firstTickHour += 1 }

        // Generate tick times every 2 hours
        var tickDate = calendar.date(bySettingHour: firstTickHour, minute: 0, second: 0, of: day.dayStart) ?? day.dayStart
        // If setting the hour rolled to previous day, advance
        if tickDate < day.dayStart {
            tickDate = tickDate.addingTimeInterval(2 * 3600)
        }

        while tickDate < day.dayEnd {
            let x = xPosition(for: tickDate, in: size.width, total: total)

            // Skip ticks too close to edges
            if x > 12 && x < size.width - 12 {
                // Tick mark
                let tickPath = Path { path in
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: tickHeight))
                }
                context.stroke(tickPath, with: .color(Color.btTextMuted), lineWidth: 1)

                // Time label
                let label = tickLabel(for: tickDate)
                let text = context.resolve(
                    Text(label)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color.btTextMuted)
                )
                let textSize = text.measure(in: size)
                context.draw(
                    text,
                    at: CGPoint(x: x, y: tickHeight + tickLabelGap + textSize.height / 2)
                )
            }

            tickDate = tickDate.addingTimeInterval(2 * 3600)
        }

        // "Now" indicator extends through tick area
        if day.isToday {
            let nowX = xPosition(for: Date(), in: size.width, total: total)
            let linePath = Path { path in
                path.move(to: CGPoint(x: nowX, y: 0))
                path.addLine(to: CGPoint(x: nowX, y: tickHeight))
            }
            context.stroke(linePath, with: .color(Color.btTextSecondary), lineWidth: 1)
        }
    }

    // MARK: - Helpers

    private func xPosition(for time: Date, in width: CGFloat, total: TimeInterval) -> CGFloat {
        let elapsed = time.timeIntervalSince(day.dayStart)
        let fraction = max(0, min(1, elapsed / total))
        return fraction * width
    }

    private func color(for kind: SegmentKind) -> Color {
        switch kind {
        case .sleep: return Color.btSleepAccent
        case .feed: return Color.btFeedAccent
        case .awake: return Color.btBackgroundSecondary
        }
    }

    private func tickLabel(for date: Date) -> String {
        let hour = Calendar.current.component(.hour, from: date)
        if hour == 0 { return "12a" }
        if hour < 12 { return "\(hour)a" }
        if hour == 12 { return "12p" }
        return "\(hour - 12)p"
    }
}

// MARK: - Preview

#Preview("Day Rhythm Bar") {
    let day = TimelineDay(
        date: Date(),
        dayStart: Calendar.current.date(bySettingHour: 6, minute: 30, second: 0, of: Date())!,
        dayEnd: Date(),
        isToday: true,
        segments: [
            TimelineSegment(
                start: Calendar.current.date(bySettingHour: 6, minute: 30, second: 0, of: Date())!,
                end: Calendar.current.date(bySettingHour: 6, minute: 45, second: 0, of: Date())!,
                kind: .awake
            ),
            TimelineSegment(
                start: Calendar.current.date(bySettingHour: 6, minute: 45, second: 0, of: Date())!,
                end: Calendar.current.date(bySettingHour: 7, minute: 0, second: 0, of: Date())!,
                kind: .feed
            ),
            TimelineSegment(
                start: Calendar.current.date(bySettingHour: 7, minute: 0, second: 0, of: Date())!,
                end: Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date())!,
                kind: .awake
            ),
            TimelineSegment(
                start: Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date())!,
                end: Calendar.current.date(bySettingHour: 9, minute: 15, second: 0, of: Date())!,
                kind: .sleep
            ),
            TimelineSegment(
                start: Calendar.current.date(bySettingHour: 9, minute: 15, second: 0, of: Date())!,
                end: Calendar.current.date(bySettingHour: 9, minute: 30, second: 0, of: Date())!,
                kind: .awake
            ),
            TimelineSegment(
                start: Calendar.current.date(bySettingHour: 9, minute: 30, second: 0, of: Date())!,
                end: Calendar.current.date(bySettingHour: 9, minute: 42, second: 0, of: Date())!,
                kind: .feed
            ),
            TimelineSegment(
                start: Calendar.current.date(bySettingHour: 9, minute: 42, second: 0, of: Date())!,
                end: Calendar.current.date(bySettingHour: 11, minute: 0, second: 0, of: Date())!,
                kind: .awake
            ),
            TimelineSegment(
                start: Calendar.current.date(bySettingHour: 11, minute: 0, second: 0, of: Date())!,
                end: Calendar.current.date(bySettingHour: 12, minute: 30, second: 0, of: Date())!,
                kind: .sleep
            ),
        ],
        events: []
    )

    DayRhythmBar(day: day)
        .padding(.horizontal, 24)
        .background(Color.btBackground)
}
