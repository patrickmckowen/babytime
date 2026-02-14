//
//  SleepTimerDisplayTests.swift
//  BabyTimeTests
//
//  Tests for ActivityManager.sleepTimerString(at:) duration logic.
//  Verifies the three-state model: no session, static duration, live ticking.
//

import Testing
import Foundation
import SwiftData
@testable import BabyTime

// MARK: - Test Helpers

@MainActor
private func makeManager() -> (ActivityManager, Baby) {
    let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
    let container = try! ModelContainer(
        for: Baby.self, FeedEvent.self, SleepEvent.self, WakeEvent.self,
        configurations: config
    )
    let manager = ActivityManager(modelContext: container.mainContext)
    let baby = manager.addBaby(name: "Test", birthdate: Date())
    manager.selectBaby(baby)
    return (manager, baby)
}

// MARK: - Timer Display Tests

@Suite("Sleep Timer Display")
@MainActor
struct SleepTimerDisplayTests {

    @Test("No start time returns 00:00")
    func noStartTime() {
        let (manager, _) = makeManager()

        let result = manager.sleepTimerString(at: Date())

        #expect(result == "00:00")
    }

    @Test("Active session ticks with provided date")
    func activeTicking() {
        let (manager, _) = makeManager()
        manager.startSleep()
        let startTime = manager.sleepStartTime!

        // Simulate 5 minutes and 30 seconds later
        let futureDate = startTime.addingTimeInterval(5 * 60 + 30)
        let result = manager.sleepTimerString(at: futureDate)

        #expect(result == "05:30")
    }

    @Test("Stopped session shows static duration")
    func stoppedStatic() {
        let (manager, _) = makeManager()
        manager.startSleep()
        let startTime = manager.sleepStartTime!

        // Stop after some time
        manager.stopSleep()
        let endTime = manager.sleepEndTime!
        let expectedElapsed = Int(endTime.timeIntervalSince(startTime))
        let expectedMins = expectedElapsed / 60
        let expectedSecs = expectedElapsed % 60
        let expected = String(format: "%02d:%02d", expectedMins, expectedSecs)

        // Calling with a much later date should NOT change the result (not ticking)
        let muchLater = Date().addingTimeInterval(9999)
        let result = manager.sleepTimerString(at: muchLater)

        #expect(result == expected)
    }

    @Test("Stopped session does not tick with later date")
    func stoppedDoesNotTick() {
        let (manager, _) = makeManager()
        let start = Date().addingTimeInterval(-600) // 10 min ago
        manager.startSleep(at: start)
        manager.stopSleep()

        let resultNow = manager.sleepTimerString(at: Date())
        let resultLater = manager.sleepTimerString(at: Date().addingTimeInterval(3600))

        #expect(resultNow == resultLater)
    }

    @Test("Active session with known elapsed shows correct format")
    func activeKnownElapsed() {
        let (manager, _) = makeManager()
        let exactStart = Date().addingTimeInterval(-125) // 2min 5sec ago
        manager.startSleep(at: exactStart)

        let result = manager.sleepTimerString(at: Date())

        #expect(result == "02:05")
    }
}
