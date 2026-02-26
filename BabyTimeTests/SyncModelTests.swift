//
//  SyncModelTests.swift
//  BabyTimeTests
//
//  Phase 1 tests: verify SQLiteData schema, CRUD operations,
//  and foreign key relationships for the @Table models.
//

import Dependencies
import Foundation
import SQLiteData
import Testing
@testable import BabyTime

// MARK: - Test Helpers

/// Sets up an in-memory database with the full schema for testing.
private func withDatabase(_ body: (any DatabaseWriter) throws -> Void) throws {
    try withDependencies {
        try $0.bootstrapTestDatabase()
    } operation: {
        @Dependency(\.defaultDatabase) var database
        try body(database)
    }
}

// MARK: - Schema Tests

@Suite("SyncModels — Schema Setup")
struct SyncSchemaTests {

    @Test("Database creates all tables")
    func tablesExist() throws {
        try withDatabase { db in
            let tables = try db.read { db in
                try String.fetchAll(
                    db,
                    sql: "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name"
                )
            }
            #expect(tables.contains("syncBabies"))
            #expect(tables.contains("syncFeedEvents"))
            #expect(tables.contains("syncSleepEvents"))
            #expect(tables.contains("syncWakeEvents"))
        }
    }

    @Test("Foreign key indexes are created")
    func indexesExist() throws {
        try withDatabase { db in
            let indexes = try db.read { db in
                try String.fetchAll(
                    db,
                    sql: "SELECT name FROM sqlite_master WHERE type='index' AND name LIKE 'idx_%' ORDER BY name"
                )
            }
            #expect(indexes.contains("idx_syncFeedEvents_babyID"))
            #expect(indexes.contains("idx_syncSleepEvents_babyID"))
            #expect(indexes.contains("idx_syncWakeEvents_babyID"))
        }
    }
}

// MARK: - CRUD Tests

@Suite("SyncModels — Baby CRUD")
struct BabyCRUDTests {

    @Test("Insert and fetch a baby")
    func insertAndFetch() throws {
        try withDatabase { db in
            let babyID = UUID()
            let baby = Baby(
                id: babyID,
                stableID: UUID().uuidString,
                name: "Test Baby",
                birthdate: Date(),
                createdAt: Date()
            )
            try db.write { db in
                try Baby.insert { baby }.execute(db)
            }
            let fetched = try db.read { db in
                try Baby.fetchAll(db)
            }
            #expect(fetched.count == 1)
            #expect(fetched.first?.id == babyID)
            #expect(fetched.first?.name == "Test Baby")
            #expect(fetched.first?.bedtimeHour == 19)
            #expect(fetched.first?.dreamFeedEnabled == false)
        }
    }

    @Test("Update a baby")
    func update() throws {
        try withDatabase { db in
            let baby = Baby(
                id: UUID(),
                stableID: UUID().uuidString,
                name: "Original",
                birthdate: Date(),
                createdAt: Date()
            )
            try db.write { db in
                try Baby.insert { baby }.execute(db)
                try Baby.find(baby.id)
                    .update { $0.name = "Updated" }
                    .execute(db)
            }
            let fetched = try db.read { db in
                try Baby.find(baby.id).fetchOne(db)
            }
            #expect(fetched?.name == "Updated")
        }
    }

    @Test("Delete a baby")
    func delete() throws {
        try withDatabase { db in
            let baby = Baby(
                id: UUID(),
                stableID: UUID().uuidString,
                name: "ToDelete",
                birthdate: Date(),
                createdAt: Date()
            )
            try db.write { db in
                try Baby.insert { baby }.execute(db)
                try Baby.find(baby.id).delete().execute(db)
            }
            let count = try db.read { db in
                try Baby.fetchCount(db)
            }
            #expect(count == 0)
        }
    }
}

// MARK: - FeedEvent CRUD

@Suite("SyncModels — FeedEvent CRUD")
struct FeedEventCRUDTests {

