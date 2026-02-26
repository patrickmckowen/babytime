//
//  SwiftDataMigrator.swift
//  BabyTime
//
//  One-time migration from old SwiftData (CoreData) store to SQLiteData.
//  Reads the old default.store via GRDB raw SQL and inserts into new tables.
//  See SYNC.md Phase 4a for architecture context.
//

import Foundation
import GRDB
import SQLiteData

struct SwiftDataMigrator {

    struct MigrationResult: Sendable {
        let babies: Int
        let feedEvents: Int
        let sleepEvents: Int
        let wakeEvents: Int

        var totalRecords: Int { babies + feedEvents + sleepEvents + wakeEvents }
    }

    private static let migrationKey = "swiftDataMigrationComplete"

    // MARK: - Public API

    /// Returns the URL of the old SwiftData store, or nil if it doesn't exist.
    static func legacyStoreURL() -> URL? {
        guard let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else { return nil }

        let storeURL = appSupport.appendingPathComponent("default.store")
        return FileManager.default.fileExists(atPath: storeURL.path) ? storeURL : nil
    }

    /// Runs the one-time migration if needed. Idempotent via UserDefaults flag.
    /// Does not throw — failures are logged and retried next launch.
    @discardableResult
    static func migrateIfNeeded(to database: any DatabaseWriter) -> MigrationResult? {
        guard !UserDefaults.standard.bool(forKey: migrationKey) else { return nil }

        guard let storeURL = legacyStoreURL() else {
            // New install — no old data to migrate
            UserDefaults.standard.set(true, forKey: migrationKey)
            return nil
        }

        do {
            let result = try migrate(from: storeURL, to: database)
            UserDefaults.standard.set(true, forKey: migrationKey)
            return result
        } catch {
            print("[SwiftDataMigrator] Migration failed, will retry next launch: \(error)")
            return nil
        }
    }

    // MARK: - Core Migration (throws — used directly by tests)

    /// Reads the old CoreData store and inserts all data into the new database.
    /// All inserts happen in a single transaction — all-or-nothing.
    static func migrate(
        from storeURL: URL,
        to database: any DatabaseWriter
    ) throws -> MigrationResult {
        var config = Configuration()
        config.readonly = true
        let legacyDB = try DatabaseQueue(path: storeURL.path, configuration: config)

        // Read all old data
        let (babies, babyPKMap) = try legacyDB.read { db in
            try readBabies(from: db, storeURL: storeURL)
        }
        let feedEvents = try legacyDB.read { db in
            try readFeedEvents(from: db, babyPKMap: babyPKMap)
        }
        let sleepEvents = try legacyDB.read { db in
            try readSleepEvents(from: db, babyPKMap: babyPKMap)
        }
        let wakeEvents = try legacyDB.read { db in
            try readWakeEvents(from: db, babyPKMap: babyPKMap)
        }

        // Write everything in a single transaction
        try database.write { db in
            for baby in babies {
                try Baby.insert { baby }.execute(db)
            }
            for event in feedEvents {
                try FeedEvent.insert { event }.execute(db)
            }
            for event in sleepEvents {
                try SleepEvent.insert { event }.execute(db)
            }
            for event in wakeEvents {
                try WakeEvent.insert { event }.execute(db)
            }
        }

        return MigrationResult(
            babies: babies.count,
            feedEvents: feedEvents.count,
            sleepEvents: sleepEvents.count,
            wakeEvents: wakeEvents.count
        )
    }

    // MARK: - Row Readers

