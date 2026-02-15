//
//  DayEngineTests.swift
//  BabyTimeTests
//
//  Parameterized tests for DayEngine state derivation.
//

import Testing
import Foundation
@testable import BabyTime

// MARK: - Test Helpers

/// Creates a Baby with specific age for testing
private func makeBaby(
    ageDays: Int,
    bedtimeHour: Int = 19,
    bedtimeMinute: Int = 0,
    referenceDate: Date = Date()
) -> Baby {
    let birthdate = Calendar.current.date(
        byAdding: .day, value: -ageDays, to: referenceDate
    )!
    return Baby(
        name: "Test",
        birthdate: birthdate,
        bedtimeHour: bedtimeHour,
        bedtimeMinute: bedtimeMinute
    )
}

/// Creates a completed feed event
private func makeFeed(
    minutesAgo: Int,
    kind: FeedKind = .bottle,
    amountOz: Double = 4,
    referenceDate: Date = Date()
) -> FeedEvent {
    let start = referenceDate.addingTimeInterval(-Double(minutesAgo) * 60)
    return FeedEvent(
        startTime: start,
        endTime: start.addingTimeInterval(10 * 60),
        kind: kind,
        amountOz: amountOz
    )
}

/// Creates a completed sleep event
private func makeSleep(
    startedMinutesAgo: Int,
    durationMinutes: Int,
    referenceDate: Date = Date()
) -> SleepEvent {
    let start = referenceDate.addingTimeInterval(-Double(startedMinutesAgo) * 60)
    let end = start.addingTimeInterval(Double(durationMinutes) * 60)
    return SleepEvent(startTime: start, endTime: end)
}

/// Creates an active (in-progress) sleep event
private func makeActiveSleep(
    startedMinutesAgo: Int,
    referenceDate: Date = Date()
) -> SleepEvent {
    let start = referenceDate.addingTimeInterval(-Double(startedMinutesAgo) * 60)
    return SleepEvent(startTime: start, endTime: nil)
}

// MARK: - Day State Tests

@Suite("DayEngine — Day State Derivation")
struct DayStateTests {

    // Use a fixed reference time for deterministic tests
    let now = Calendar.current.date(
        from: DateComponents(year: 2026, month: 2, day: 11, hour: 14, minute: 0)
    )!

    @Test("No events → notStarted")
    func notStarted() {
        let baby = makeBaby(ageDays: 100, referenceDate: now)
        let snapshot = DayEngine.snapshot(baby: baby, feeds: [], sleeps: [], now: now)
        #expect(snapshot.dayState == .notStarted)
    }

    @Test("Awake early in wake window (3-4 month old, 30 min awake)")
    func awakeEarly() {
        let baby = makeBaby(ageDays: 90, referenceDate: now) // 3 months
        let feed = makeFeed(minutesAgo: 30, referenceDate: now)
        let sleep = makeSleep(startedMinutesAgo: 60, durationMinutes: 30, referenceDate: now)

        let snapshot = DayEngine.snapshot(
            baby: baby, feeds: [feed], sleeps: [sleep], now: now
        )

        // 30 min awake, WW1 for 3-4mo = 75...90 → should be awakeEarly
        if case .awakeEarly(let mins, _) = snapshot.dayState {
            #expect(mins == 30)
        } else {
            Issue.record("Expected awakeEarly, got \(snapshot.dayState)")
        }
    }

    @Test("Awake approaching wake window (3-4 month old, 1 nap done, 95 min awake)")
    func awakeApproaching() {
        let baby = makeBaby(ageDays: 90, referenceDate: now)
        let feed = makeFeed(minutesAgo: 120, referenceDate: now)
        // 1 completed nap → engine uses WW2 (90...105)
        let sleep = makeSleep(startedMinutesAgo: 125, durationMinutes: 30, referenceDate: now)
        // Awake since sleep ended 95 min ago

        let snapshot = DayEngine.snapshot(
            baby: baby, feeds: [feed], sleeps: [sleep], now: now
        )

        // 95 min awake, WW2 = 90...105 → approaching
        if case .awakeApproaching(let mins, let range) = snapshot.dayState {
            #expect(mins == 95)
            #expect(range == 90...105)
        } else {
            Issue.record("Expected awakeApproaching, got \(snapshot.dayState)")
        }
    }