    @Test("Insert feed event with foreign key")
    func insertWithFK() throws {
        try withDatabase { db in
            let babyID = UUID()
            let baby = Baby(
                id: babyID,
                stableID: UUID().uuidString,
                name: "Test",
                birthdate: Date(),
                createdAt: Date()
            )
            let feedID = UUID()
            let feed = FeedEvent(
                id: feedID,
                babyID: babyID,
                startTime: Date(),
                feedKind: .nursing,
                nursingSide: .left,
                caregiverName: "Mom",
                deviceID: "device-1"
            )
            try db.write { db in
                try Baby.insert { baby }.execute(db)
                try FeedEvent.insert { feed }.execute(db)
            }
            let fetched = try db.read { db in
                try FeedEvent.fetchAll(db)
            }
            #expect(fetched.count == 1)
            #expect(fetched.first?.feedKind == .nursing)
            #expect(fetched.first?.nursingSide == .left)
            #expect(fetched.first?.caregiverName == "Mom")
            #expect(fetched.first?.isActive == true)
        }
    }

    @Test("Feed event with endTime is not active")
    func completedFeed() throws {
        try withDatabase { db in
            let babyID = UUID()
            let baby = Baby(
                id: babyID,
                stableID: UUID().uuidString,
                name: "Test",
                birthdate: Date(),
                createdAt: Date()
            )
            let feed = FeedEvent(
                id: UUID(),
                babyID: babyID,
                startTime: Date().addingTimeInterval(-600),
                endTime: Date(),
                feedKind: .bottle,
                amountOz: 4.0
            )
            try db.write { db in
                try Baby.insert { baby }.execute(db)
                try FeedEvent.insert { feed }.execute(db)
            }
            let fetched = try db.read { db in
                try FeedEvent.fetchAll(db)
            }
            #expect(fetched.first?.isActive == false)
            #expect(fetched.first?.amountOz == 4.0)
        }
    }
}

// MARK: - SleepEvent CRUD

@Suite("SyncModels — SleepEvent CRUD")
struct SleepEventCRUDTests {

    @Test("Insert sleep event")
    func insert() throws {
        try withDatabase { db in
            let babyID = UUID()
            let baby = Baby(
                id: babyID,
                stableID: UUID().uuidString,
                name: "Test",
                birthdate: Date(),
                createdAt: Date()
            )
            let sleep = SleepEvent(
                id: UUID(),
                babyID: babyID,
                startTime: Date(),
                isNightSleep: true,
                caregiverName: "Dad",
                deviceID: "device-2"
            )
            try db.write { db in
                try Baby.insert { baby }.execute(db)
                try SleepEvent.insert { sleep }.execute(db)
            }
            let fetched = try db.read { db in
                try SleepEvent.fetchAll(db)
            }
            #expect(fetched.count == 1)
            #expect(fetched.first?.isNightSleep == true)
            #expect(fetched.first?.isActive == true)
            #expect(fetched.first?.caregiverName == "Dad")
        }
    }
}

// MARK: - WakeEvent CRUD

@Suite("SyncModels — WakeEvent CRUD")
struct WakeEventCRUDTests {

    @Test("Insert wake event")
    func insert() throws {
        try withDatabase { db in
            let babyID = UUID()
            let baby = Baby(
                id: babyID,
                stableID: UUID().uuidString,
                name: "Test",
                birthdate: Date(),
                createdAt: Date()
            )
            let now = Date()
            let wake = WakeEvent(
                id: UUID(),
                babyID: babyID,
                date: Calendar.current.startOfDay(for: now),
                time: now
            )
            try db.write { db in
                try Baby.insert { baby }.execute(db)
                try WakeEvent.insert { wake }.execute(db)
            }
            let fetched = try db.read { db in
                try WakeEvent.fetchAll(db)
            }
            #expect(fetched.count == 1)
            #expect(fetched.first?.babyID == babyID)
        }
    }
}

// MARK: - Foreign Key Cascade Tests

@Suite("SyncModels — Foreign Key Cascades")
struct SyncForeignKeyCascadeTests {

