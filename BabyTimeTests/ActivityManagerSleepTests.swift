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

    private func makeManager() -> ActivityManager {
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try! ModelContainer(
            for: Baby.self, FeedEvent.self, SleepEvent.self, WakeEvent.self,
            configurations: config
        )
        let manager = ActivityManager(modelContext: container.mainContext)
        let baby = manager.addBaby(name: "Test", birthdate: Date())
        manager.selectBaby(baby)
        return manager
    }

    @Test("startSleep creates active session")
    func startSleep() {
        let manager = makeManager()

        manager.startSleep()

        #expect(manager.isSleepActive == true)
        #expect(manager.hasSleepSession == true)
        #expect(manager.sleepStartTime != nil)
        #expect(manager.sleepEndTime == nil)
    }

    @Test("startSleep with past date uses that date")
    func startSleepAtPastDate() {
        let manager = makeManager()
        let pastDate = Date().addingTimeInterval(-3600)

        manager.startSleep(at: pastDate)

        #expect(manager.isSleepActive == true)
        #expect(abs(manager.sleepStartTime!.timeIntervalSince(pastDate)) < 1)
    }

    @Test("stopSleep sets endTime, session remains")
    func stopSleep() {
        let manager = makeManager()
        manager.startSleep()

        manager.stopSleep()

        #expect(manager.isSleepActive == false)
        #expect(manager.hasSleepSession == true)
        #expect(manager.sleepEndTime != nil)
    }

    @Test("resumeSleep clears endTime")
    func resumeSleep() {
        let manager = makeManager()
        manager.startSleep()
        manager.stopSleep()
        #expect(manager.isSleepActive == false)

        manager.resumeSleep()

        #expect(manager.isSleepActive == true)
        #expect(manager.sleepEndTime == nil)
    }

    @Test("resetSleep deletes event entirely")
    func resetSleep() {
        let manager = makeManager()
        manager.startSleep()

        manager.resetSleep()

        #expect(manager.isSleepActive == false)
        #expect(manager.hasSleepSession == false)
        #expect(manager.sleepStartTime == nil)
        #expect(manager.sleepEndTime == nil)
    }

    @Test("saveSleep on active session sets endTime and clears reference")
    func saveSleepActive() {
        let manager = makeManager()
        manager.startSleep()
        #expect(manager.isSleepActive == true)

        manager.saveSleep()

        #expect(manager.isSleepActive == false)
        #expect(manager.hasSleepSession == false)
    }

    @Test("saveSleep on stopped session clears reference and persists")
    func saveSleepStopped() {
        let manager = makeManager()
        manager.startSleep()
        manager.stopSleep()

        manager.saveSleep()

        #expect(manager.hasSleepSession == false)
    }

    @Test("saveSleepManual creates complete event")
    func saveSleepManual() {
        let manager = makeManager()
        let start = Date().addingTimeInterval(-7200)
        let end = Date().addingTimeInterval(-3600)

        manager.saveSleepManual(startTime: start, endTime: end)

        #expect(manager.hasSleepSession == false)
        manager.refresh()
        #expect(manager.todaySleeps.count == 1)
        #expect(abs(manager.todaySleeps.first!.startTime.timeIntervalSince(start)) < 1)
        #expect(abs(manager.todaySleeps.first!.endTime!.timeIntervalSince(end)) < 1)
    }

    @Test("stopSleep on non-active session is a no-op")
    func stopSleepNoop() {
        let manager = makeManager()
        manager.startSleep()
        manager.stopSleep()
        let endTime = manager.sleepEndTime

        manager.stopSleep()

        #expect(manager.sleepEndTime == endTime)
    }

    @Test("saveSleep with no active event is a no-op")
    func saveSleepNoop() {
        let manager = makeManager()

        manager.saveSleep()

        #expect(manager.hasSleepSession == false)
    }
}
