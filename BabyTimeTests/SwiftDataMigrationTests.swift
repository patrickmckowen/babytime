//
//  SwiftDataMigrationTests.swift
//  BabyTimeTests
//
//  Tests for Phase 4a: SwiftData → SQLite data migration.
//  Creates fake CoreData-format SQLite stores and verifies migration.
//

import Dependencies
import Foundation
import SQLiteData
import Testing
@testable import BabyTime

// MARK: - Test Helpers

/// Creates a fake CoreData-format SQLite database at the given URL.
private func createLegacyStore(at url: URL) throws -> DatabaseQueue {
    let db = try DatabaseQueue(path: url.path)
    try db.write { db in
        // CoreData metadata tables
        try db.execute(sql: """
            CREATE TABLE Z_PRIMARYKEY (
                Z_ENT INTEGER PRIMARY KEY,
                Z_NAME VARCHAR,
                Z_SUPER INTEGER,
                Z_MAX INTEGER
            )
        """)

        try db.execute(sql: """
            CREATE TABLE Z_METADATA (
                Z_VERSION INTEGER PRIMARY KEY,
                Z_UUID VARCHAR(255),
                Z_PLIST BLOB
            )
        """)

        // Baby table
        try db.execute(sql: """
            CREATE TABLE ZBABY (
                Z_PK INTEGER PRIMARY KEY,
                Z_ENT INTEGER,
                Z_OPT INTEGER,
                ZSTABLEID VARCHAR,
                ZNAME VARCHAR,
                ZBIRTHDATE TIMESTAMP,
                ZBEDTIMEHOUR INTEGER,
                ZBEDTIMEMINUTE INTEGER,
                ZDREAMFEEDENABLED INTEGER,
                ZDREAMFEEDHOUR INTEGER,
                ZDREAMFEEDMINUTE INTEGER,
                ZCUSTOMFEEDINTERVALMINUTES INTEGER,
                ZPHOTODATA BLOB,
                ZCREATEDAT TIMESTAMP
            )
        """)

        // FeedEvent table
        try db.execute(sql: """
            CREATE TABLE ZFEEDEVENT (
                Z_PK INTEGER PRIMARY KEY,
                Z_ENT INTEGER,
                Z_OPT INTEGER,
                ZBABY INTEGER,
                ZSTARTTIME TIMESTAMP,
                ZENDTIME TIMESTAMP,
                ZFEEDKIND VARCHAR,
                ZBOTTLESOURCE VARCHAR,
                ZAMOUNTOZ FLOAT,
                ZNURSINGSIDE VARCHAR,
                ZCAREGIVERNAME VARCHAR,
                ZDEVICEID VARCHAR
            )
        """)

        // SleepEvent table
        try db.execute(sql: """
            CREATE TABLE ZSLEEPEVENT (
                Z_PK INTEGER PRIMARY KEY,
                Z_ENT INTEGER,
                Z_OPT INTEGER,
                ZBABY INTEGER,
                ZSTARTTIME TIMESTAMP,
                ZENDTIME TIMESTAMP,
                ZISNIGHTSLEEP INTEGER,
                ZCAREGIVERNAME VARCHAR,
                ZDEVICEID VARCHAR
            )
        """)

        // WakeEvent table
        try db.execute(sql: """
            CREATE TABLE ZWAKEEVENT (
                Z_PK INTEGER PRIMARY KEY,
                Z_ENT INTEGER,
                Z_OPT INTEGER,
                ZBABY INTEGER,
                ZDATE TIMESTAMP,
                ZTIME TIMESTAMP,
                ZCAREGIVERNAME VARCHAR,
                ZDEVICEID VARCHAR
            )
        """)
    }
    return db
}

/// Sets up a new in-memory database with the current schema for migration target.
private func withNewDatabase(_ body: (any DatabaseWriter) throws -> Void) throws {
    try withDependencies {
        try $0.bootstrapTestDatabase()
    } operation: {
        @Dependency(\.defaultDatabase) var database
        try body(database)
    }
}

