//
//  TimelineDay.swift
//  BabyTime
//
//  Value types packaging one day's timeline data for the dual-column view.
//

import Foundation

// MARK: - Log Entry

enum LogEntry: Identifiable {
    case feed(FeedEvent)
    case sleep(SleepEvent)

    var id: UUID {
        switch self {
        case .feed(let e): return e.id
        case .sleep(let e): return e.id
        }
    }

    var startTime: Date {
        switch self {
        case .feed(let e): return e.startTime
        case .sleep(let e): return e.startTime
        }
    }
}

// MARK: - Timeline Day

struct TimelineDay {
    let date: Date
    let dayStart: Date
    let dayEnd: Date
    let isToday: Bool
    let segments: [TimelineSegment]
    let events: [LogEntry]
}

struct TimelineSegment: Identifiable {
    let id = UUID()
    let start: Date
    let end: Date
    let kind: SegmentKind
}

enum SegmentKind {
    case sleep
    case feed
    case awake
}

// MARK: - Factory

extension TimelineDay {
    /// Build a TimelineDay from raw events.
    /// Bottles without duration get a 15-minute band.
    static func build(
        date: Date,
        wakeTime: Date?,
        feeds: [FeedEvent],
        naps: [SleepEvent],
        nightSleep: SleepEvent?,
        bedtime: Date?,
        now: Date
    ) -> TimelineDay {
        let calendar = Calendar.current
        let isToday = calendar.isDateInToday(date)

        // Determine day bounds
        let allEvents: [Date] = feeds.map(\.startTime) + naps.map(\.startTime)
        let firstEventTime = allEvents.min()

        let dayStart: Date
        if let wake = wakeTime {
            dayStart = wake
        } else if let first = firstEventTime {
            dayStart = first
        } else {
            dayStart = calendar.startOfDay(for: date)
        }

        let dayEnd: Date
        if let ns = nightSleep {
            dayEnd = ns.startTime
        } else if let bt = bedtime {
            dayEnd = isToday ? max(bt, now) : bt
        } else if isToday {
            dayEnd = now
        } else {
            // Fallback: end of last event or end of day
            let lastFeedEnd = feeds.compactMap { feedEndTime($0) }.max()
            let lastNapEnd = naps.compactMap(\.endTime).max()
            dayEnd = [lastFeedEnd, lastNapEnd].compactMap { $0 }.max() ?? calendar.startOfDay(for: date).addingTimeInterval(12 * 3600)
        }

        // Build event intervals
        var intervals: [(start: Date, end: Date, kind: SegmentKind)] = []

        for nap in naps {
            let napEnd = nap.endTime ?? (isToday ? now : nap.startTime)
            intervals.append((
                start: max(nap.startTime, dayStart),
                end: min(napEnd, dayEnd),
                kind: .sleep
            ))
        }

        for feed in feeds {
            let end = feedEndTime(feed) ?? feed.startTime.addingTimeInterval(15 * 60)
            intervals.append((
                start: max(feed.startTime, dayStart),
                end: min(end, dayEnd),
                kind: .feed
            ))
        }

        // Sort by start time
        intervals.sort { $0.start < $1.start }

        // Fill gaps with .awake segments
        var segments: [TimelineSegment] = []
        var cursor = dayStart

        for interval in intervals {
            if interval.start > cursor {
                segments.append(TimelineSegment(start: cursor, end: interval.start, kind: .awake))
            }
            segments.append(TimelineSegment(start: interval.start, end: interval.end, kind: interval.kind))
            cursor = max(cursor, interval.end)
        }

        // Trailing gap
        if cursor < dayEnd {
            segments.append(TimelineSegment(start: cursor, end: dayEnd, kind: .awake))
        }

        // Build log entries (chronological)
        var entries: [LogEntry] = []
        entries += feeds.map { .feed($0) }
        entries += naps.filter { $0.endTime != nil || isToday }.map { .sleep($0) }
        entries.sort { $0.startTime < $1.startTime }

        return TimelineDay(
            date: date,
            dayStart: dayStart,
            dayEnd: dayEnd,
            isToday: isToday,
            segments: segments,
            events: entries
        )
    }

    /// Compute the visual end time for a feed event.
    /// Bottles have endTime == startTime (no duration), so use startTime + 15min.
    private static func feedEndTime(_ event: FeedEvent) -> Date? {
        if event.kind == .bottle {
            return event.startTime.addingTimeInterval(15 * 60)
        }
        return event.endTime
    }
}