    @Test("Awake beyond wake window (3-4 month old, 1 nap done, 110 min awake)")
    func awakeBeyond() {
        let baby = makeBaby(ageDays: 90, referenceDate: now)
        let feed = makeFeed(minutesAgo: 150, referenceDate: now)
        // 1 completed nap → engine uses WW2 (90...105)
        let sleep = makeSleep(startedMinutesAgo: 140, durationMinutes: 30, referenceDate: now)
        // Awake since sleep ended 110 min ago

        let snapshot = DayEngine.snapshot(
            baby: baby, feeds: [feed], sleeps: [sleep], now: now
        )

        // 110 min awake, WW2 = 90...105 → beyond
        if case .awakeBeyond(let mins, let range) = snapshot.dayState {
            #expect(mins == 110)
            #expect(range == 90...105)
        } else {
            Issue.record("Expected awakeBeyond, got \(snapshot.dayState)")
        }
    }

    @Test("Sleeping — no pressure")
    func sleepingNoPressure() {
        // Baby napping at 2 PM, bedtime 7 PM, cutoff ~5 PM for 3-4mo
        let baby = makeBaby(ageDays: 90, bedtimeHour: 19, referenceDate: now)
        let feed = makeFeed(minutesAgo: 60, referenceDate: now)
        let activeSleep = makeActiveSleep(startedMinutesAgo: 20, referenceDate: now)

        let snapshot = DayEngine.snapshot(
            baby: baby, feeds: [feed], sleeps: [activeSleep], now: now
        )

        if case .sleepingNoPressure(let mins, _) = snapshot.dayState {
            #expect(mins == 20)
        } else {
            Issue.record("Expected sleepingNoPressure, got \(snapshot.dayState)")
        }
    }

    @Test("Sleeping — must end (past cutoff)")
    func sleepingMustEnd() {
        // Set "now" to 6:30 PM, bedtime 7 PM, last WW for 3-4mo = 105...120 min
        // Cutoff = 7 PM - 120 min = 5 PM. At 6:30 PM we're well past cutoff.
        let lateNow = Calendar.current.date(
            from: DateComponents(year: 2026, month: 2, day: 11, hour: 18, minute: 30)
        )!
        let baby = makeBaby(ageDays: 90, bedtimeHour: 19, referenceDate: lateNow)
        let feed = makeFeed(minutesAgo: 120, referenceDate: lateNow)
        let activeSleep = makeActiveSleep(startedMinutesAgo: 30, referenceDate: lateNow)

        let snapshot = DayEngine.snapshot(
            baby: baby, feeds: [feed], sleeps: [activeSleep], now: lateNow
        )

        if case .sleepingMustEnd = snapshot.dayState {
            // Pass
        } else {
            Issue.record("Expected sleepingMustEnd, got \(snapshot.dayState)")
        }
    }

    @Test("Nap window closed")
    func napWindowClosed() {
        // 5:30 PM, bedtime 7 PM, cutoff ~5 PM for 3-4mo → past cutoff, awake
        let lateNow = Calendar.current.date(
            from: DateComponents(year: 2026, month: 2, day: 11, hour: 17, minute: 30)
        )!
        let baby = makeBaby(ageDays: 90, bedtimeHour: 19, referenceDate: lateNow)
        let feed = makeFeed(minutesAgo: 60, referenceDate: lateNow)
        let sleep = makeSleep(startedMinutesAgo: 120, durationMinutes: 30, referenceDate: lateNow)

        let snapshot = DayEngine.snapshot(
            baby: baby, feeds: [feed], sleeps: [sleep], now: lateNow
        )

        if case .napWindowClosed(_, let minsToBed) = snapshot.dayState {
            #expect(minsToBed == 90)
        } else {
            Issue.record("Expected napWindowClosed, got \(snapshot.dayState)")
        }
    }