    @Test("Deleting a baby cascades to feed events")
    func cascadeDeleteFeeds() throws {
        try withDatabase { db in
            let babyID = UUID()
            let baby = Baby(
                id: babyID,
                stableID: UUID().uuidString,
                name: "Test",
                birthdate: Date(),
                createdAt: Date()
            )
            let feed = FeedEvent(
                id: UUID(),
                babyID: babyID,
                startTime: Date(),
                feedKind: .bottle,
                amountOz: 3.0
            )
            try db.write { db in
                try Baby.insert { baby }.execute(db)
                try FeedEvent.insert { feed }.execute(db)
            }
            // Verify event exists
            var feedCount = try db.read { db in try FeedEvent.fetchCount(db) }
            #expect(feedCount == 1)

            // Delete baby — should cascade
            try db.write { db in
                try Baby.find(babyID).delete().execute(db)
            }
            feedCount = try db.read { db in try FeedEvent.fetchCount(db) }
            #expect(feedCount == 0)
        }
    }

    @Test("Deleting a baby cascades to sleep and wake events")
    func cascadeDeleteAll() throws {
        try withDatabase { db in
            let babyID = UUID()
            let baby = Baby(
                id: babyID,
                stableID: UUID().uuidString,
                name: "Test",
                birthdate: Date(),
                createdAt: Date()
            )
            try db.write { db in
                try Baby.insert { baby }.execute(db)
                try SleepEvent.insert {
                    SleepEvent(id: UUID(), babyID: babyID, startTime: Date())
                }.execute(db)
                try WakeEvent.insert {
                    WakeEvent(
                        id: UUID(),
                        babyID: babyID,
                        date: Calendar.current.startOfDay(for: Date()),
                        time: Date()
                    )
                }.execute(db)
            }

            // Delete baby
            try db.write { db in
                try Baby.find(babyID).delete().execute(db)
            }

            let sleepCount = try db.read { db in try SleepEvent.fetchCount(db) }
            let wakeCount = try db.read { db in try WakeEvent.fetchCount(db) }
            #expect(sleepCount == 0)
            #expect(wakeCount == 0)
        }
    }

    @Test("Cannot insert event with non-existent baby ID")
    func fkViolation() throws {
        try withDatabase { db in
            let orphanFeed = FeedEvent(
                id: UUID(),
                babyID: UUID(), // No matching baby
                startTime: Date()
            )
            #expect(throws: (any Error).self) {
                try db.write { db in
                    try FeedEvent.insert { orphanFeed }.execute(db)
                }
            }
        }
    }
}

// MARK: - Enum Storage Tests

@Suite("SyncModels — Enum Storage")
struct SyncEnumStorageTests {

    @Test("FeedKind round-trips correctly")
    func feedKindRoundTrip() throws {
        try withDatabase { db in
            let babyID = UUID()
            try db.write { db in
                try Baby.insert {
                    Baby(
                        id: babyID,
                        stableID: UUID().uuidString,
                        name: "Test",
                        birthdate: Date(),
                        createdAt: Date()
                    )
                }.execute(db)

                for kind in FeedKind.allCases {
                    try FeedEvent.insert {
                        FeedEvent(
                            id: UUID(),
                            babyID: babyID,
                            startTime: Date(),
                            feedKind: kind
                        )
                    }.execute(db)
                }
            }
            let events = try db.read { db in
                try FeedEvent.fetchAll(db)
            }
            let kinds = Set(events.map(\.feedKind))
            #expect(kinds == Set(FeedKind.allCases))
        }
    }

    @Test("NursingSide round-trips correctly")
    func nursingSideRoundTrip() throws {
        try withDatabase { db in
            let babyID = UUID()
            try db.write { db in
                try Baby.insert {
                    Baby(
                        id: babyID,
                        stableID: UUID().uuidString,
                        name: "Test",
                        birthdate: Date(),
                        createdAt: Date()
                    )
                }.execute(db)

                for side in NursingSide.allCases {
                    try FeedEvent.insert {
                        FeedEvent(
                            id: UUID(),
                            babyID: babyID,
                            startTime: Date(),
                            nursingSide: side
                        )
                    }.execute(db)
                }
            }
            let events = try db.read { db in
                try FeedEvent.fetchAll(db)
            }
            let sides = Set(events.map(\.nursingSide))
            #expect(sides == Set(NursingSide.allCases))
        }
    }
}