    /// CoreData column mapping for Baby:
    /// Z_PK → id (new UUID), ZSTABLEID → stableID, ZNAME → name,
    /// ZBIRTHDATE → birthdate (Double → Date), ZBEDTIMEHOUR/MINUTE → bedtime,
    /// ZDREAMFEED* → dreamFeed*, ZPHOTODATA → photoData, ZCREATEDAT → createdAt
    private static func readBabies(
        from db: Database,
        storeURL: URL
    ) throws -> ([Baby], [Int64: UUID]) {
        guard try tableExists("ZBABY", in: db) else { return ([], [:]) }

        let rows = try Row.fetchAll(db, sql: "SELECT * FROM ZBABY")
        var babies: [Baby] = []
        var pkMap: [Int64: UUID] = [:]

        for row in rows {
            let zpk: Int64 = row["Z_PK"]
            let newID = UUID()
            pkMap[zpk] = newID

            let stableID: String? = row["ZSTABLEID"]
            let name: String? = row["ZNAME"]
            let birthdateRef: Double? = row["ZBIRTHDATE"]
            let bedtimeHour: Int? = row["ZBEDTIMEHOUR"]
            let bedtimeMinute: Int? = row["ZBEDTIMEMINUTE"]
            let dreamFeedEnabled: Int? = row["ZDREAMFEEDENABLED"]
            let dreamFeedHour: Int? = row["ZDREAMFEEDHOUR"]
            let dreamFeedMinute: Int? = row["ZDREAMFEEDMINUTE"]
            let customFeedInterval: Int? = row["ZCUSTOMFEEDINTERVALMINUTES"]
            let createdAtRef: Double? = row["ZCREATEDAT"]

            let photoData = readPhotoData(from: row, storeURL: storeURL, zpk: zpk)

            babies.append(Baby(
                id: newID,
                stableID: stableID ?? UUID().uuidString,
                name: name ?? "",
                birthdate: Date(timeIntervalSinceReferenceDate: birthdateRef ?? 0),
                bedtimeHour: bedtimeHour ?? 19,
                bedtimeMinute: bedtimeMinute ?? 0,
                dreamFeedEnabled: (dreamFeedEnabled ?? 0) != 0,
                dreamFeedHour: dreamFeedHour ?? 22,
                dreamFeedMinute: dreamFeedMinute ?? 30,
                customFeedIntervalMinutes: customFeedInterval ?? 0,
                photoData: photoData,
                createdAt: Date(
                    timeIntervalSinceReferenceDate: createdAtRef ?? Date().timeIntervalSinceReferenceDate
                )
            ))
        }

        return (babies, pkMap)
    }

    /// CoreData column mapping for FeedEvent:
    /// ZBABY → babyID (via Z_PK map), ZSTARTTIME/ZENDTIME → dates,
    /// ZFEEDKIND/ZBOTTLESOURCE/ZNURSINGSIDE → enum raw values, ZAMOUNTOZ → amountOz
    private static func readFeedEvents(
        from db: Database,
        babyPKMap: [Int64: UUID]
    ) throws -> [FeedEvent] {
        guard try tableExists("ZFEEDEVENT", in: db) else { return [] }

        let rows = try Row.fetchAll(db, sql: "SELECT * FROM ZFEEDEVENT")
        return rows.compactMap { row -> FeedEvent? in
            guard let babyPK: Int64 = row["ZBABY"],
                  let babyID = babyPKMap[babyPK] else { return nil }

            let startRef: Double? = row["ZSTARTTIME"]
            let endRef: Double? = row["ZENDTIME"]
            let feedKindStr: String? = row["ZFEEDKIND"]
            let bottleSourceStr: String? = row["ZBOTTLESOURCE"]
            let nursingSideStr: String? = row["ZNURSINGSIDE"]
            let amountOz: Double? = row["ZAMOUNTOZ"]
            let caregiverName: String? = row["ZCAREGIVERNAME"]
            let deviceID: String? = row["ZDEVICEID"]

            return FeedEvent(
                id: UUID(),
                babyID: babyID,
                startTime: Date(
                    timeIntervalSinceReferenceDate: startRef ?? Date().timeIntervalSinceReferenceDate
                ),
                endTime: endRef.map { Date(timeIntervalSinceReferenceDate: $0) },
                feedKind: FeedKind(rawValue: feedKindStr ?? "bottle") ?? .bottle,
                bottleSource: BottleSource(rawValue: bottleSourceStr ?? "breastMilk") ?? .breastMilk,
                amountOz: amountOz ?? 0,
                nursingSide: NursingSide(rawValue: nursingSideStr ?? "both") ?? .both,
                caregiverName: caregiverName ?? "",
                deviceID: deviceID ?? ""
            )
        }
    }