    @Test("Bedtime window (within 30 min of bedtime)")
    func bedtimeWindow() {
        let almostBedtime = Calendar.current.date(
            from: DateComponents(year: 2026, month: 2, day: 11, hour: 18, minute: 45)
        )!
        let baby = makeBaby(ageDays: 90, bedtimeHour: 19, referenceDate: almostBedtime)
        let feed = makeFeed(minutesAgo: 30, referenceDate: almostBedtime)
        let sleep = makeSleep(startedMinutesAgo: 120, durationMinutes: 30, referenceDate: almostBedtime)

        let snapshot = DayEngine.snapshot(
            baby: baby, feeds: [feed], sleeps: [sleep], now: almostBedtime
        )

        if case .bedtimeWindow(let mins) = snapshot.dayState {
            #expect(mins == 15)
        } else {
            Issue.record("Expected bedtimeWindow, got \(snapshot.dayState)")
        }
    }

    @Test("Wake time as sole wake reference (no events)")
    func wakeTimeOnly() {
        let baby = makeBaby(ageDays: 100, referenceDate: now)
        // Wake time set 60 min ago, no feeds or sleeps
        let wakeTime = now.addingTimeInterval(-60 * 60)

        let snapshot = DayEngine.snapshot(
            baby: baby, feeds: [], sleeps: [], wakeTime: wakeTime, now: now
        )

        // Should use wakeTime as reference → awakeEarly (60 min, WW1 for 3-4mo = 75...90)
        if case .awakeEarly(let mins, _) = snapshot.dayState {
            #expect(mins == 60)
        } else {
            Issue.record("Expected awakeEarly, got \(snapshot.dayState)")
        }
        #expect(snapshot.wakeTime == wakeTime)
    }

    @Test("Wake time ignored when lastSleepEnd exists")
    func wakeTimeOverriddenBySleepEnd() {
        let baby = makeBaby(ageDays: 90, referenceDate: now)
        // Wake time at 7 AM (7 hours ago)
        let wakeTime = now.addingTimeInterval(-7 * 60 * 60)
        // Sleep ended 30 min ago — should take priority
        let sleep = makeSleep(startedMinutesAgo: 60, durationMinutes: 30, referenceDate: now)
        let feed = makeFeed(minutesAgo: 30, referenceDate: now)

        let snapshot = DayEngine.snapshot(
            baby: baby, feeds: [feed], sleeps: [sleep], wakeTime: wakeTime, now: now
        )

        // lastSleepEnd (30 min ago) takes priority over wakeTime (7h ago)
        if case .awakeEarly(let mins, _) = snapshot.dayState {
            #expect(mins == 30)
        } else {
            Issue.record("Expected awakeEarly with 30 min, got \(snapshot.dayState)")
        }
    }

    @Test("Wake time used when no sleeps but feeds exist")
    func wakeTimeWithFeedsNoSleeps() {
        let baby = makeBaby(ageDays: 90, referenceDate: now)
        // Wake time 80 min ago, feed 30 min ago
        let wakeTime = now.addingTimeInterval(-80 * 60)
        let feed = makeFeed(minutesAgo: 30, referenceDate: now)

        let snapshot = DayEngine.snapshot(
            baby: baby, feeds: [feed], sleeps: [], wakeTime: wakeTime, now: now
        )

        // wakeTime (80 min) should be used over firstEvent (30 min)
        // 80 min, WW1 for 3-4mo = 75...90 → approaching
        if case .awakeApproaching(let mins, _) = snapshot.dayState {
            #expect(mins == 80)
        } else {
            Issue.record("Expected awakeApproaching with 80 min, got \(snapshot.dayState)")
        }
    }

    @Test("No wake time, no events → notStarted")
    func noWakeTimeNoEvents() {
        let baby = makeBaby(ageDays: 100, referenceDate: now)
        let snapshot = DayEngine.snapshot(
            baby: baby, feeds: [], sleeps: [], wakeTime: nil, now: now
        )
        #expect(snapshot.dayState == .notStarted)
        #expect(snapshot.wakeTime == nil)
    }

