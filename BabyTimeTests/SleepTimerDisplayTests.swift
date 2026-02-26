//
//  SleepTimerDisplayTests.swift
//  BabyTimeTests
//
//  Tests for ActivityManager.sleepTimerString(at:) duration logic.
//  Verifies the three-state model: no session, static duration, live ticking.
//

import Dependencies
import SQLiteData
import Testing
import Foundation
@testable import BabyTime

// MARK: - Timer Display Tests

@Suite("Sleep Timer Display", .serialized)
@MainActor
struct SleepTimerDisplayTests {

    private func withManager(_ body: (ActivityManager) -> Void) {
        withDependencies {
            try! $0.bootstrapTestDatabase()
        } operation: {
            @Dependency(\.defaultDatabase) var database
            let manager = ActivityManager(database: database)
            let baby = manager.addBaby(name: "Test", birthdate: Date())
            manager.selectBaby(baby)
            body(manager)
        }
    }

    @Test("No start time returns 00:00")
    func noStartTime() {
        withManager { manager in
            let result = manager.sleepTimerString(at: Date())

            #expect(result == "00:00")
        }
    }

    @Test("Active session ticks with provided date")
    func activeTicking() {
        withManager { manager in
            manager.startSleep()
            let startTime = manager.sleepStartTime!

            // Simulate 5 minutes and 30 seconds later
            let futureDate = startTime.addingTimeInterval(5 * 60 + 30)
            let result = manager.sleepTimerString(at: futureDate)

            #expect(result == "05:30")
        }
    }

    @Test("Stopped session shows static duration")
    func stoppedStatic() {
        withManager { manager in
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
    }

    @Test("Stopped session does not tick with later date")
    func stoppedDoesNotTick() {
        withManager { manager in
            let start = Date().addingTimeInterval(-600) // 10 min ago
            manager.startSleep(at: start)
            manager.stopSleep()

            let resultNow = manager.sleepTimerString(at: Date())
            let resultLater = manager.sleepTimerString(at: Date().addingTimeInterval(3600))

            #expect(resultNow == resultLater)
        }
    }

    @Test("Active session with known elapsed shows correct format")
    func activeKnownElapsed() {
        withManager { manager in
            let exactStart = Date().addingTimeInterval(-125) // 2min 5sec ago
            manager.startSleep(at: exactStart)

            let result = manager.sleepTimerString(at: Date())

            #expect(result == "02:05")
        }
    }
}