    /// CoreData column mapping for SleepEvent:
    /// ZBABY → babyID, ZSTARTTIME/ZENDTIME → dates, ZISNIGHTSLEEP → Bool (Int 0/1)
    private static func readSleepEvents(
        from db: Database,
        babyPKMap: [Int64: UUID]
    ) throws -> [SleepEvent] {
        guard try tableExists("ZSLEEPEVENT", in: db) else { return [] }

        let rows = try Row.fetchAll(db, sql: "SELECT * FROM ZSLEEPEVENT")
        return rows.compactMap { row -> SleepEvent? in
            guard let babyPK: Int64 = row["ZBABY"],
                  let babyID = babyPKMap[babyPK] else { return nil }

            let startRef: Double? = row["ZSTARTTIME"]
            let endRef: Double? = row["ZENDTIME"]
            let isNightSleep: Int? = row["ZISNIGHTSLEEP"]
            let caregiverName: String? = row["ZCAREGIVERNAME"]
            let deviceID: String? = row["ZDEVICEID"]

            return SleepEvent(
                id: UUID(),
                babyID: babyID,
                startTime: Date(
                    timeIntervalSinceReferenceDate: startRef ?? Date().timeIntervalSinceReferenceDate
                ),
                endTime: endRef.map { Date(timeIntervalSinceReferenceDate: $0) },
                isNightSleep: (isNightSleep ?? 0) != 0,
                caregiverName: caregiverName ?? "",
                deviceID: deviceID ?? ""
            )
        }
    }

    /// CoreData column mapping for WakeEvent:
    /// ZBABY → babyID, ZDATE → date (normalized to start of day), ZTIME → time
    private static func readWakeEvents(
        from db: Database,
        babyPKMap: [Int64: UUID]
    ) throws -> [WakeEvent] {
        guard try tableExists("ZWAKEEVENT", in: db) else { return [] }

        let rows = try Row.fetchAll(db, sql: "SELECT * FROM ZWAKEEVENT")
        return rows.compactMap { row -> WakeEvent? in
            guard let babyPK: Int64 = row["ZBABY"],
                  let babyID = babyPKMap[babyPK] else { return nil }

            let dateRef: Double? = row["ZDATE"]
            let timeRef: Double? = row["ZTIME"]
            let caregiverName: String? = row["ZCAREGIVERNAME"]
            let deviceID: String? = row["ZDEVICEID"]

            let dateValue = Date(
                timeIntervalSinceReferenceDate: dateRef ?? Date().timeIntervalSinceReferenceDate
            )

            return WakeEvent(
                id: UUID(),
                babyID: babyID,
                date: Calendar.current.startOfDay(for: dateValue),
                time: Date(
                    timeIntervalSinceReferenceDate: timeRef ?? dateRef ?? Date().timeIntervalSinceReferenceDate
                ),
                caregiverName: caregiverName ?? "",
                deviceID: deviceID ?? ""
            )
        }
    }

    // MARK: - Helpers

    private static func tableExists(_ name: String, in db: Database) throws -> Bool {
        let count = try Int.fetchOne(
            db,
            sql: "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name=?",
            arguments: [name]
        )
        return (count ?? 0) > 0
    }

    /// Reads photo data — tries inline blob first, falls back to external storage directory.
    private static func readPhotoData(from row: Row, storeURL: URL, zpk: Int64) -> Data? {
        // Try inline blob (CoreData stores small blobs directly in the column)
        if let data: Data = row["ZPHOTODATA"], data.count > 100 {
            return data
        }

        // Try external storage directory (CoreData @Attribute(.externalStorage))
        let externalDir = storeURL
            .deletingLastPathComponent()
            .appendingPathComponent(".default.store_external_data")
            .appendingPathComponent("ZBABY")
            .appendingPathComponent("ZPHOTODATA")

        guard FileManager.default.fileExists(atPath: externalDir.path),
              let files = try? FileManager.default.contentsOfDirectory(
                  at: externalDir,
                  includingPropertiesForKeys: nil
              ),
              !files.isEmpty else { return nil }

        // Best-effort: match by Z_PK order (1-based)
        let sorted = files.sorted { $0.lastPathComponent < $1.lastPathComponent }
        let index = Int(zpk) - 1
        guard index >= 0, index < sorted.count else { return nil }

        return try? Data(contentsOf: sorted[index])
    }
}