    @Test("Progressive wake windows — WW2 after one nap")
    func progressiveWakeWindowAfterNap() {
        let baby = makeBaby(ageDays: 90, referenceDate: now) // 3-4 months
        let feed1 = makeFeed(minutesAgo: 180, referenceDate: now)
        let feed2 = makeFeed(minutesAgo: 60, referenceDate: now)
        // One completed nap
        let nap1 = makeSleep(startedMinutesAgo: 150, durationMinutes: 40, referenceDate: now)
        // Second nap ended 30 min ago → now on WW2
        let nap2 = makeSleep(startedMinutesAgo: 60, durationMinutes: 30, referenceDate: now)

        let snapshot = DayEngine.snapshot(
            baby: baby, feeds: [feed1, feed2], sleeps: [nap1, nap2], now: now
        )

        // WW2 for 3-4mo should be wider: 90...105
        // 30 min awake after 2 naps → should be awakeEarly
        if case .awakeEarly(let mins, let range) = snapshot.dayState {
            #expect(mins == 30)
            #expect(range == 90...105) // WW3 (index 2 after 2 completed naps)
        } else {
            Issue.record("Expected awakeEarly with WW3 range, got \(snapshot.dayState)")
        }
    }
}

// MARK: - Feed State Tests

@Suite("DayEngine — Feed State Derivation")
struct FeedStateTests {

    let now = Calendar.current.date(
        from: DateComponents(year: 2026, month: 2, day: 11, hour: 14, minute: 0)
    )!

    @Test("No feeds → noFeedsYet")
    func noFeeds() {
        let baby = makeBaby(ageDays: 90, referenceDate: now)
        let snapshot = DayEngine.snapshot(baby: baby, feeds: [], sleeps: [], now: now)
        // notStarted because no events at all, but feed state should be noFeedsYet
        #expect(snapshot.feedState == .noFeedsYet)
    }

    @Test("Recently fed (30 min ago, interval 150-210)")
    func recentlyFed() {
        let baby = makeBaby(ageDays: 90, referenceDate: now)
        let feed = makeFeed(minutesAgo: 30, referenceDate: now)

        let snapshot = DayEngine.snapshot(
            baby: baby, feeds: [feed], sleeps: [], now: now
        )

        if case .recentlyFed(let mins) = snapshot.feedState {
            #expect(mins == 30)
        } else {
            Issue.record("Expected recentlyFed, got \(snapshot.feedState)")
        }
    }

    @Test("Approaching feed interval")
    func approachingFeed() {
        let baby = makeBaby(ageDays: 90, referenceDate: now)
        // 80% of 150 = 120, so 125 min should be approaching
        let feed = makeFeed(minutesAgo: 125, referenceDate: now)

        let snapshot = DayEngine.snapshot(
            baby: baby, feeds: [feed], sleeps: [], now: now
        )

        if case .approaching(let mins, _) = snapshot.feedState {
            #expect(mins == 125)
        } else {
            Issue.record("Expected approaching, got \(snapshot.feedState)")
        }
    }

    @Test("Ready for feed (past interval lower bound)")
    func readyForFeed() {
        let baby = makeBaby(ageDays: 90, referenceDate: now)
        let feed = makeFeed(minutesAgo: 160, referenceDate: now)

        let snapshot = DayEngine.snapshot(
            baby: baby, feeds: [feed], sleeps: [], now: now
        )

        if case .ready(let mins, _) = snapshot.feedState {
            #expect(mins == 160)
        } else {
            Issue.record("Expected ready, got \(snapshot.feedState)")
        }
    }

    @Test("Feed state is independent of sleep state")
    func feedIndependentOfSleep() {
        let baby = makeBaby(ageDays: 90, referenceDate: now)
        let feed = makeFeed(minutesAgo: 160, referenceDate: now)
        let activeSleep = makeActiveSleep(startedMinutesAgo: 20, referenceDate: now)

        let snapshot = DayEngine.snapshot(
            baby: baby, feeds: [feed], sleeps: [activeSleep], now: now
        )

        // Baby is sleeping, but feed state should still show ready
        if case .sleepingNoPressure = snapshot.dayState {
            // good
        } else {
            Issue.record("Expected sleeping state, got \(snapshot.dayState)")
        }

        if case .ready = snapshot.feedState {
            // good — feed state independent of sleep
        } else {
            Issue.record("Expected feed ready, got \(snapshot.feedState)")
        }
    }
}

// MARK: - Custom Feed Interval Tests

