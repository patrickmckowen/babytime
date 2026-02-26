//
//  NotificationSchedulerTests.swift
//  BabyTimeTests
//
//  Tests for the pure NotificationScheduler function.
//  Same pattern as DayEngineTests — construct inputs, assert on outputs.
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
    dreamFeedEnabled: Bool = false,
    dreamFeedHour: Int = 22,
    dreamFeedMinute: Int = 30,
    customFeedIntervalMinutes: Int = 0,
    referenceDate: Date = Date()
) -> Baby {
    let birthdate = Calendar.current.date(
        byAdding: .day, value: -ageDays, to: referenceDate
    )!
    return Baby(
        name: "Test",
        birthdate: birthdate,
        bedtimeHour: bedtimeHour,
        bedtimeMinute: bedtimeMinute,
        dreamFeedEnabled: dreamFeedEnabled,
        dreamFeedHour: dreamFeedHour,
        dreamFeedMinute: dreamFeedMinute,
        customFeedIntervalMinutes: customFeedIntervalMinutes
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

/// Creates an active (in-progress) feed event
private func makeActiveFeed(
    startedMinutesAgo: Int,
    kind: FeedKind = .nursing,
    referenceDate: Date = Date()
) -> FeedEvent {
    let start = referenceDate.addingTimeInterval(-Double(startedMinutesAgo) * 60)
    return FeedEvent(startTime: start, endTime: nil, kind: kind)
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
    isNightSleep: Bool = false,
    referenceDate: Date = Date()
) -> SleepEvent {
    let start = referenceDate.addingTimeInterval(-Double(startedMinutesAgo) * 60)
    return SleepEvent(startTime: start, endTime: nil, isNightSleep: isNightSleep)
}

/// Extracts trigger IDs from result array
private func triggerIDs(_ triggers: [NotificationTrigger]) -> Set<String> {
    Set(triggers.map(\.id))
}

// MARK: - Tests

@Suite("NotificationScheduler — Trigger Computation")
struct NotificationSchedulerTests {

    // Fixed reference time: 2pm on Feb 20, 2026
    let now = Calendar.current.date(
        from: DateComponents(year: 2026, month: 2, day: 20, hour: 14, minute: 0)
    )!

    @Test("notStarted returns empty")
    func notStartedReturnsEmpty() {
        let baby = makeBaby(ageDays: 100, referenceDate: now)
        let snapshot = DayEngine.snapshot(baby: baby, feeds: [], sleeps: [], now: now)

        let triggers = NotificationScheduler.triggers(from: snapshot, baby: baby, now: now)

        #expect(triggers.isEmpty)
    }

    @Test("asleepForNight with dream feed enabled")
    func asleepForNightWithDreamFeed() {
        let baby = makeBaby(
            ageDays: 100,
            bedtimeHour: 19,
            dreamFeedEnabled: true,
            dreamFeedHour: 22,
            dreamFeedMinute: 30,
            referenceDate: now
        )
        let nightSleep = makeActiveSleep(startedMinutesAgo: 10, isNightSleep: true, referenceDate: now)
        let feed = makeFeed(minutesAgo: 60, referenceDate: now)

        let snapshot = DayEngine.snapshot(
            baby: baby, feeds: [feed], sleeps: [nightSleep], now: now
        )

        // Verify we're in asleepForNight state
        if case .asleepForNight = snapshot.dayState {
            // good
        } else {
            Issue.record("Expected asleepForNight, got \(snapshot.dayState)")
            return
        }

        let triggers = NotificationScheduler.triggers(from: snapshot, baby: baby, now: now)
        let ids = triggerIDs(triggers)

        #expect(ids == ["dream-feed"])
        #expect(triggers.first?.fireDate != nil)
    }

    @Test("asleepForNight without dream feed returns empty")
    func asleepForNightNoDreamFeed() {
        let baby = makeBaby(
            ageDays: 100,
            bedtimeHour: 19,
            dreamFeedEnabled: false,
            referenceDate: now
        )
        let nightSleep = makeActiveSleep(startedMinutesAgo: 10, isNightSleep: true, referenceDate: now)
        let feed = makeFeed(minutesAgo: 60, referenceDate: now)

        let snapshot = DayEngine.snapshot(
            baby: baby, feeds: [feed], sleeps: [nightSleep], now: now
        )

        let triggers = NotificationScheduler.triggers(from: snapshot, baby: baby, now: now)

        #expect(triggers.isEmpty)
    }

    @Test("Awake early schedules WW + feed + bedtime triggers")
    func awakeEarlySchedulesAll() {
        // 3-4 month old, just woke from nap 30 min ago, fed 20 min ago
        let baby = makeBaby(ageDays: 90, bedtimeHour: 19, referenceDate: now)
        let sleep = makeSleep(startedMinutesAgo: 60, durationMinutes: 30, referenceDate: now)
        let feed = makeFeed(minutesAgo: 20, referenceDate: now)

        let snapshot = DayEngine.snapshot(
            baby: baby, feeds: [feed], sleeps: [sleep], now: now
        )

        let triggers = NotificationScheduler.triggers(from: snapshot, baby: baby, now: now)
        let ids = triggerIDs(triggers)

        // WW2 for 3-4mo = 90...105 min. Awake 30 min → both WW triggers are future
        #expect(ids.contains("ww-approaching"))
        #expect(ids.contains("ww-exceeded"))
        // Feed interval for 3-4mo = 150...210 min. Fed 20 min ago → feed triggers are future
        #expect(ids.contains("feed-approaching"))
        #expect(ids.contains("feed-ready"))
        // Bedtime at 19:00, now is 14:00 → 30 min before = 18:30 → future
        #expect(ids.contains("bedtime-approaching"))
    }

    @Test("Sleeping suppresses WW triggers")
    func sleepingSuppressesWW() {
        let baby = makeBaby(ageDays: 90, referenceDate: now)
        let feed = makeFeed(minutesAgo: 60, referenceDate: now)
        let activeSleep = makeActiveSleep(startedMinutesAgo: 20, referenceDate: now)

        let snapshot = DayEngine.snapshot(
            baby: baby, feeds: [feed], sleeps: [activeSleep], now: now
        )

        let triggers = NotificationScheduler.triggers(from: snapshot, baby: baby, now: now)
        let ids = triggerIDs(triggers)

        #expect(!ids.contains("ww-approaching"))
        #expect(!ids.contains("ww-exceeded"))
    }

    @Test("Past triggers are excluded")
    func pastTriggersExcluded() {
        // 3-4 month old, awake for 120 min → WW2 (90...105) already passed
        let baby = makeBaby(ageDays: 90, referenceDate: now)
        // 1 completed nap 120 min ago
        let sleep = makeSleep(startedMinutesAgo: 150, durationMinutes: 30, referenceDate: now)
        let feed = makeFeed(minutesAgo: 60, referenceDate: now)

        let snapshot = DayEngine.snapshot(
            baby: baby, feeds: [feed], sleeps: [sleep], now: now
        )

        let triggers = NotificationScheduler.triggers(from: snapshot, baby: baby, now: now)
        let ids = triggerIDs(triggers)

        // Both WW triggers should be in the past (90 and 105 min < 120 min awake)
        #expect(!ids.contains("ww-approaching"))
        #expect(!ids.contains("ww-exceeded"))
    }

    @Test("Sleeping near cutoff schedules cutoff-reached")
    func sleepingNearCutoffSchedulesCutoffReached() {
        // Baby napping with cutoff upcoming
        let baby = makeBaby(ageDays: 90, bedtimeHour: 19, referenceDate: now)
        let feed = makeFeed(minutesAgo: 60, referenceDate: now)
        let activeSleep = makeActiveSleep(startedMinutesAgo: 30, referenceDate: now)

        let snapshot = DayEngine.snapshot(
            baby: baby, feeds: [feed], sleeps: [activeSleep], now: now
        )

        // Only check if actually sleeping
        switch snapshot.dayState {
        case .sleepingNoPressure, .sleepingApproachingCutoff, .sleepingMustEnd:
            break
        default:
            Issue.record("Expected sleeping state, got \(snapshot.dayState)")
            return
        }

        let triggers = NotificationScheduler.triggers(from: snapshot, baby: baby, now: now)
        let ids = triggerIDs(triggers)

        // Cutoff should be in the future → cutoff-reached scheduled
        if snapshot.napCutoff > now {
            #expect(ids.contains("cutoff-reached"))
        }
        // While sleeping, cutoff-approaching should NOT be scheduled
        #expect(!ids.contains("cutoff-approaching"))
    }

    @Test("Awake schedules cutoff-approaching when cutoff is future")
    func awakeCutoffApproaching() {
        // Baby awake, cutoff is in the future (30+ min away)
        let baby = makeBaby(ageDays: 90, bedtimeHour: 19, referenceDate: now)
        let feed = makeFeed(minutesAgo: 20, referenceDate: now)
        let sleep = makeSleep(startedMinutesAgo: 60, durationMinutes: 30, referenceDate: now)

        let snapshot = DayEngine.snapshot(
            baby: baby, feeds: [feed], sleeps: [sleep], now: now
        )

        let triggers = NotificationScheduler.triggers(from: snapshot, baby: baby, now: now)
        let ids = triggerIDs(triggers)

        // Nap cutoff is bedtime - lastWW. For 3-4mo, lastWW = 105...120
        // Bedtime 19:00 - 120 min = 16:00 cutoff, 30 min before = 15:30 → future from 14:00
        if snapshot.napCutoff.addingTimeInterval(-30 * 60) > now {
            #expect(ids.contains("cutoff-approaching"))
        }
        // While awake, cutoff-reached should NOT be scheduled
        #expect(!ids.contains("cutoff-reached"))
    }

    @Test("Feed approaching uses custom interval")
    func customFeedInterval() {
        let baby = makeBaby(
            ageDays: 90,
            customFeedIntervalMinutes: 90,
            referenceDate: now
        )
        let feed = makeFeed(minutesAgo: 30, referenceDate: now)
        let sleep = makeSleep(startedMinutesAgo: 60, durationMinutes: 30, referenceDate: now)

        let snapshot = DayEngine.snapshot(
            baby: baby, feeds: [feed], sleeps: [sleep], now: now
        )

        let triggers = NotificationScheduler.triggers(from: snapshot, baby: baby, now: now)

        // Custom interval = 90 min. 80% = 72 min. Fed 30 min ago.
        // feed-approaching fires at feedRef + 72 min = 42 min from now
        let feedApproaching = triggers.first { $0.id == "feed-approaching" }
        #expect(feedApproaching != nil)

        if let fa = feedApproaching, let feedRef = snapshot.lastFeedReference {
            let expectedMin = 90.0 * 0.8
            let expectedDate = feedRef.addingTimeInterval(expectedMin * 60)
            let diff = abs(fa.fireDate.timeIntervalSince(expectedDate))
            #expect(diff < 1) // within 1 second
        }
    }

    @Test("feedingNow suppresses feed triggers")
    func feedingNowSuppressesFeedTriggers() {
        let baby = makeBaby(ageDays: 90, referenceDate: now)
        let activeFeed = makeActiveFeed(startedMinutesAgo: 5, referenceDate: now)
        let sleep = makeSleep(startedMinutesAgo: 60, durationMinutes: 30, referenceDate: now)

        let snapshot = DayEngine.snapshot(
            baby: baby, feeds: [activeFeed], sleeps: [sleep], now: now
        )

        // Verify we're in feedingNow state
        if case .feedingNow = snapshot.feedState {
            // good
        } else {
            Issue.record("Expected feedingNow, got \(snapshot.feedState)")
            return
        }

        let triggers = NotificationScheduler.triggers(from: snapshot, baby: baby, now: now)
        let ids = triggerIDs(triggers)

        #expect(!ids.contains("feed-approaching"))
        #expect(!ids.contains("feed-ready"))
    }

    @Test("WW triggers suppressed when fire date is after nap cutoff")
    func wwTriggersSuppressedAfterNapCutoff() {
        // Scenario: 4-month-old, bedtime 7pm, 3 completed naps, last nap ended 5 min ago.
        // napCutoff = 19:00 - 120 min (lastWW upperBound) = 17:00
        // currentWW (3 completed naps → index 3) = 105...120 min
        // ww-approaching would fire at wakeRef + 105 min → well after 17:00 cutoff
        // ww-exceeded would fire at wakeRef + 120 min → also after cutoff
        // Both should be suppressed.

        let refTime = Calendar.current.date(
            from: DateComponents(year: 2026, month: 2, day: 20, hour: 16, minute: 20)
        )!

        let baby = makeBaby(ageDays: 120, bedtimeHour: 19, referenceDate: refTime)

        // 3 completed naps earlier in the day
        // nap3 ends at 16:15 (5 min before refTime) → wakeReference = 16:15
        // approachingDate = 16:15 + 105 = 18:00 → AFTER napCutoff (17:00)
        // exceededDate   = 16:15 + 120 = 18:15 → AFTER napCutoff (17:00)
        let nap1 = makeSleep(startedMinutesAgo: 360, durationMinutes: 60, referenceDate: refTime)
        let nap2 = makeSleep(startedMinutesAgo: 240, durationMinutes: 45, referenceDate: refTime)
        let nap3 = makeSleep(startedMinutesAgo: 35, durationMinutes: 30, referenceDate: refTime)

        let feed = makeFeed(minutesAgo: 30, referenceDate: refTime)

        let snapshot = DayEngine.snapshot(
            baby: baby, feeds: [feed], sleeps: [nap1, nap2, nap3], now: refTime
        )

        // Verify preconditions
        #expect(snapshot.completedNaps == 3)
        #expect(snapshot.napCutoff < refTime.addingTimeInterval(105 * 60))

        let triggers = NotificationScheduler.triggers(from: snapshot, baby: baby, now: refTime)
        let ids = triggerIDs(triggers)

        #expect(!ids.contains("ww-approaching"), "Should not suggest a nap after nap cutoff")
        #expect(!ids.contains("ww-exceeded"), "Should not report wake window ended after nap cutoff")
    }

    @Test("Sleeping suppresses feed triggers")
    func sleepingSuppressesFeedTriggers() {
        let baby = makeBaby(ageDays: 90, referenceDate: now)
        let feed = makeFeed(minutesAgo: 60, referenceDate: now)
        let activeSleep = makeActiveSleep(startedMinutesAgo: 20, referenceDate: now)

        let snapshot = DayEngine.snapshot(
            baby: baby, feeds: [feed], sleeps: [activeSleep], now: now
        )

        // Verify baby is sleeping
        switch snapshot.dayState {
        case .sleepingNoPressure, .sleepingApproachingCutoff, .sleepingMustEnd:
            break
        default:
            Issue.record("Expected sleeping state, got \(snapshot.dayState)")
            return
        }

        let triggers = NotificationScheduler.triggers(from: snapshot, baby: baby, now: now)
        let ids = triggerIDs(triggers)

        #expect(!ids.contains("feed-approaching"), "Should not schedule feed-approaching while sleeping")
        #expect(!ids.contains("feed-ready"), "Should not schedule feed-ready while sleeping")
    }

    @Test("Sleeping suppresses bedtime-approaching")
    func sleepingSuppressesBedtimeApproaching() {
        let baby = makeBaby(ageDays: 90, bedtimeHour: 19, referenceDate: now)
        let feed = makeFeed(minutesAgo: 60, referenceDate: now)
        let activeSleep = makeActiveSleep(startedMinutesAgo: 20, referenceDate: now)

        let snapshot = DayEngine.snapshot(
            baby: baby, feeds: [feed], sleeps: [activeSleep], now: now
        )

        // Verify baby is sleeping
        switch snapshot.dayState {
        case .sleepingNoPressure, .sleepingApproachingCutoff, .sleepingMustEnd:
            break
        default:
            Issue.record("Expected sleeping state, got \(snapshot.dayState)")
            return
        }

        let triggers = NotificationScheduler.triggers(from: snapshot, baby: baby, now: now)
        let ids = triggerIDs(triggers)

        #expect(!ids.contains("bedtime-approaching"), "Should not schedule bedtime-approaching while sleeping")
    }

    @Test("No feeds logged uses wakeReference for feed timing")
    func noFeedsUsesWakeReference() {
        // Baby woke from nap 30 min ago, no feeds logged today
        let baby = makeBaby(ageDays: 90, referenceDate: now)
        let sleep = makeSleep(startedMinutesAgo: 60, durationMinutes: 30, referenceDate: now)

        let snapshot = DayEngine.snapshot(
            baby: baby, feeds: [], sleeps: [sleep], now: now
        )

        // Verify wakeReference is set and lastFeedReference is nil
        #expect(snapshot.wakeReference != nil, "wakeReference should be set after nap")
        #expect(snapshot.lastFeedReference == nil, "lastFeedReference should be nil with no feeds")

        let triggers = NotificationScheduler.triggers(from: snapshot, baby: baby, now: now)
        let ids = triggerIDs(triggers)

        // Feed triggers should fire based on wakeReference
        #expect(ids.contains("feed-approaching"), "Should schedule feed-approaching from wakeReference")
        #expect(ids.contains("feed-ready"), "Should schedule feed-ready from wakeReference")
    }

    @Test("Trigger fire dates are all in the future")
    func allTriggersInFuture() {
        let baby = makeBaby(ageDays: 90, referenceDate: now)
        let feed = makeFeed(minutesAgo: 20, referenceDate: now)
        let sleep = makeSleep(startedMinutesAgo: 60, durationMinutes: 30, referenceDate: now)

        let snapshot = DayEngine.snapshot(
            baby: baby, feeds: [feed], sleeps: [sleep], now: now
        )

        let triggers = NotificationScheduler.triggers(from: snapshot, baby: baby, now: now)

        for trigger in triggers {
            #expect(trigger.fireDate > now, "Trigger \(trigger.id) should be in the future")
        }
    }
}
