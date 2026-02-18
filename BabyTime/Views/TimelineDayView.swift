//
//  TimelineDayView.swift
//  BabyTime
//
//  Single-day dual-column layout: timeline strip (left) + event rows (right).
//  Rows are positioned proportionally to their time on the timeline.
//  The strip fills the full visible height.
//

import SwiftUI
import SwiftData

struct TimelineDayView: View {
    let day: TimelineDay
    let babyName: String
    let onTapEvent: (LogEntry) -> Void
    let onDeleteEvent: (LogEntry) -> Void

    private let minRowHeight: CGFloat = 52
    private let pointsPerHour: CGFloat = 60
    private let stripLeading: CGFloat = 16
    private let stripToContent: CGFloat = 12

    var body: some View {
        if day.events.isEmpty {
            emptyState
        } else {
            GeometryReader { geo in
                scrollableTimeline(screenHeight: geo.size.height)
            }
        }
    }

    // MARK: - Timeline

    private func scrollableTimeline(screenHeight: CGFloat) -> some View {
        let height = contentHeight(screenHeight: screenHeight)

        return ScrollView {
            HStack(alignment: .top, spacing: stripToContent) {
                // Left: timeline strip
                TimelineStripView(day: day, totalHeight: height)
                    .padding(.leading, stripLeading)

                // Right: positioned event rows
                ZStack(alignment: .topLeading) {
                    ForEach(positionedEvents(height: height)) { item in
                        TimelineEventRow(entry: item.entry, babyName: babyName)
                            .offset(y: item.yOffset)
                            .onTapGesture { onTapEvent(item.entry) }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .frame(height: height)
            .padding(.top, 8)
            .padding(.bottom, 40)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Text("No activities yet")
                .font(BTTypography.label)
                .foregroundStyle(Color.btTextSecondary)
            Text("Feed and sleep events will appear here")
                .font(BTTypography.caption)
                .foregroundStyle(Color.btTextMuted)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Layout Calculations

    private func contentHeight(screenHeight: CGFloat) -> CGFloat {
        let seconds = day.dayEnd.timeIntervalSince(day.dayStart)
        let dayDurationHours = max(1, CGFloat(seconds) / 3600)
        let proportionalHeight = dayDurationHours * pointsPerHour
        let minForRows = CGFloat(day.events.count) * minRowHeight
        // Fill at least the visible screen (minus nav bar + padding)
        let visibleHeight = screenHeight - 48
        return max(proportionalHeight, minForRows, visibleHeight)
    }

    private func positionedEvents(height: CGFloat) -> [PositionedEvent] {
        var items: [PositionedEvent] = []
        let total = day.dayEnd.timeIntervalSince(day.dayStart)
        guard total > 0 else { return [] }

        for entry in day.events {
            let elapsed = entry.startTime.timeIntervalSince(day.dayStart)
            let fraction = max(0, min(1, elapsed / total))
            let idealY = fraction * height
            items.append(PositionedEvent(entry: entry, yOffset: idealY))
        }

        // Enforce minimum spacing: walk top-to-bottom, push down if overlapping
        for i in 1..<items.count {
            let previousBottom = items[i - 1].yOffset + minRowHeight
            if items[i].yOffset < previousBottom {
                items[i].yOffset = previousBottom
            }
        }

        return items
    }
}

// MARK: - Positioned Event

private struct PositionedEvent: Identifiable {
    let entry: LogEntry
    var yOffset: CGFloat

    var id: PersistentIdentifier { entry.id }
}

// MARK: - Preview

#Preview("Timeline Day") {
    let container = try! ModelContainer(
        for: Baby.self, FeedEvent.self, SleepEvent.self, WakeEvent.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let ctx = container.mainContext
    let cal = Calendar.current
    let today = Date()

    let baby = Baby(
        name: "Kaia",
        birthdate: cal.date(byAdding: .day, value: -100, to: today)!
    )
    ctx.insert(baby)

    // Build events directly — faster than going through ActivityManager
    let wakeTime = cal.date(bySettingHour: 6, minute: 30, second: 0, of: today)!

    let feeds: [FeedEvent] = [
        FeedEvent(startTime: cal.date(bySettingHour: 6, minute: 45, second: 0, of: today)!,
                  endTime: cal.date(bySettingHour: 6, minute: 45, second: 0, of: today)!,
                  kind: .bottle, amountOz: 4, baby: baby),
        FeedEvent(startTime: cal.date(bySettingHour: 9, minute: 30, second: 0, of: today)!,
                  endTime: cal.date(bySettingHour: 9, minute: 42, second: 0, of: today)!,
                  kind: .nursing, side: .left, baby: baby),
        FeedEvent(startTime: cal.date(bySettingHour: 13, minute: 0, second: 0, of: today)!,
                  endTime: cal.date(bySettingHour: 13, minute: 0, second: 0, of: today)!,
                  kind: .bottle, amountOz: 5, baby: baby),
        FeedEvent(startTime: cal.date(bySettingHour: 15, minute: 30, second: 0, of: today)!,
                  endTime: cal.date(bySettingHour: 15, minute: 30, second: 0, of: today)!,
                  kind: .bottle, amountOz: 4, baby: baby),
    ]

    let naps: [SleepEvent] = [
        SleepEvent(startTime: cal.date(bySettingHour: 8, minute: 0, second: 0, of: today)!,
                   endTime: cal.date(bySettingHour: 9, minute: 15, second: 0, of: today)!,
                   baby: baby),
        SleepEvent(startTime: cal.date(bySettingHour: 11, minute: 0, second: 0, of: today)!,
                   endTime: cal.date(bySettingHour: 12, minute: 30, second: 0, of: today)!,
                   baby: baby),
        SleepEvent(startTime: cal.date(bySettingHour: 14, minute: 30, second: 0, of: today)!,
                   endTime: cal.date(bySettingHour: 15, minute: 15, second: 0, of: today)!,
                   baby: baby),
    ]

    for f in feeds { ctx.insert(f) }
    for n in naps { ctx.insert(n) }

    let day = TimelineDay.build(
        date: today,
        wakeTime: wakeTime,
        feeds: feeds,
        naps: naps,
        nightSleep: nil,
        bedtime: cal.date(bySettingHour: 19, minute: 0, second: 0, of: today)!,
        now: today
    )

    return NavigationStack {
        TimelineDayView(
            day: day,
            babyName: "Kaia",
            onTapEvent: { _ in },
            onDeleteEvent: { _ in }
        )
        .background(Color.btBackground)
        .navigationTitle("Today")
        .navigationBarTitleDisplayMode(.inline)
    }
}