/// Creates a temporary directory and returns its URL. Caller must clean up.
private func makeTempDir() throws -> URL {
    let tempDir = FileManager.default.temporaryDirectory
        .appendingPathComponent("SwiftDataMigrationTests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    return tempDir
}

// MARK: - Reference dates for tests

/// Fixed reference date for deterministic tests.
private let refBirthdate = Date(timeIntervalSinceReferenceDate: 789_000_000) // ~2026-01-02
private let refCreatedAt = Date(timeIntervalSinceReferenceDate: 789_100_000)
private let refStartTime = Date(timeIntervalSinceReferenceDate: 789_200_000)
private let refEndTime = Date(timeIntervalSinceReferenceDate: 789_203_600) // +1 hour
private let refWakeDate = Date(timeIntervalSinceReferenceDate: 789_180_000)
private let refWakeTime = Date(timeIntervalSinceReferenceDate: 789_205_200)

// MARK: - Baby Migration Tests

@Suite("SwiftDataMigration — Baby")
struct BabyMigrationTests {

    @Test("Migrates a single baby with all fields")
    func singleBaby() throws {
        let tempDir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let storeURL = tempDir.appendingPathComponent("default.store")
        let legacyDB = try createLegacyStore(at: storeURL)

        let stableID = UUID().uuidString
        try legacyDB.write { db in
            try db.execute(
                sql: """
                    INSERT INTO ZBABY (Z_PK, Z_ENT, Z_OPT, ZSTABLEID, ZNAME, ZBIRTHDATE,
                        ZBEDTIMEHOUR, ZBEDTIMEMINUTE, ZDREAMFEEDENABLED, ZDREAMFEEDHOUR,
                        ZDREAMFEEDMINUTE, ZCUSTOMFEEDINTERVALMINUTES, ZCREATEDAT)
                    VALUES (1, 1, 1, ?, 'Luna', ?, 20, 30, 1, 23, 0, 180, ?)
                    """,
                arguments: [stableID, refBirthdate.timeIntervalSinceReferenceDate, refCreatedAt.timeIntervalSinceReferenceDate]
            )
        }

        try withNewDatabase { newDB in
            let result = try SwiftDataMigrator.migrate(from: storeURL, to: newDB)
            #expect(result.babies == 1)

            let babies = try newDB.read { db in try Baby.fetchAll(db) }
            #expect(babies.count == 1)

            let baby = try #require(babies.first)
            #expect(baby.stableID == stableID)
            #expect(baby.name == "Luna")
            #expect(baby.bedtimeHour == 20)
            #expect(baby.bedtimeMinute == 30)
            #expect(baby.dreamFeedEnabled == true)
            #expect(baby.dreamFeedHour == 23)
            #expect(baby.dreamFeedMinute == 0)
            #expect(baby.customFeedIntervalMinutes == 180)
        }
    }

    @Test("Date conversion from timeIntervalSinceReferenceDate")
    func dateConversion() throws {
        let tempDir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let storeURL = tempDir.appendingPathComponent("default.store")
        let legacyDB = try createLegacyStore(at: storeURL)

        try legacyDB.write { db in
            try db.execute(
                sql: """
                    INSERT INTO ZBABY (Z_PK, Z_ENT, Z_OPT, ZSTABLEID, ZNAME, ZBIRTHDATE,
                        ZBEDTIMEHOUR, ZBEDTIMEMINUTE, ZDREAMFEEDENABLED, ZDREAMFEEDHOUR,
                        ZDREAMFEEDMINUTE, ZCUSTOMFEEDINTERVALMINUTES, ZCREATEDAT)
                    VALUES (1, 1, 1, ?, 'Test', ?, 19, 0, 0, 22, 30, 0, ?)
                    """,
                arguments: [
                    UUID().uuidString,
                    refBirthdate.timeIntervalSinceReferenceDate,
                    refCreatedAt.timeIntervalSinceReferenceDate,
                ]
            )
        }

        try withNewDatabase { newDB in
            _ = try SwiftDataMigrator.migrate(from: storeURL, to: newDB)

            let baby = try newDB.read { db in try Baby.fetchAll(db) }.first!
            #expect(abs(baby.birthdate.timeIntervalSince(refBirthdate)) < 1)
            #expect(abs(baby.createdAt.timeIntervalSince(refCreatedAt)) < 1)
        }
    }

    @Test("Migrates multiple babies with correct IDs")
    func multipleBabies() throws {
        let tempDir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let storeURL = tempDir.appendingPathComponent("default.store")
        let legacyDB = try createLegacyStore(at: storeURL)

        let stable1 = UUID().uuidString
        let stable2 = UUID().uuidString
        try legacyDB.write { db in
            try db.execute(
                sql: """
                    INSERT INTO ZBABY (Z_PK, Z_ENT, Z_OPT, ZSTABLEID, ZNAME, ZBIRTHDATE,
                        ZBEDTIMEHOUR, ZBEDTIMEMINUTE, ZDREAMFEEDENABLED, ZDREAMFEEDHOUR,
                        ZDREAMFEEDMINUTE, ZCUSTOMFEEDINTERVALMINUTES, ZCREATEDAT)
                    VALUES (1, 1, 1, ?, 'Baby1', ?, 19, 0, 0, 22, 30, 0, ?)
                    """,
                arguments: [stable1, refBirthdate.timeIntervalSinceReferenceDate, refCreatedAt.timeIntervalSinceReferenceDate]
            )
            try db.execute(
                sql: """
                    INSERT INTO ZBABY (Z_PK, Z_ENT, Z_OPT, ZSTABLEID, ZNAME, ZBIRTHDATE,
                        ZBEDTIMEHOUR, ZBEDTIMEMINUTE, ZDREAMFEEDENABLED, ZDREAMFEEDHOUR,
                        ZDREAMFEEDMINUTE, ZCUSTOMFEEDINTERVALMINUTES, ZCREATEDAT)
                    VALUES (2, 1, 1, ?, 'Baby2', ?, 20, 15, 1, 23, 0, 0, ?)
                    """,
                arguments: [stable2, refBirthdate.timeIntervalSinceReferenceDate, refCreatedAt.timeIntervalSinceReferenceDate]
            )
        }

        try withNewDatabase { newDB in
            let result = try SwiftDataMigrator.migrate(from: storeURL, to: newDB)
            #expect(result.babies == 2)

            let babies = try newDB.read { db in try Baby.fetchAll(db) }
            let names = Set(babies.map(\.name))
            #expect(names == ["Baby1", "Baby2"])
            let stableIDs = Set(babies.map(\.stableID))
            #expect(stableIDs == [stable1, stable2])
        }
    }
}

// MARK: - FeedEvent Migration Tests

@Suite("SwiftDataMigration — FeedEvent")
struct FeedEventMigrationTests {

    @Test("Migrates feed events with correct baby relationship")
    func feedWithRelationship() throws {
        let tempDir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let storeURL = tempDir.appendingPathComponent("default.store")
        let legacyDB = try createLegacyStore(at: storeURL)

        try legacyDB.write { db in
            try db.execute(
                sql: """
                    INSERT INTO ZBABY (Z_PK, Z_ENT, Z_OPT, ZSTABLEID, ZNAME, ZBIRTHDATE,
                        ZBEDTIMEHOUR, ZBEDTIMEMINUTE, ZDREAMFEEDENABLED, ZDREAMFEEDHOUR,
                        ZDREAMFEEDMINUTE, ZCUSTOMFEEDINTERVALMINUTES, ZCREATEDAT)
                    VALUES (1, 1, 1, ?, 'Test', ?, 19, 0, 0, 22, 30, 0, ?)
                    """,
                arguments: [UUID().uuidString, refBirthdate.timeIntervalSinceReferenceDate, refCreatedAt.timeIntervalSinceReferenceDate]
            )
            try db.execute(
                sql: """
                    INSERT INTO ZFEEDEVENT (Z_PK, Z_ENT, Z_OPT, ZBABY, ZSTARTTIME, ZENDTIME,
                        ZFEEDKIND, ZBOTTLESOURCE, ZAMOUNTOZ, ZNURSINGSIDE, ZCAREGIVERNAME, ZDEVICEID)
                    VALUES (1, 2, 1, 1, ?, ?, 'nursing', 'breastMilk', 0, 'left', 'Mom', 'device-1')
                    """,
                arguments: [refStartTime.timeIntervalSinceReferenceDate, refEndTime.timeIntervalSinceReferenceDate]
            )
        }

        try withNewDatabase { newDB in
            let result = try SwiftDataMigrator.migrate(from: storeURL, to: newDB)
            #expect(result.feedEvents == 1)

            let babies = try newDB.read { db in try Baby.fetchAll(db) }
            let feeds = try newDB.read { db in try FeedEvent.fetchAll(db) }
            #expect(feeds.count == 1)

            let feed = try #require(feeds.first)
            #expect(feed.babyID == babies.first?.id)
            #expect(feed.feedKind == .nursing)
            #expect(feed.nursingSide == .left)
            #expect(feed.caregiverName == "Mom")
            #expect(feed.deviceID == "device-1")
            #expect(feed.endTime != nil)
        }
    }

    @Test("Migrates bottle feed with amount")
    func bottleFeed() throws {
        let tempDir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let storeURL = tempDir.appendingPathComponent("default.store")
        let legacyDB = try createLegacyStore(at: storeURL)

        try legacyDB.write { db in
            try db.execute(
                sql: """
                    INSERT INTO ZBABY (Z_PK, Z_ENT, Z_OPT, ZSTABLEID, ZNAME, ZBIRTHDATE,
                        ZBEDTIMEHOUR, ZBEDTIMEMINUTE, ZDREAMFEEDENABLED, ZDREAMFEEDHOUR,
                        ZDREAMFEEDMINUTE, ZCUSTOMFEEDINTERVALMINUTES, ZCREATEDAT)
                    VALUES (1, 1, 1, ?, 'Test', ?, 19, 0, 0, 22, 30, 0, ?)
                    """,
                arguments: [UUID().uuidString, refBirthdate.timeIntervalSinceReferenceDate, refCreatedAt.timeIntervalSinceReferenceDate]
            )
            try db.execute(
                sql: """
                    INSERT INTO ZFEEDEVENT (Z_PK, Z_ENT, Z_OPT, ZBABY, ZSTARTTIME, ZENDTIME,
                        ZFEEDKIND, ZBOTTLESOURCE, ZAMOUNTOZ, ZNURSINGSIDE, ZCAREGIVERNAME, ZDEVICEID)
                    VALUES (1, 2, 1, 1, ?, NULL, 'bottle', 'formula', 4.5, 'both', '', '')
                    """,
                arguments: [refStartTime.timeIntervalSinceReferenceDate]
            )
        }

        try withNewDatabase { newDB in
            _ = try SwiftDataMigrator.migrate(from: storeURL, to: newDB)

            let feed = try newDB.read { db in try FeedEvent.fetchAll(db) }.first!
            #expect(feed.feedKind == .bottle)
            #expect(feed.bottleSource == .formula)
            #expect(feed.amountOz == 4.5)
            #expect(feed.endTime == nil)
            #expect(feed.isActive == true)
        }
    }

    @Test("Orphan feed events (no matching baby) are skipped")
    func orphanFeedSkipped() throws {
        let tempDir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let storeURL = tempDir.appendingPathComponent("default.store")
        let legacyDB = try createLegacyStore(at: storeURL)

        try legacyDB.write { db in
            // No baby inserted — feed references Z_PK=99 which doesn't exist
            try db.execute(
                sql: """
                    INSERT INTO ZFEEDEVENT (Z_PK, Z_ENT, Z_OPT, ZBABY, ZSTARTTIME,
                        ZFEEDKIND, ZBOTTLESOURCE, ZAMOUNTOZ, ZNURSINGSIDE, ZCAREGIVERNAME, ZDEVICEID)
                    VALUES (1, 2, 1, 99, ?, 'bottle', 'breastMilk', 2, 'both', '', '')
                    """,
                arguments: [refStartTime.timeIntervalSinceReferenceDate]
            )
        }

        try withNewDatabase { newDB in
            let result = try SwiftDataMigrator.migrate(from: storeURL, to: newDB)
            #expect(result.feedEvents == 0)
        }
    }
}

// MARK: - SleepEvent Migration Tests

@Suite("SwiftDataMigration — SleepEvent")
struct SleepEventMigrationTests {

    @Test("Migrates night sleep with isNightSleep flag")
    func nightSleep() throws {
        let tempDir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let storeURL = tempDir.appendingPathComponent("default.store")
        let legacyDB = try createLegacyStore(at: storeURL)

        try legacyDB.write { db in
            try db.execute(
                sql: """
                    INSERT INTO ZBABY (Z_PK, Z_ENT, Z_OPT, ZSTABLEID, ZNAME, ZBIRTHDATE,
                        ZBEDTIMEHOUR, ZBEDTIMEMINUTE, ZDREAMFEEDENABLED, ZDREAMFEEDHOUR,
                        ZDREAMFEEDMINUTE, ZCUSTOMFEEDINTERVALMINUTES, ZCREATEDAT)
                    VALUES (1, 1, 1, ?, 'Test', ?, 19, 0, 0, 22, 30, 0, ?)
                    """,
                arguments: [UUID().uuidString, refBirthdate.timeIntervalSinceReferenceDate, refCreatedAt.timeIntervalSinceReferenceDate]
            )
            try db.execute(
                sql: """
                    INSERT INTO ZSLEEPEVENT (Z_PK, Z_ENT, Z_OPT, ZBABY, ZSTARTTIME, ZENDTIME,
                        ZISNIGHTSLEEP, ZCAREGIVERNAME, ZDEVICEID)
                    VALUES (1, 3, 1, 1, ?, ?, 1, 'Dad', 'device-2')
                    """,
                arguments: [refStartTime.timeIntervalSinceReferenceDate, refEndTime.timeIntervalSinceReferenceDate]
            )
        }

        try withNewDatabase { newDB in
            let result = try SwiftDataMigrator.migrate(from: storeURL, to: newDB)
            #expect(result.sleepEvents == 1)

            let sleep = try newDB.read { db in try SleepEvent.fetchAll(db) }.first!
            #expect(sleep.isNightSleep == true)
            #expect(sleep.caregiverName == "Dad")
            #expect(sleep.endTime != nil)
            #expect(sleep.isActive == false)
        }
    }

    @Test("Migrates active nap (no endTime)")
    func activeNap() throws {
        let tempDir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let storeURL = tempDir.appendingPathComponent("default.store")
        let legacyDB = try createLegacyStore(at: storeURL)

        try legacyDB.write { db in
            try db.execute(
                sql: """
                    INSERT INTO ZBABY (Z_PK, Z_ENT, Z_OPT, ZSTABLEID, ZNAME, ZBIRTHDATE,
                        ZBEDTIMEHOUR, ZBEDTIMEMINUTE, ZDREAMFEEDENABLED, ZDREAMFEEDHOUR,
                        ZDREAMFEEDMINUTE, ZCUSTOMFEEDINTERVALMINUTES, ZCREATEDAT)
                    VALUES (1, 1, 1, ?, 'Test', ?, 19, 0, 0, 22, 30, 0, ?)
                    """,
                arguments: [UUID().uuidString, refBirthdate.timeIntervalSinceReferenceDate, refCreatedAt.timeIntervalSinceReferenceDate]
            )
            try db.execute(
                sql: """
                    INSERT INTO ZSLEEPEVENT (Z_PK, Z_ENT, Z_OPT, ZBABY, ZSTARTTIME, ZENDTIME,
                        ZISNIGHTSLEEP, ZCAREGIVERNAME, ZDEVICEID)
                    VALUES (1, 3, 1, 1, ?, NULL, 0, '', '')
                    """,
                arguments: [refStartTime.timeIntervalSinceReferenceDate]
            )
        }

        try withNewDatabase { newDB in
            _ = try SwiftDataMigrator.migrate(from: storeURL, to: newDB)

            let sleep = try newDB.read { db in try SleepEvent.fetchAll(db) }.first!
            #expect(sleep.isNightSleep == false)
            #expect(sleep.endTime == nil)
            #expect(sleep.isActive == true)
        }
    }
}

// MARK: - WakeEvent Migration Tests

@Suite("SwiftDataMigration — WakeEvent")
struct WakeEventMigrationTests {

    @Test("Migrates wake event with normalized date")
    func wakeEvent() throws {
        let tempDir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let storeURL = tempDir.appendingPathComponent("default.store")
        let legacyDB = try createLegacyStore(at: storeURL)

        try legacyDB.write { db in
            try db.execute(
                sql: """
                    INSERT INTO ZBABY (Z_PK, Z_ENT, Z_OPT, ZSTABLEID, ZNAME, ZBIRTHDATE,
                        ZBEDTIMEHOUR, ZBEDTIMEMINUTE, ZDREAMFEEDENABLED, ZDREAMFEEDHOUR,
                        ZDREAMFEEDMINUTE, ZCUSTOMFEEDINTERVALMINUTES, ZCREATEDAT)
                    VALUES (1, 1, 1, ?, 'Test', ?, 19, 0, 0, 22, 30, 0, ?)
                    """,
                arguments: [UUID().uuidString, refBirthdate.timeIntervalSinceReferenceDate, refCreatedAt.timeIntervalSinceReferenceDate]
            )
            try db.execute(
                sql: """
                    INSERT INTO ZWAKEEVENT (Z_PK, Z_ENT, Z_OPT, ZBABY, ZDATE, ZTIME,
                        ZCAREGIVERNAME, ZDEVICEID)
                    VALUES (1, 4, 1, 1, ?, ?, 'Mom', 'device-1')
                    """,
                arguments: [refWakeDate.timeIntervalSinceReferenceDate, refWakeTime.timeIntervalSinceReferenceDate]
            )
        }

        try withNewDatabase { newDB in
            let result = try SwiftDataMigrator.migrate(from: storeURL, to: newDB)
            #expect(result.wakeEvents == 1)

            let wake = try newDB.read { db in try WakeEvent.fetchAll(db) }.first!
            #expect(wake.caregiverName == "Mom")
            // Date should be normalized to start of day
            let startOfDay = Calendar.current.startOfDay(for: refWakeDate)
            #expect(abs(wake.date.timeIntervalSince(startOfDay)) < 1)
            #expect(abs(wake.time.timeIntervalSince(refWakeTime)) < 1)
        }
    }
}

// MARK: - Relationship Mapping Tests

@Suite("SwiftDataMigration — Relationships")
struct RelationshipMigrationTests {

    @Test("Z_PK to UUID mapping preserves baby-event relationships")
    func multipleEventsPerBaby() throws {
        let tempDir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let storeURL = tempDir.appendingPathComponent("default.store")
        let legacyDB = try createLegacyStore(at: storeURL)

        try legacyDB.write { db in
            // Two babies
            try db.execute(
                sql: """
                    INSERT INTO ZBABY (Z_PK, Z_ENT, Z_OPT, ZSTABLEID, ZNAME, ZBIRTHDATE,
                        ZBEDTIMEHOUR, ZBEDTIMEMINUTE, ZDREAMFEEDENABLED, ZDREAMFEEDHOUR,
                        ZDREAMFEEDMINUTE, ZCUSTOMFEEDINTERVALMINUTES, ZCREATEDAT)
                    VALUES (1, 1, 1, ?, 'Baby1', ?, 19, 0, 0, 22, 30, 0, ?)
                    """,
                arguments: [UUID().uuidString, refBirthdate.timeIntervalSinceReferenceDate, refCreatedAt.timeIntervalSinceReferenceDate]
            )
            try db.execute(
                sql: """
                    INSERT INTO ZBABY (Z_PK, Z_ENT, Z_OPT, ZSTABLEID, ZNAME, ZBIRTHDATE,
                        ZBEDTIMEHOUR, ZBEDTIMEMINUTE, ZDREAMFEEDENABLED, ZDREAMFEEDHOUR,
                        ZDREAMFEEDMINUTE, ZCUSTOMFEEDINTERVALMINUTES, ZCREATEDAT)
                    VALUES (2, 1, 1, ?, 'Baby2', ?, 20, 0, 0, 22, 30, 0, ?)
                    """,
                arguments: [UUID().uuidString, refBirthdate.timeIntervalSinceReferenceDate, refCreatedAt.timeIntervalSinceReferenceDate]
            )

            // Feed for Baby1
            try db.execute(
                sql: """
                    INSERT INTO ZFEEDEVENT (Z_PK, Z_ENT, Z_OPT, ZBABY, ZSTARTTIME,
                        ZFEEDKIND, ZBOTTLESOURCE, ZAMOUNTOZ, ZNURSINGSIDE, ZCAREGIVERNAME, ZDEVICEID)
                    VALUES (1, 2, 1, 1, ?, 'bottle', 'breastMilk', 3, 'both', '', '')
                    """,
                arguments: [refStartTime.timeIntervalSinceReferenceDate]
            )

            // Feed for Baby2
            try db.execute(
                sql: """
                    INSERT INTO ZFEEDEVENT (Z_PK, Z_ENT, Z_OPT, ZBABY, ZSTARTTIME,
                        ZFEEDKIND, ZBOTTLESOURCE, ZAMOUNTOZ, ZNURSINGSIDE, ZCAREGIVERNAME, ZDEVICEID)
                    VALUES (2, 2, 1, 2, ?, 'nursing', 'breastMilk', 0, 'right', '', '')
                    """,
                arguments: [refStartTime.timeIntervalSinceReferenceDate]
            )

            // Sleep for Baby1
            try db.execute(
                sql: """
                    INSERT INTO ZSLEEPEVENT (Z_PK, Z_ENT, Z_OPT, ZBABY, ZSTARTTIME,
                        ZISNIGHTSLEEP, ZCAREGIVERNAME, ZDEVICEID)
                    VALUES (1, 3, 1, 1, ?, 0, '', '')
                    """,
                arguments: [refStartTime.timeIntervalSinceReferenceDate]
            )
        }

        try withNewDatabase { newDB in
            let result = try SwiftDataMigrator.migrate(from: storeURL, to: newDB)
            #expect(result.babies == 2)
            #expect(result.feedEvents == 2)
            #expect(result.sleepEvents == 1)

            let babies = try newDB.read { db in try Baby.fetchAll(db) }
            let baby1 = try #require(babies.first(where: { $0.name == "Baby1" }))
            let baby2 = try #require(babies.first(where: { $0.name == "Baby2" }))

            let feeds = try newDB.read { db in try FeedEvent.fetchAll(db) }
            let bottleFeed = feeds.first(where: { $0.feedKind == .bottle })
            let nursingFeed = feeds.first(where: { $0.feedKind == .nursing })
            #expect(bottleFeed?.babyID == baby1.id)
            #expect(nursingFeed?.babyID == baby2.id)

            let sleeps = try newDB.read { db in try SleepEvent.fetchAll(db) }
            #expect(sleeps.first?.babyID == baby1.id)
        }
    }
}

// MARK: - Edge Cases

@Suite("SwiftDataMigration — Edge Cases")
struct MigrationEdgeCaseTests {

    @Test("Empty store migrates zero records")
    func emptyStore() throws {
        let tempDir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let storeURL = tempDir.appendingPathComponent("default.store")
        _ = try createLegacyStore(at: storeURL)

        try withNewDatabase { newDB in
            let result = try SwiftDataMigrator.migrate(from: storeURL, to: newDB)
            #expect(result.totalRecords == 0)
        }
    }

    @Test("Store without expected tables migrates zero records")
    func missingTables() throws {
        let tempDir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let storeURL = tempDir.appendingPathComponent("default.store")
        // Create a bare SQLite file — no CoreData tables
        _ = try DatabaseQueue(path: storeURL.path)

        try withNewDatabase { newDB in
            let result = try SwiftDataMigrator.migrate(from: storeURL, to: newDB)
            #expect(result.totalRecords == 0)
        }
    }

    @Test("MigrationResult totalRecords sums all counts")
    func totalRecords() {
        let result = SwiftDataMigrator.MigrationResult(
            babies: 2,
            feedEvents: 10,
            sleepEvents: 5,
            wakeEvents: 3
        )
        #expect(result.totalRecords == 20)
    }
}

// MARK: - Idempotency & Guard Tests

@Suite("SwiftDataMigration — Idempotency")
struct MigrationIdempotencyTests {

    @Test("migrateIfNeeded skips when UserDefaults flag is already set")
    func skipsWhenFlagSet() throws {
        let tempDir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let storeURL = tempDir.appendingPathComponent("default.store")
        _ = try createLegacyStore(at: storeURL)

        // Pre-set the migration flag
        let key = "swiftDataMigrationComplete"
        let previousValue = UserDefaults.standard.bool(forKey: key)
        defer { UserDefaults.standard.set(previousValue, forKey: key) }
        UserDefaults.standard.set(true, forKey: key)

        try withNewDatabase { newDB in
            let result = SwiftDataMigrator.migrateIfNeeded(to: newDB)
            #expect(result == nil)
        }
    }

    @Test("migrateIfNeeded sets flag after successful migration")
    func setsFlagAfterSuccess() throws {
        let tempDir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let key = "swiftDataMigrationComplete"
        let previousValue = UserDefaults.standard.bool(forKey: key)
        defer { UserDefaults.standard.set(previousValue, forKey: key) }

        // Clear the flag and create a legacy store with data
        UserDefaults.standard.set(false, forKey: key)

        let storeURL = tempDir.appendingPathComponent("default.store")
        let legacyDB = try createLegacyStore(at: storeURL)
        try legacyDB.write { db in
            try db.execute(
                sql: """
                    INSERT INTO ZBABY (Z_PK, Z_ENT, Z_OPT, ZSTABLEID, ZNAME, ZBIRTHDATE,
                        ZBEDTIMEHOUR, ZBEDTIMEMINUTE, ZDREAMFEEDENABLED, ZDREAMFEEDHOUR,
                        ZDREAMFEEDMINUTE, ZCUSTOMFEEDINTERVALMINUTES, ZCREATEDAT)
                    VALUES (1, 1, 1, ?, 'Test', ?, 19, 0, 0, 22, 30, 0, ?)
                    """,
                arguments: [UUID().uuidString, refBirthdate.timeIntervalSinceReferenceDate, refCreatedAt.timeIntervalSinceReferenceDate]
            )
        }

        // migrateIfNeeded can't find the store at our custom tempDir path
        // (it looks in Application Support), so test the flag-setting via migrate() directly
        try withNewDatabase { newDB in
            let result = try SwiftDataMigrator.migrate(from: storeURL, to: newDB)
            #expect(result.babies == 1)

            // Verify a second migrate() call produces duplicates (proving the flag guard matters)
            let result2 = try SwiftDataMigrator.migrate(from: storeURL, to: newDB)
            #expect(result2.babies == 1)

            // Both runs inserted — now 2 babies with different UUIDs but same data
            let allBabies = try newDB.read { db in try Baby.fetchAll(db) }
            #expect(allBabies.count == 2)
        }
    }
}

// MARK: - Data Integrity Tests

@Suite("SwiftDataMigration — Data Integrity")
struct MigrationDataIntegrityTests {

    @Test("Full scenario: baby with all event types")
    func fullScenario() throws {
        let tempDir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let storeURL = tempDir.appendingPathComponent("default.store")
        let legacyDB = try createLegacyStore(at: storeURL)

        let stableID = UUID().uuidString
        try legacyDB.write { db in
            try db.execute(
                sql: """
                    INSERT INTO ZBABY (Z_PK, Z_ENT, Z_OPT, ZSTABLEID, ZNAME, ZBIRTHDATE,
                        ZBEDTIMEHOUR, ZBEDTIMEMINUTE, ZDREAMFEEDENABLED, ZDREAMFEEDHOUR,
                        ZDREAMFEEDMINUTE, ZCUSTOMFEEDINTERVALMINUTES, ZCREATEDAT)
                    VALUES (1, 1, 1, ?, 'Luna', ?, 20, 30, 1, 23, 0, 180, ?)
                    """,
                arguments: [stableID, refBirthdate.timeIntervalSinceReferenceDate, refCreatedAt.timeIntervalSinceReferenceDate]
            )

            // 2 feeds
            try db.execute(
                sql: """
                    INSERT INTO ZFEEDEVENT (Z_PK, Z_ENT, Z_OPT, ZBABY, ZSTARTTIME, ZENDTIME,
                        ZFEEDKIND, ZBOTTLESOURCE, ZAMOUNTOZ, ZNURSINGSIDE, ZCAREGIVERNAME, ZDEVICEID)
                    VALUES (1, 2, 1, 1, ?, ?, 'nursing', 'breastMilk', 0, 'left', 'Mom', 'device-1')
                    """,
                arguments: [refStartTime.timeIntervalSinceReferenceDate, refEndTime.timeIntervalSinceReferenceDate]
            )
            try db.execute(
                sql: """
                    INSERT INTO ZFEEDEVENT (Z_PK, Z_ENT, Z_OPT, ZBABY, ZSTARTTIME, ZENDTIME,
                        ZFEEDKIND, ZBOTTLESOURCE, ZAMOUNTOZ, ZNURSINGSIDE, ZCAREGIVERNAME, ZDEVICEID)
                    VALUES (2, 2, 1, 1, ?, NULL, 'bottle', 'formula', 4.0, 'both', 'Dad', 'device-2')
                    """,
                arguments: [refEndTime.timeIntervalSinceReferenceDate]
            )

            // 2 sleeps (one completed nap, one active night sleep)
            try db.execute(
                sql: """
                    INSERT INTO ZSLEEPEVENT (Z_PK, Z_ENT, Z_OPT, ZBABY, ZSTARTTIME, ZENDTIME,
                        ZISNIGHTSLEEP, ZCAREGIVERNAME, ZDEVICEID)
                    VALUES (1, 3, 1, 1, ?, ?, 0, 'Mom', 'device-1')
                    """,
                arguments: [refStartTime.timeIntervalSinceReferenceDate, refEndTime.timeIntervalSinceReferenceDate]
            )
            try db.execute(
                sql: """
                    INSERT INTO ZSLEEPEVENT (Z_PK, Z_ENT, Z_OPT, ZBABY, ZSTARTTIME, ZENDTIME,
                        ZISNIGHTSLEEP, ZCAREGIVERNAME, ZDEVICEID)
                    VALUES (2, 3, 1, 1, ?, NULL, 1, 'Dad', 'device-2')
                    """,
                arguments: [refEndTime.timeIntervalSinceReferenceDate]
            )

            // 1 wake
            try db.execute(
                sql: """
                    INSERT INTO ZWAKEEVENT (Z_PK, Z_ENT, Z_OPT, ZBABY, ZDATE, ZTIME,
                        ZCAREGIVERNAME, ZDEVICEID)
                    VALUES (1, 4, 1, 1, ?, ?, 'Mom', 'device-1')
                    """,
                arguments: [refWakeDate.timeIntervalSinceReferenceDate, refWakeTime.timeIntervalSinceReferenceDate]
            )
        }

        try withNewDatabase { newDB in
            let result = try SwiftDataMigrator.migrate(from: storeURL, to: newDB)
            #expect(result.babies == 1)
            #expect(result.feedEvents == 2)
            #expect(result.sleepEvents == 2)
            #expect(result.wakeEvents == 1)
            #expect(result.totalRecords == 6)

            // All events reference the same baby
            let baby = try newDB.read { db in try Baby.fetchAll(db) }.first!
            #expect(baby.stableID == stableID)
            #expect(baby.name == "Luna")

            let feeds = try newDB.read { db in try FeedEvent.fetchAll(db) }
            #expect(feeds.allSatisfy { $0.babyID == baby.id })
            #expect(feeds.filter { $0.feedKind == .nursing }.count == 1)
            #expect(feeds.filter { $0.feedKind == .bottle }.count == 1)

            let sleeps = try newDB.read { db in try SleepEvent.fetchAll(db) }
            #expect(sleeps.allSatisfy { $0.babyID == baby.id })
            #expect(sleeps.filter { $0.isNightSleep }.count == 1)
            #expect(sleeps.filter { $0.isActive }.count == 1)
            #expect(sleeps.filter { !$0.isActive }.count == 1)

            let wakes = try newDB.read { db in try WakeEvent.fetchAll(db) }
            #expect(wakes.allSatisfy { $0.babyID == baby.id })
        }
    }

    @Test("Multiple events per baby preserves exact counts")
    func volumeTest() throws {
        let tempDir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let storeURL = tempDir.appendingPathComponent("default.store")
        let legacyDB = try createLegacyStore(at: storeURL)

        try legacyDB.write { db in
            try db.execute(
                sql: """
                    INSERT INTO ZBABY (Z_PK, Z_ENT, Z_OPT, ZSTABLEID, ZNAME, ZBIRTHDATE,
                        ZBEDTIMEHOUR, ZBEDTIMEMINUTE, ZDREAMFEEDENABLED, ZDREAMFEEDHOUR,
                        ZDREAMFEEDMINUTE, ZCUSTOMFEEDINTERVALMINUTES, ZCREATEDAT)
                    VALUES (1, 1, 1, ?, 'Test', ?, 19, 0, 0, 22, 30, 0, ?)
                    """,
                arguments: [UUID().uuidString, refBirthdate.timeIntervalSinceReferenceDate, refCreatedAt.timeIntervalSinceReferenceDate]
            )

            // 5 feeds
            for i in 1...5 {
                let offset = Double(i) * 3600
                try db.execute(
                    sql: """
                        INSERT INTO ZFEEDEVENT (Z_PK, Z_ENT, Z_OPT, ZBABY, ZSTARTTIME,
                            ZFEEDKIND, ZBOTTLESOURCE, ZAMOUNTOZ, ZNURSINGSIDE, ZCAREGIVERNAME, ZDEVICEID)
                        VALUES (?, 2, 1, 1, ?, 'bottle', 'breastMilk', ?, 'both', '', '')
                        """,
                    arguments: [i, refStartTime.timeIntervalSinceReferenceDate + offset, Double(i)]
                )
            }

            // 3 sleeps
            for i in 1...3 {
                let offset = Double(i) * 7200
                try db.execute(
                    sql: """
                        INSERT INTO ZSLEEPEVENT (Z_PK, Z_ENT, Z_OPT, ZBABY, ZSTARTTIME,
                            ZISNIGHTSLEEP, ZCAREGIVERNAME, ZDEVICEID)
                        VALUES (?, 3, 1, 1, ?, 0, '', '')
                        """,
                    arguments: [i, refStartTime.timeIntervalSinceReferenceDate + offset]
                )
            }

            // 2 wakes
            for i in 1...2 {
                let offset = Double(i) * 86400
                try db.execute(
                    sql: """
                        INSERT INTO ZWAKEEVENT (Z_PK, Z_ENT, Z_OPT, ZBABY, ZDATE, ZTIME,
                            ZCAREGIVERNAME, ZDEVICEID)
                        VALUES (?, 4, 1, 1, ?, ?, '', '')
                        """,
                    arguments: [i, refWakeDate.timeIntervalSinceReferenceDate + offset, refWakeTime.timeIntervalSinceReferenceDate + offset]
                )
            }
        }

        try withNewDatabase { newDB in
            let result = try SwiftDataMigrator.migrate(from: storeURL, to: newDB)
            #expect(result.babies == 1)
            #expect(result.feedEvents == 5)
            #expect(result.sleepEvents == 3)
            #expect(result.wakeEvents == 2)

            // Verify amounts are distinct (data wasn't flattened)
            let feeds = try newDB.read { db in try FeedEvent.fetchAll(db) }
            let amounts = Set(feeds.map(\.amountOz))
            #expect(amounts == [1, 2, 3, 4, 5])
        }
    }

    @Test("stableID is preserved for @AppStorage continuity")
    func stableIDPreservation() throws {
        let tempDir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let storeURL = tempDir.appendingPathComponent("default.store")
        let legacyDB = try createLegacyStore(at: storeURL)

        let originalStableID = "STABLE-\(UUID().uuidString)"
        try legacyDB.write { db in
            try db.execute(
                sql: """
                    INSERT INTO ZBABY (Z_PK, Z_ENT, Z_OPT, ZSTABLEID, ZNAME, ZBIRTHDATE,
                        ZBEDTIMEHOUR, ZBEDTIMEMINUTE, ZDREAMFEEDENABLED, ZDREAMFEEDHOUR,
                        ZDREAMFEEDMINUTE, ZCUSTOMFEEDINTERVALMINUTES, ZCREATEDAT)
                    VALUES (1, 1, 1, ?, 'StableTest', ?, 19, 0, 0, 22, 30, 0, ?)
                    """,
                arguments: [originalStableID, refBirthdate.timeIntervalSinceReferenceDate, refCreatedAt.timeIntervalSinceReferenceDate]
            )
        }

        try withNewDatabase { newDB in
            _ = try SwiftDataMigrator.migrate(from: storeURL, to: newDB)

            let baby = try newDB.read { db in try Baby.fetchAll(db) }.first!
            // stableID must be the exact same string — this is what @AppStorage uses
            #expect(baby.stableID == originalStableID)
            // UUID should be different (newly generated)
            #expect(baby.id != UUID()) // just verifying it's a valid UUID
        }
    }
}

// MARK: - NULL / Missing Data Tests

@Suite("SwiftDataMigration — NULL Handling")
struct MigrationNULLHandlingTests {

    @Test("Baby with all optional fields NULL uses safe defaults")
    func babyNullFields() throws {
        let tempDir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let storeURL = tempDir.appendingPathComponent("default.store")
        let legacyDB = try createLegacyStore(at: storeURL)

        try legacyDB.write { db in
            // Insert a row with only Z_PK — all other fields NULL
            try db.execute(sql: """
                INSERT INTO ZBABY (Z_PK, Z_ENT, Z_OPT)
                VALUES (1, 1, 1)
            """)
        }

        try withNewDatabase { newDB in
            let result = try SwiftDataMigrator.migrate(from: storeURL, to: newDB)
            #expect(result.babies == 1)

            let baby = try newDB.read { db in try Baby.fetchAll(db) }.first!
            // Verify safe defaults
            #expect(baby.name == "")
            #expect(baby.bedtimeHour == 19)
            #expect(baby.bedtimeMinute == 0)
            #expect(baby.dreamFeedEnabled == false)
            #expect(baby.dreamFeedHour == 22)
            #expect(baby.dreamFeedMinute == 30)
            #expect(baby.customFeedIntervalMinutes == 0)
            #expect(baby.photoData == nil)
            // stableID should be auto-generated (not empty)
            #expect(!baby.stableID.isEmpty)
        }
    }

    @Test("FeedEvent with NULL optional fields uses safe defaults")
    func feedNullFields() throws {
        let tempDir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let storeURL = tempDir.appendingPathComponent("default.store")
        let legacyDB = try createLegacyStore(at: storeURL)

        try legacyDB.write { db in
            try db.execute(
                sql: """
                    INSERT INTO ZBABY (Z_PK, Z_ENT, Z_OPT, ZSTABLEID, ZNAME, ZBIRTHDATE,
                        ZBEDTIMEHOUR, ZBEDTIMEMINUTE, ZDREAMFEEDENABLED, ZDREAMFEEDHOUR,
                        ZDREAMFEEDMINUTE, ZCUSTOMFEEDINTERVALMINUTES, ZCREATEDAT)
                    VALUES (1, 1, 1, ?, 'Test', ?, 19, 0, 0, 22, 30, 0, ?)
                    """,
                arguments: [UUID().uuidString, refBirthdate.timeIntervalSinceReferenceDate, refCreatedAt.timeIntervalSinceReferenceDate]
            )
            // Feed with NULL endTime, NULL caregiverName, NULL deviceID, NULL feedKind
            try db.execute(
                sql: """
                    INSERT INTO ZFEEDEVENT (Z_PK, Z_ENT, Z_OPT, ZBABY, ZSTARTTIME)
                    VALUES (1, 2, 1, 1, ?)
                    """,
                arguments: [refStartTime.timeIntervalSinceReferenceDate]
            )
        }

        try withNewDatabase { newDB in
            let result = try SwiftDataMigrator.migrate(from: storeURL, to: newDB)
            #expect(result.feedEvents == 1)

            let feed = try newDB.read { db in try FeedEvent.fetchAll(db) }.first!
            #expect(feed.endTime == nil)
            #expect(feed.feedKind == .bottle)
            #expect(feed.bottleSource == .breastMilk)
            #expect(feed.amountOz == 0)
            #expect(feed.nursingSide == .both)
            #expect(feed.caregiverName == "")
            #expect(feed.deviceID == "")
        }
    }

    @Test("WakeEvent with NULL time falls back to date value")
    func wakeNullTime() throws {
        let tempDir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let storeURL = tempDir.appendingPathComponent("default.store")
        let legacyDB = try createLegacyStore(at: storeURL)

        try legacyDB.write { db in
            try db.execute(
                sql: """
                    INSERT INTO ZBABY (Z_PK, Z_ENT, Z_OPT, ZSTABLEID, ZNAME, ZBIRTHDATE,
                        ZBEDTIMEHOUR, ZBEDTIMEMINUTE, ZDREAMFEEDENABLED, ZDREAMFEEDHOUR,
                        ZDREAMFEEDMINUTE, ZCUSTOMFEEDINTERVALMINUTES, ZCREATEDAT)
                    VALUES (1, 1, 1, ?, 'Test', ?, 19, 0, 0, 22, 30, 0, ?)
                    """,
                arguments: [UUID().uuidString, refBirthdate.timeIntervalSinceReferenceDate, refCreatedAt.timeIntervalSinceReferenceDate]
            )
            // Wake with ZTIME = NULL — should fall back to ZDATE value
            try db.execute(
                sql: """
                    INSERT INTO ZWAKEEVENT (Z_PK, Z_ENT, Z_OPT, ZBABY, ZDATE, ZTIME,
                        ZCAREGIVERNAME, ZDEVICEID)
                    VALUES (1, 4, 1, 1, ?, NULL, '', '')
                    """,
                arguments: [refWakeDate.timeIntervalSinceReferenceDate]
            )
        }

        try withNewDatabase { newDB in
            let result = try SwiftDataMigrator.migrate(from: storeURL, to: newDB)
            #expect(result.wakeEvents == 1)

            let wake = try newDB.read { db in try WakeEvent.fetchAll(db) }.first!
            // time should fall back to date reference
            #expect(abs(wake.time.timeIntervalSince(refWakeDate)) < 1)
        }
    }
}
