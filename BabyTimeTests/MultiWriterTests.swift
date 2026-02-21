//
//  MultiWriterTests.swift
//  BabyTimeTests
//
//  Tests for multi-writer data layer: conflict detection, auto-resolution,
//  computed active event discovery, and caregiver identity stamping.
//

import Testing
import Foundation
@testable import BabyTime

// MARK: - Test Helpers

private func makeBaby(
    ageDays: Int = 90,
    bedtimeHour: Int = 19,
    referenceDate: Date = Date()
) -> Baby {
    let birthdate = Calendar.current.date(
        byAdding: .day, value: -ageDays, to: referenceDate
    )!
    return Baby(
        name: "Test",
        birthdate: birthdate,
        bedtimeHour: bedtimeHour,
        bedtimeMinute: 0
    )
}

private func makeActiveNursing(
    startedMinutesAgo: Int,
    caregiverName: String = "",
    referenceDate: Date = Date()
) -> FeedEvent {
    let start = referenceDate.addingTimeInterval(-Double(startedMinutesAgo) * 60)
    return FeedEvent(
        startTime: start,
        endTime: nil,
        kind: .nursing,
        side: .both,
        caregiverName: caregiverName,
        deviceID: "test-device"
    )
}

private func makeActiveSleep(
    startedMinutesAgo: Int,
    isNightSleep: Bool = false,
    caregiverName: String = "",
    referenceDate: Date = Date()
) -> SleepEvent {
    let start = referenceDate.addingTimeInterval(-Double(startedMinutesAgo) * 60)
    return SleepEvent(
        startTime: start,
        endTime: nil,
        isNightSleep: isNightSleep,
        caregiverName: caregiverName,
        deviceID: "test-device"
    )
}

private func makeCompletedFeed(
    minutesAgo: Int,
    referenceDate: Date = Date()
) -> FeedEvent {
    let start = referenceDate.addingTimeInterval(-Double(minutesAgo) * 60)
    return FeedEvent(
        startTime: start,
        endTime: start.addingTimeInterval(10 * 60),
        kind: .bottle,
        amountOz: 4
    )
}

// MARK: - Conflict Detection (DayEngine)

@Suite("Multi-Writer — Conflict Detection")
struct ConflictDetectionTests {

    let now = Calendar.current.date(
        from: DateComponents(year: 2026, month: 2, day: 20, hour: 14, minute: 0)
    )!

    @Test("No conflicts when single active feed")
    func singleActiveFeedNoConflict() {
        let baby = makeBaby(referenceDate: now)
        let feed = makeActiveNursing(startedMinutesAgo: 10, referenceDate: now)

        let snapshot = DayEngine.snapshot(
            baby: baby, feeds: [feed], sleeps: [], now: now
        )

        #expect(snapshot.conflicts.isEmpty)
    }

    @Test("No conflicts when single active sleep")
    func singleActiveSleepNoConflict() {
        let baby = makeBaby(referenceDate: now)
        let sleep = makeActiveSleep(startedMinutesAgo: 20, referenceDate: now)

        let snapshot = DayEngine.snapshot(
            baby: baby, feeds: [], sleeps: [sleep], now: now
        )

        #expect(snapshot.conflicts.isEmpty)
    }

    @Test("No conflict for one active feed + one active sleep")
    func feedAndSleepNotConflict() {
        let baby = makeBaby(referenceDate: now)
        let feed = makeActiveNursing(startedMinutesAgo: 10, referenceDate: now)
        let sleep = makeActiveSleep(startedMinutesAgo: 5, referenceDate: now)

        let snapshot = DayEngine.snapshot(
            baby: baby, feeds: [feed], sleeps: [sleep], now: now
        )

        #expect(snapshot.conflicts.isEmpty)
    }

    @Test("Conflict detected: two active nursing sessions")
    func twoActiveNursingConflict() {
        let baby = makeBaby(referenceDate: now)
        let feed1 = makeActiveNursing(
            startedMinutesAgo: 10, caregiverName: "Mom", referenceDate: now
        )
        let feed2 = makeActiveNursing(
            startedMinutesAgo: 8, caregiverName: "Dad", referenceDate: now
        )

        let snapshot = DayEngine.snapshot(
            baby: baby, feeds: [feed1, feed2], sleeps: [], now: now
        )

        #expect(snapshot.conflicts.count == 1)
        if case .multipleActiveFeeds(let count) = snapshot.conflicts.first?.kind {
            #expect(count == 2)
        } else {
            Issue.record("Expected multipleActiveFeeds conflict")
        }
        #expect(snapshot.conflicts.first?.caregiverNames.contains("Mom") == true)
        #expect(snapshot.conflicts.first?.caregiverNames.contains("Dad") == true)
    }