@Suite("DayEngine — Custom Feed Interval")
struct CustomFeedIntervalTests {

    let now = Calendar.current.date(
        from: DateComponents(year: 2026, month: 2, day: 11, hour: 14, minute: 0)
    )!

    @Test("Default interval used when customFeedIntervalMinutes is 0")
    func defaultInterval() {
        let baby = makeBaby(ageDays: 90, referenceDate: now) // 3-4mo: 150...210
        let feed = makeFeed(minutesAgo: 125, referenceDate: now)

        let snapshot = DayEngine.snapshot(
            baby: baby, feeds: [feed], sleeps: [], now: now
        )

        // 125 min, 80% of 150 = 120 → approaching (uses default 150...210)
        if case .approaching(let mins, let range) = snapshot.feedState {
            #expect(mins == 125)
            #expect(range == 150...210)
        } else {
            Issue.record("Expected approaching, got \(snapshot.feedState)")
        }
    }

    @Test("Custom 120-min interval overrides AgeTable default")
    func customIntervalOverride() {
        let baby = makeBaby(ageDays: 90, referenceDate: now)
        baby.customFeedIntervalMinutes = 120 // 2 hours

        // 100 min ago: 80% of 120 = 96 → approaching with custom range
        let feed = makeFeed(minutesAgo: 100, referenceDate: now)

        let snapshot = DayEngine.snapshot(
            baby: baby, feeds: [feed], sleeps: [], now: now
        )

        if case .approaching(let mins, let range) = snapshot.feedState {
            #expect(mins == 100)
            #expect(range == 120...120)
        } else {
            Issue.record("Expected approaching with custom interval, got \(snapshot.feedState)")
        }
    }

    @Test("Custom interval: ready when past custom threshold")
    func customIntervalReady() {
        let baby = makeBaby(ageDays: 90, referenceDate: now)
        baby.customFeedIntervalMinutes = 120

        // 130 min ago: past 120 → ready
        let feed = makeFeed(minutesAgo: 130, referenceDate: now)

        let snapshot = DayEngine.snapshot(
            baby: baby, feeds: [feed], sleeps: [], now: now
        )

        if case .ready(let mins, let range) = snapshot.feedState {
            #expect(mins == 130)
            #expect(range == 120...120)
        } else {
            Issue.record("Expected ready with custom interval, got \(snapshot.feedState)")
        }
    }

    @Test("Custom interval: recentlyFed when well within interval")
    func customIntervalRecentlyFed() {
        let baby = makeBaby(ageDays: 90, referenceDate: now)
        baby.customFeedIntervalMinutes = 120

        // 60 min ago: well under 80% of 120 (96) → recentlyFed
        let feed = makeFeed(minutesAgo: 60, referenceDate: now)

        let snapshot = DayEngine.snapshot(
            baby: baby, feeds: [feed], sleeps: [], now: now
        )

        if case .recentlyFed(let mins) = snapshot.feedState {
            #expect(mins == 60)
        } else {
            Issue.record("Expected recentlyFed, got \(snapshot.feedState)")
        }
    }
}

// MARK: - Nap Cutoff Tests

@Suite("DayEngine — Nap Cutoff")
struct NapCutoffTests {

    @Test("Nap cutoff = bedtime - last wake window upper bound",
          arguments: [
            (19, 105, 120), // 3-4mo: bedtime 7PM, lastWW 105...120 → cutoff 5PM
            (19, 150, 180), // 5-7mo: bedtime 7PM, lastWW 150...180 → cutoff 4PM
            (20, 180, 240), // 8-10mo: bedtime 8PM, lastWW 180...240 → cutoff 4PM
          ])
    func napCutoffCalculation(bedtimeHour: Int, wwLower: Int, wwUpper: Int) {
        let bedtime = Calendar.current.date(
            from: DateComponents(year: 2026, month: 2, day: 11, hour: bedtimeHour, minute: 0)
        )!
        let ww = wwLower...wwUpper
        let cutoff = DayEngine.napCutoffTime(bedtime: bedtime, lastWakeWindow: ww)

        let expectedCutoff = bedtime.addingTimeInterval(-Double(wwUpper) * 60)
        #expect(cutoff == expectedCutoff)
    }
}
