//
//  ActivityManagerSleepTests.swift
//  BabyTimeTests
//
//  Tests for ActivityManager sleep state machine transitions.
//

import Testing
import Foundation
import SwiftData
@testable import BabyTime

// MARK: - Sleep State Machine Tests

@Suite("Sleep State Machine", .serialized)
@MainActor
struct SleepStateMachineTests {

    private func withManager(_ body: (ActivityManager) -> Void) {
        let config = ModelConfiguration("test-\(UUID())", isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try! ModelContainer(
            for: Baby.self, FeedEvent.self, SleepEvent.self, WakeEvent.self,
            configurations: config
        )
        withExtendedLifetime(container) {
            let manager = ActivityManager(modelContext: container.mainContext)
            let baby = manager.addBaby(name: "Test", birthdate: Date())
            manager.selectBaby(baby)
            body(manager)
        }
    }

    @Test("startSleep creates active session")
    func startSleep() {
        withManager { manager in
            manager.startSleep()

            #expect(manager.isSleepActive == true)
            #expect(manager.hasSleepSession == true)
            #expect(manager.sleepStartTime != nil)
            #expect(manager.sleepEndTime == nil)
        }
    }

    @Test("startSleep with past date uses that date")
    func startSleepAtPastDate() {
        withManager { manager in
            let pastDate = Date().addingTimeInterval(-3600)

            manager.startSleep(at: pastDate)

            #expect(manager.isSleepActive == true)
            #expect(abs(manager.sleepStartTime!.timeIntervalSince(pastDate)) < 1)
        }
    }

    @Test("stopSleep sets endTime, session remains")
    func stopSleep() {
        withManager { manager in
            manager.startSleep()

            manager.stopSleep()

            #expect(manager.isSleepActive == false)
            #expect(manager.hasSleepSession == true)
            #expect(manager.sleepEndTime != nil)
        }
    }

    @Test("resumeSleep clears endTime")
    func resumeSleep() {
        withManager { manager in
            manager.startSleep()
            manager.stopSleep()
            #expect(manager.isSleepActive == false)

            manager.resumeSleep()

            #expect(manager.isSleepActive == true)
            #expect(manager.sleepEndTime == nil)
        }
    }

    @Test("resetSleep deletes event entirely")
    func resetSleep() {
        withManager { manager in
            manager.startSleep()

            manager.resetSleep()

            #expect(manager.isSleepActive == false)
            #expect(manager.hasSleepSession == false)
            #expect(manager.sleepStartTime == nil)
            #expect(manager.sleepEndTime == nil)
        }
    }

    @Test("saveSleep on active session sets endTime and clears reference")
    func saveSleepActive() {
        withManager { manager in
            manager.startSleep()
            #expect(manager.isSleepActive == true)

            manager.saveSleep()

            #expect(manager.isSleepActive == false)
            #expect(manager.hasSleepSession == false)
        }
    }

    @Test("saveSleep on stopped session clears reference and persists")
    func saveSleepStopped() {
        withManager { manager in
            manager.startSleep()
            manager.stopSleep()

            manager.saveSleep()

            #expect(manager.hasSleepSession == false)
        }
    }

    @Test("saveSleepManual creates complete event")
    func saveSleepManual() {
        withManager { manager in
            let start = Date().addingTimeInterval(-7200)
            let end = Date().addingTimeInterval(-3600)

            manager.saveSleepManual(startTime: start, endTime: end)

            #expect(manager.hasSleepSession == false)
            manager.refresh()
            #expect(manager.todaySleeps.count == 1)
            #expect(abs(manager.todaySleeps.first!.startTime.timeIntervalSince(start)) < 1)
            #expect(abs(manager.todaySleeps.first!.endTime!.timeIntervalSince(end)) < 1)
        }
    }

    @Test("stopSleep on non-active session is a no-op")
    func stopSleepNoop() {
        withManager { manager in
            manager.startSleep()
            manager.stopSleep()
            let endTime = manager.sleepEndTime

            manager.stopSleep()

            #expect(manager.sleepEndTime == endTime)
        }
    }

    @Test("saveSleep with no active event is a no-op")
    func saveSleepNoop() {
        withManager { manager in
            manager.saveSleep()

            #expect(manager.hasSleepSession == false)
        }
    }
}

// MARK: - Overnight Sleep Flow Tests

@Suite("Overnight Sleep Flow", .serialized)
@MainActor
struct OvernightSleepFlowTests {

