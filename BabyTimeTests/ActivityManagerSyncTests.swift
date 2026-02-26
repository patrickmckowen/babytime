//
//  ActivityManagerSyncTests.swift
//  BabyTimeTests
//
//  Tests for multi-device sync behavior in ActivityManager:
//  autoCloseStaleEvents deviceID filtering and SyncDelegate.
//

import Dependencies
import SQLiteData
import Testing
import Foundation
@testable import BabyTime

// MARK: - autoCloseStaleEvents Multi-Device Tests

@Suite("AutoClose — Multi-Device Filtering", .serialized)
@MainActor
struct AutoCloseMultiDeviceTests {

    private func withManager(_ body: (ActivityManager, any DatabaseWriter, Baby) -> Void) {
        withDependencies {
            try! $0.bootstrapTestDatabase()
        } operation: {
            @Dependency(\.defaultDatabase) var database
            let manager = ActivityManager(database: database)
            let baby = manager.addBaby(
                name: "Test",
                birthdate: Calendar.current.date(byAdding: .day, value: -90, to: Date())!
            )
            manager.selectBaby(baby)
            body(manager, database, baby)
        }
    }

    @Test("Duplicate local nursings are closed, remote nursing is preserved")
    func duplicateLocalNursingsClosed() {
        withManager { manager, database, baby in
            let localDeviceID = DeviceIdentity.deviceID
            let remoteDeviceID = "remote-device-\(UUID().uuidString)"

            // Insert two local active nursings and one remote active nursing
            let localNursing1 = FeedEvent(
                id: UUID(), babyID: baby.id,
                startTime: Date().addingTimeInterval(-600),
                feedKind: .nursing, nursingSide: .both,
                caregiverName: "Mom", deviceID: localDeviceID
            )
            let localNursing2 = FeedEvent(
                id: UUID(), babyID: baby.id,
                startTime: Date().addingTimeInterval(-300),
                feedKind: .nursing, nursingSide: .both,
                caregiverName: "Mom", deviceID: localDeviceID
            )
            let remoteNursing = FeedEvent(
                id: UUID(), babyID: baby.id,
                startTime: Date().addingTimeInterval(-200),
                feedKind: .nursing, nursingSide: .left,
                caregiverName: "Dad", deviceID: remoteDeviceID
            )

            try? database.write { db in
                try FeedEvent.insert { localNursing1 }.execute(db)
                try FeedEvent.insert { localNursing2 }.execute(db)
                try FeedEvent.insert { remoteNursing }.execute(db)
            }

            // Trigger refresh which calls autoCloseStaleEvents
            manager.refresh()

            // Check results
            let activeNursings = (try? database.read { db in
                try FeedEvent
                    .where { $0.babyID.eq(#bind(baby.id)) && $0.feedKind.eq(#bind(FeedKind.nursing)) && $0.endTime.is(nil) }
                    .fetchAll(db)
            }) ?? []

            // Local: earliest kept active, second closed
            // Remote: preserved as-is
            #expect(activeNursings.count == 2, "Should have 1 local + 1 remote active nursing")
            #expect(activeNursings.contains(where: { $0.id == localNursing1.id }), "Earliest local nursing should stay active")
            #expect(activeNursings.contains(where: { $0.id == remoteNursing.id }), "Remote nursing should stay active")
            #expect(!activeNursings.contains(where: { $0.id == localNursing2.id }), "Second local nursing should be closed")
        }
    }

    @Test("Duplicate local naps are closed, remote nap is preserved")
    func duplicateLocalNapsClosed() {
        withManager { manager, database, baby in
            let localDeviceID = DeviceIdentity.deviceID
            let remoteDeviceID = "remote-device-\(UUID().uuidString)"

            let localNap1 = SleepEvent(
                id: UUID(), babyID: baby.id,
                startTime: Date().addingTimeInterval(-1200),
                isNightSleep: false,
                caregiverName: "Mom", deviceID: localDeviceID
            )
            let localNap2 = SleepEvent(
                id: UUID(), babyID: baby.id,
                startTime: Date().addingTimeInterval(-600),
                isNightSleep: false,
                caregiverName: "Mom", deviceID: localDeviceID
            )
            let remoteNap = SleepEvent(
                id: UUID(), babyID: baby.id,
                startTime: Date().addingTimeInterval(-300),
                isNightSleep: false,
                caregiverName: "Dad", deviceID: remoteDeviceID
            )

            try? database.write { db in
                try SleepEvent.insert { localNap1 }.execute(db)
                try SleepEvent.insert { localNap2 }.execute(db)
                try SleepEvent.insert { remoteNap }.execute(db)
            }

            manager.refresh()

            let activeNaps = (try? database.read { db in
                try SleepEvent
                    .where { $0.babyID.eq(#bind(baby.id)) && $0.isNightSleep.eq(false) && $0.endTime.is(nil) }
                    .fetchAll(db)
            }) ?? []

            #expect(activeNaps.count == 2, "Should have 1 local + 1 remote active nap")
            #expect(activeNaps.contains(where: { $0.id == localNap1.id }), "Earliest local nap should stay active")
            #expect(activeNaps.contains(where: { $0.id == remoteNap.id }), "Remote nap should stay active")
            #expect(!activeNaps.contains(where: { $0.id == localNap2.id }), "Second local nap should be closed")
        }
    }

    @Test("Stale night sleep (>48h) is closed regardless of device origin")
    func staleNightSleepClosedGlobally() {
        withManager { manager, database, baby in
            let remoteDeviceID = "remote-device-\(UUID().uuidString)"

            // Night sleep started 49 hours ago from a remote device
            let staleNight = SleepEvent(
                id: UUID(), babyID: baby.id,
                startTime: Date().addingTimeInterval(-49 * 3600),
                isNightSleep: true,
                caregiverName: "Dad", deviceID: remoteDeviceID
            )

            try? database.write { db in
                try SleepEvent.insert { staleNight }.execute(db)
            }

            manager.refresh()

            let fetched = try? database.read { db in
                try SleepEvent.find(staleNight.id).fetchOne(db)
            }

            #expect(fetched?.endTime != nil, "Stale night sleep should be closed regardless of device origin")
        }
    }

    @Test("Remote-only active nursings are not touched when no local duplicates exist")
    func remoteOnlyNursingsUntouched() {
        withManager { manager, database, baby in
            let remoteDeviceID = "remote-device-\(UUID().uuidString)"

            let remoteNursing1 = FeedEvent(
                id: UUID(), babyID: baby.id,
                startTime: Date().addingTimeInterval(-600),
                feedKind: .nursing, nursingSide: .both,
                caregiverName: "Dad", deviceID: remoteDeviceID
            )
            let remoteNursing2 = FeedEvent(
                id: UUID(), babyID: baby.id,
                startTime: Date().addingTimeInterval(-300),
                feedKind: .nursing, nursingSide: .left,
                caregiverName: "Dad", deviceID: remoteDeviceID
            )

            try? database.write { db in
                try FeedEvent.insert { remoteNursing1 }.execute(db)
                try FeedEvent.insert { remoteNursing2 }.execute(db)
            }

            manager.refresh()

            let activeNursings = (try? database.read { db in
                try FeedEvent
                    .where { $0.babyID.eq(#bind(baby.id)) && $0.feedKind.eq(#bind(FeedKind.nursing)) && $0.endTime.is(nil) }
                    .fetchAll(db)
            }) ?? []

            #expect(activeNursings.count == 2, "Both remote nursings should remain active")
        }
    }
}

// MARK: - SyncDelegate Tests

@Suite("SyncDelegate — Account Change Alert")
@MainActor
struct SyncDelegateTests {

    @Test("showResetDataAlert defaults to false")
    func defaultState() {
        let delegate = SyncDelegate()
        #expect(delegate.showResetDataAlert == false)
    }

    @Test("showResetDataAlert can be toggled")
    func toggleAlert() {
        let delegate = SyncDelegate()
        delegate.showResetDataAlert = true
        #expect(delegate.showResetDataAlert == true)
        delegate.showResetDataAlert = false
        #expect(delegate.showResetDataAlert == false)
    }
}
