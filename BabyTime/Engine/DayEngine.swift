//
//  DayEngine.swift
//  BabyTime
//
//  Pure state derivation engine. No side effects, no persistence, no UI.
//  Takes baby + events + current time → produces DaySnapshot.
//

import Foundation

enum DayEngine {

    /// Pure function: derive current day state from inputs.
    ///
    /// This is the core of the app's intelligence. It answers:
    /// "Given this baby's age, today's events, and the current time, what state are we in?"
    static func snapshot(
        baby: Baby,
        feeds: [FeedEvent],
        sleeps: [SleepEvent],
        wakeTime: Date? = nil,
        now: Date
    ) -> DaySnapshot {
        let ageInDays = baby.ageInDays(at: now)
        let ageTable = AgeTable.forAge(days: ageInDays)
        let bedtime = baby.bedtimeToday(referenceDate: now)
        let napCutoff = napCutoffTime(bedtime: bedtime, lastWakeWindow: ageTable.lastWakeWindow)

        let completedSleeps = sleeps.filter { $0.endTime != nil }
        let activeSleep = sleeps.first { $0.endTime == nil }
        let completedFeeds = feeds.filter { $0.endTime != nil || $0.kind == .bottle }
        let activeFeed = feeds.first { $0.endTime == nil && $0.kind == .nursing }

        let napCount = completedSleeps.count
        let feedCount = completedFeeds.count + (activeFeed != nil ? 1 : 0)
        let currentWW = ageTable.currentWakeWindow(completedNaps: napCount)

        let dayState = deriveDayState(
            activeSleep: activeSleep,
            lastSleepEnd: latestSleepEnd(completedSleeps),
            wakeTime: wakeTime,
            firstEventTime: earliestEventTime(feeds: feeds, sleeps: sleeps),
            now: now,
            currentWW: currentWW,
            napCutoff: napCutoff,
            bedtime: bedtime
        )

        let feedState = deriveFeedState(
            activeFeed: activeFeed,
            lastCompletedFeed: latestCompletedFeed(feeds),
            now: now,
            feedInterval: ageTable.feedIntervalMinutes
        )

        return DaySnapshot(
            dayState: dayState,
            feedState: feedState,
            completedNaps: napCount,
            totalFeedCount: feedCount,
            napCutoff: napCutoff,
            bedtime: bedtime,
            ageTable: ageTable,
            wakeTime: wakeTime
        )
    }

    // MARK: - Nap Cutoff

    /// nap_cutoff = bedtime − last_wake_window.upperBound
    static func napCutoffTime(bedtime: Date, lastWakeWindow: ClosedRange<Int>) -> Date {
        bedtime.addingTimeInterval(-Double(lastWakeWindow.upperBound) * 60)
    }

    // MARK: - Day State Derivation

    private static func deriveDayState(
        activeSleep: SleepEvent?,
        lastSleepEnd: Date?,
        wakeTime: Date?,
        firstEventTime: Date?,
        now: Date,
        currentWW: ClosedRange<Int>,
        napCutoff: Date,
        bedtime: Date
    ) -> DayState {
        // No events and no wake time → not started
        guard let wakeReference = lastSleepEnd ?? wakeTime ?? firstEventTime else {
            return .notStarted
        }

        let minutesToBedtime = Int(bedtime.timeIntervalSince(now) / 60)

        // Currently sleeping?
        if let sleep = activeSleep {
            let sleepMinutes = Int(now.timeIntervalSince(sleep.startTime) / 60)
            let minutesUntilCutoff = Int(napCutoff.timeIntervalSince(now) / 60)

            if minutesUntilCutoff <= 0 {
                return .sleepingMustEnd(
                    sleepMinutes: sleepMinutes,
                    minutesPastCutoff: abs(minutesUntilCutoff)
                )
            } else if minutesUntilCutoff <= 30 {
                return .sleepingApproachingCutoff(
                    sleepMinutes: sleepMinutes,
                    minutesUntilCutoff: minutesUntilCutoff
                )
            } else {
                return .sleepingNoPressure(
                    sleepMinutes: sleepMinutes,
                    minutesUntilCutoff: minutesUntilCutoff
                )
            }
        }

        // Awake — calculate wake duration
        let wakeMinutes = Int(now.timeIntervalSince(wakeReference) / 60)

        // Bedtime window (within 30 minutes of bedtime)
        if minutesToBedtime <= 30 && minutesToBedtime > 0 {
            return .bedtimeWindow(minutesToBedtime: minutesToBedtime)
        }

        // Past bedtime
        if minutesToBedtime <= 0 {
            return .bedtimeWindow(minutesToBedtime: 0)
        }

        // Nap window closed (past cutoff, but not yet bedtime window)
        if now >= napCutoff {
            return .napWindowClosed(
                wakeMinutes: wakeMinutes,
                minutesToBedtime: minutesToBedtime
            )
        }

        // Wake window assessment
        if wakeMinutes < currentWW.lowerBound {
            return .awakeEarly(
                wakeMinutes: wakeMinutes,
                windowRange: currentWW
            )
        } else if wakeMinutes <= currentWW.upperBound {
            return .awakeApproaching(
                wakeMinutes: wakeMinutes,
                windowRange: currentWW
            )
        } else {
            return .awakeBeyond(
                wakeMinutes: wakeMinutes,
                windowRange: currentWW
            )
        }
    }

    // MARK: - Feed State Derivation

    private static func deriveFeedState(
        activeFeed: FeedEvent?,
        lastCompletedFeed: FeedEvent?,
        now: Date,
        feedInterval: ClosedRange<Int>
    ) -> FeedState {
        // Currently feeding?
        if let active = activeFeed {
            let minutes = Int(now.timeIntervalSince(active.startTime) / 60)
            return .feedingNow(startedMinutesAgo: minutes)
        }

        // No feeds at all
        guard let lastFeed = lastCompletedFeed else {
            return .noFeedsYet
        }

        let minutesAgo = Int(now.timeIntervalSince(lastFeed.startTime) / 60)

        // Approaching threshold: 80% of the lower bound
        let approachingThreshold = Int(Double(feedInterval.lowerBound) * 0.8)

        if minutesAgo >= feedInterval.lowerBound {
            return .ready(minutesAgo: minutesAgo, intervalRange: feedInterval)
        } else if minutesAgo >= approachingThreshold {
            return .approaching(minutesAgo: minutesAgo, intervalRange: feedInterval)
        } else {
            return .recentlyFed(minutesAgo: minutesAgo)
        }
    }

    // MARK: - Helpers

    private static func latestSleepEnd(_ sleeps: [SleepEvent]) -> Date? {
        sleeps.compactMap(\.endTime).max()
    }

    private static func latestCompletedFeed(_ feeds: [FeedEvent]) -> FeedEvent? {
        feeds
            .filter { $0.endTime != nil || $0.kind == .bottle }
            .max { $0.startTime < $1.startTime }
    }

    private static func earliestEventTime(feeds: [FeedEvent], sleeps: [SleepEvent]) -> Date? {
        let feedTimes = feeds.map(\.startTime)
        let sleepTimes = sleeps.map(\.startTime)
        return (feedTimes + sleepTimes).min()
    }
}