    private func withManager(_ body: (ActivityManager) -> Void) {
        let config = ModelConfiguration("test-\(UUID())", isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try! ModelContainer(
            for: Baby.self, FeedEvent.self, SleepEvent.self, WakeEvent.self,
            configurations: config
        )
        withExtendedLifetime(container) {
            let manager = ActivityManager(modelContext: container.mainContext)
            let baby = manager.addBaby(name: "Test", birthdate: Calendar.current.date(byAdding: .day, value: -90, to: Date())!)
            manager.selectBaby(baby)
            body(manager)
        }
    }

    @Test("logBedtime creates active night sleep")
    func logBedtimeCreatesNightSleep() {
        withManager { manager in
            let bedtime = Date().addingTimeInterval(-3600) // 1 hour ago
            manager.logBedtime(bedtime)

            #expect(manager.activeNightSleep != nil)
            #expect(manager.isAsleepForNight == true)
            #expect(manager.activeNightSleep?.isNightSleep == true)
            #expect(manager.activeNightSleep?.isActive == true)
        }
    }

    @Test("logWakeUp before 5 AM ends night sleep but does NOT set wake time")
    func logWakeUpBeforeFiveAM() {
        withManager { manager in
            let bedtime = Date().addingTimeInterval(-3600)
            manager.logBedtime(bedtime)

            // Wake up at 3 AM (before 5 AM threshold)
            var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
            comps.hour = 3
            comps.minute = 0
            let earlyWake = Calendar.current.date(from: comps)!

            manager.logWakeUp(at: earlyWake)

            #expect(manager.activeNightSleep == nil, "Night sleep should be ended")
            #expect(manager.isAsleepForNight == false)
            #expect(manager.hasWakeTime == false, "Should NOT set wake time before 5 AM")
        }
    }

    @Test("logWakeUp after 5 AM ends night sleep AND sets wake time")
    func logWakeUpAfterFiveAM() {
        withManager { manager in
            let bedtime = Date().addingTimeInterval(-3600)
            manager.logBedtime(bedtime)

            // Wake up at 6:30 AM (after 5 AM threshold)
            var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
            comps.hour = 6
            comps.minute = 30
            let morningWake = Calendar.current.date(from: comps)!

            manager.logWakeUp(at: morningWake)

            #expect(manager.activeNightSleep == nil, "Night sleep should be ended")
            #expect(manager.isAsleepForNight == false)
            #expect(manager.hasWakeTime == true, "Should set wake time after 5 AM")
        }
    }

    @Test("Overnight cycle: bedtime → wake (2 AM) → bedtime → wake (6:30 AM)")
    func overnightWakeCycle() {
        withManager { manager in
            // 1. Log bedtime at 7 PM
            var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
            comps.hour = 19; comps.minute = 0
            let bedtime1 = Calendar.current.date(from: comps)!
            manager.logBedtime(bedtime1)

            #expect(manager.isAsleepForNight == true)

            // 2. Wake at 2 AM (before 5 AM → overnight wake)
            comps.hour = 2; comps.minute = 0
            let wake1 = Calendar.current.date(from: comps)!
            manager.logWakeUp(at: wake1)

            #expect(manager.isAsleepForNight == false)
            #expect(manager.hasWakeTime == false)

            // 3. Back to bed at 2:30 AM
            comps.hour = 2; comps.minute = 30
            let bedtime2 = Calendar.current.date(from: comps)!
            manager.logBedtime(bedtime2)

            #expect(manager.isAsleepForNight == true)

            // 4. Morning wake at 6:30 AM (after 5 AM → sets wake time)
            comps.hour = 6; comps.minute = 30
            let wake2 = Calendar.current.date(from: comps)!
            manager.logWakeUp(at: wake2)

            #expect(manager.isAsleepForNight == false)
            #expect(manager.hasWakeTime == true)
        }
    }

    @Test("logWakeUp with no active night sleep is a no-op")
    func logWakeUpNoop() {
        withManager { manager in
            manager.logWakeUp(at: Date())

            #expect(manager.hasWakeTime == false)
            #expect(manager.isAsleepForNight == false)
        }
    }

    @Test("napCount excludes night sleep segments")
    func napCountExcludesNightSleep() {
        withManager { manager in
            // Log a completed night sleep segment
            var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
            comps.hour = 19; comps.minute = 0
            let bedtime = Calendar.current.date(from: comps)!
            manager.logBedtime(bedtime)

            comps.hour = 6; comps.minute = 30
            let wake = Calendar.current.date(from: comps)!
            manager.logWakeUp(at: wake)

            // Log a nap
            manager.startSleep()
            manager.stopSleep()
            manager.saveSleep()

            #expect(manager.napCount == 1, "Only the nap should count, not the night sleep")
        }
    }
}
