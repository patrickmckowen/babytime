//
//  DayState.swift
//  BabyTime
//
//  Day state and feed state enums derived from docs/DAY_MODEL.md.
//  These are pure value types with no side effects.
//

import Foundation

/// The baby's current day state — one of 8 states from DAY_MODEL.md + not-started.
enum DayState: Equatable, Sendable {
    /// No events logged today
    case notStarted

    /// State 1: Just woke up, early in wake window. Calm, informational.
    case awakeEarly(wakeMinutes: Int, windowRange: ClosedRange<Int>)

    /// State 2: Approaching the wake window range. Nap is an option soon.
    case awakeApproaching(wakeMinutes: Int, windowRange: ClosedRange<Int>)

    /// State 3: Past the wake window. May be getting overtired.
    case awakeBeyond(wakeMinutes: Int, windowRange: ClosedRange<Int>)

    /// State 4: Napping, no time pressure. All is well.
    case sleepingNoPressure(sleepMinutes: Int, minutesUntilCutoff: Int)

    /// State 5: Napping, but needs to wake soon to protect bedtime.
    case sleepingApproachingCutoff(sleepMinutes: Int, minutesUntilCutoff: Int)

    /// State 6: Nap must end now or bedtime is at risk.
    case sleepingMustEnd(sleepMinutes: Int, minutesPastCutoff: Int)

    /// State 7: No more naps today. Bridge to bedtime.
    case napWindowClosed(wakeMinutes: Int, minutesToBedtime: Int)

    /// State 8: Bedtime window. Almost there.
    case bedtimeWindow(minutesToBedtime: Int)
}

/// Feed state runs as a parallel, independent track.
enum FeedState: Equatable, Sendable {
    /// No feeds logged today
    case noFeedsYet

    /// Recently fed, well within the interval
    case recentlyFed(minutesAgo: Int)

    /// Approaching the feed interval range
    case approaching(minutesAgo: Int, intervalRange: ClosedRange<Int>)

    /// Within or past the feed interval — ready for next feed
    case ready(minutesAgo: Int, intervalRange: ClosedRange<Int>)

    /// Currently feeding (active feed with no endTime)
    case feedingNow(startedMinutesAgo: Int)
}

/// Combined snapshot output from the DayEngine.
struct DaySnapshot: Equatable, Sendable {
    let dayState: DayState
    let feedState: FeedState
    let completedNaps: Int
    let totalFeedCount: Int
    let napCutoff: Date
    let bedtime: Date
    let ageTable: AgeTable
    let wakeTime: Date?
}