    @Test("Conflict detected: two active naps")
    func twoActiveNapsConflict() {
        let baby = makeBaby(referenceDate: now)
        let sleep1 = makeActiveSleep(
            startedMinutesAgo: 20, caregiverName: "Mom", referenceDate: now
        )
        let sleep2 = makeActiveSleep(
            startedMinutesAgo: 15, caregiverName: "Dad", referenceDate: now
        )

        let snapshot = DayEngine.snapshot(
            baby: baby, feeds: [], sleeps: [sleep1, sleep2], now: now
        )

        #expect(snapshot.conflicts.count == 1)
        if case .multipleActiveSleeps(let count) = snapshot.conflicts.first?.kind {
            #expect(count == 2)
        } else {
            Issue.record("Expected multipleActiveSleeps conflict")
        }
    }

    @Test("No conflict with completed events")
    func completedEventsNoConflict() {
        let baby = makeBaby(referenceDate: now)
        let feed1 = makeCompletedFeed(minutesAgo: 60, referenceDate: now)
        let feed2 = makeCompletedFeed(minutesAgo: 120, referenceDate: now)

        let snapshot = DayEngine.snapshot(
            baby: baby, feeds: [feed1, feed2], sleeps: [], now: now
        )

        #expect(snapshot.conflicts.isEmpty)
    }

    @Test("DayEngine still derives correct state even with conflicts")
    func stateDerivationWithConflicts() {
        let baby = makeBaby(referenceDate: now)
        // Two active nursings — engine should still pick the first for feedState
        let feed1 = makeActiveNursing(startedMinutesAgo: 10, referenceDate: now)
        let feed2 = makeActiveNursing(startedMinutesAgo: 5, referenceDate: now)

        let snapshot = DayEngine.snapshot(
            baby: baby, feeds: [feed1, feed2], sleeps: [], now: now
        )

        // feedState should reflect the active feed (feedingNow)
        if case .feedingNow = snapshot.feedState {
            // good — engine still works
        } else {
            Issue.record("Expected feedingNow even with conflict, got \(snapshot.feedState)")
        }
        // Conflict is also reported
        #expect(snapshot.conflicts.count == 1)
    }
}

// MARK: - Identity Stamping

@Suite("Multi-Writer — Identity Stamping")
struct IdentityStampingTests {

    @Test("FeedEvent gets default identity from DeviceIdentity")
    func feedEventIdentity() {
        let event = FeedEvent(startTime: Date(), kind: .nursing)
        #expect(!event.deviceID.isEmpty)
        // caregiverName may be empty if not configured, but deviceID is always set
        #expect(event.deviceID == DeviceIdentity.deviceID)
    }

    @Test("SleepEvent gets default identity from DeviceIdentity")
    func sleepEventIdentity() {
        let event = SleepEvent(startTime: Date())
        #expect(!event.deviceID.isEmpty)
        #expect(event.deviceID == DeviceIdentity.deviceID)
    }

    @Test("WakeEvent gets default identity from DeviceIdentity")
    func wakeEventIdentity() {
        let event = WakeEvent(date: Date(), time: Date())
        #expect(!event.deviceID.isEmpty)
        #expect(event.deviceID == DeviceIdentity.deviceID)
    }

    @Test("Custom identity overrides defaults")
    func customIdentityOverride() {
        let event = FeedEvent(
            startTime: Date(),
            kind: .nursing,
            caregiverName: "Test Caregiver",
            deviceID: "custom-device-123"
        )
        #expect(event.caregiverName == "Test Caregiver")
        #expect(event.deviceID == "custom-device-123")
    }
}

// MARK: - DeviceIdentity

@Suite("Multi-Writer — DeviceIdentity")
struct DeviceIdentityTests {

    @Test("DeviceID is stable across calls")
    func deviceIDStable() {
        let id1 = DeviceIdentity.deviceID
        let id2 = DeviceIdentity.deviceID
        #expect(id1 == id2)
        #expect(!id1.isEmpty)
    }

    @Test("DeviceID is a valid UUID string")
    func deviceIDIsUUID() {
        let id = DeviceIdentity.deviceID
        #expect(UUID(uuidString: id) != nil)
    }
}
