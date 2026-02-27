//
//  AppDatabase.swift
//  BabyTime
//
//  Database setup and schema migrations for the SQLiteData layer.
//  See SYNC.md for architecture and migration plan.
//

import Dependencies
import Foundation
import SQLiteData

// MARK: - Database Bootstrap

extension DependencyValues {
    /// Sets up the default database and (optionally) the sync engine.
    /// Call from `prepareDependencies` in the app entry point.
    mutating func bootstrapDatabase() throws {
        var configuration = Configuration()
        configuration.foreignKeysEnabled = true
        configuration.prepareDatabase { db in
            try db.attachMetadatabase()
        }
        let database = try SQLiteData.defaultDatabase(configuration: configuration)
        try Self.runMigrations(on: database)
        SwiftDataMigrator.migrateIfNeeded(to: database)
        defaultDatabase = database
    }

    /// Sets up an in-memory database for testing. No CloudKit, no file system.
    mutating func bootstrapTestDatabase() throws {
        var configuration = Configuration()
        configuration.foreignKeysEnabled = true
        let database = try DatabaseQueue(configuration: configuration)
        try Self.runMigrations(on: database)
        defaultDatabase = database
    }

    // MARK: - Migrations

    private static func runMigrations(on database: any DatabaseWriter) throws {
        var migrator = DatabaseMigrator()

        migrator.registerMigration("Create initial tables") { db in
            try #sql(
                """
                CREATE TABLE "syncBabies" (
                    "id" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE DEFAULT (uuid()),
                    "stableID" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT '',
                    "name" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT '',
                    "birthdate" TEXT NOT NULL,
                    "bedtimeHour" INTEGER NOT NULL ON CONFLICT REPLACE DEFAULT 19,
                    "bedtimeMinute" INTEGER NOT NULL ON CONFLICT REPLACE DEFAULT 0,
                    "dreamFeedEnabled" INTEGER NOT NULL ON CONFLICT REPLACE DEFAULT 0,
                    "dreamFeedHour" INTEGER NOT NULL ON CONFLICT REPLACE DEFAULT 22,
                    "dreamFeedMinute" INTEGER NOT NULL ON CONFLICT REPLACE DEFAULT 30,
                    "customFeedIntervalMinutes" INTEGER NOT NULL ON CONFLICT REPLACE DEFAULT 0,
                    "photoData" BLOB,
                    "createdAt" TEXT NOT NULL
                ) STRICT
                """
            )
            .execute(db)

            try #sql(
                """
                CREATE TABLE "syncFeedEvents" (
                    "id" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE DEFAULT (uuid()),
                    "babyID" TEXT NOT NULL REFERENCES "syncBabies"("id") ON DELETE CASCADE,
                    "startTime" TEXT NOT NULL,
                    "endTime" TEXT,
                    "feedKind" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT 'bottle',
                    "bottleSource" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT 'breastMilk',
                    "amountOz" REAL NOT NULL ON CONFLICT REPLACE DEFAULT 0,
                    "nursingSide" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT 'both',
                    "caregiverName" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT '',
                    "deviceID" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT ''
                ) STRICT
                """
            )
            .execute(db)

            try #sql(
                """
                CREATE TABLE "syncSleepEvents" (
                    "id" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE DEFAULT (uuid()),
                    "babyID" TEXT NOT NULL REFERENCES "syncBabies"("id") ON DELETE CASCADE,
                    "startTime" TEXT NOT NULL,
                    "endTime" TEXT,
                    "isNightSleep" INTEGER NOT NULL ON CONFLICT REPLACE DEFAULT 0,
                    "caregiverName" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT '',
                    "deviceID" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT ''
                ) STRICT
                """
            )
            .execute(db)

            try #sql(
                """
                CREATE TABLE "syncWakeEvents" (
                    "id" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE DEFAULT (uuid()),
                    "babyID" TEXT NOT NULL REFERENCES "syncBabies"("id") ON DELETE CASCADE,
                    "date" TEXT NOT NULL,
                    "time" TEXT NOT NULL,
                    "caregiverName" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT '',
                    "deviceID" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT ''
                ) STRICT
                """
            )
            .execute(db)
        }

        migrator.registerMigration("Create foreign key indexes") { db in
            try #sql(
                """
                CREATE INDEX IF NOT EXISTS "idx_syncFeedEvents_babyID"
                ON "syncFeedEvents"("babyID")
                """
            )
            .execute(db)

            try #sql(
                """
                CREATE INDEX IF NOT EXISTS "idx_syncSleepEvents_babyID"
                ON "syncSleepEvents"("babyID")
                """
            )
            .execute(db)

            try #sql(
                """
                CREATE INDEX IF NOT EXISTS "idx_syncWakeEvents_babyID"
                ON "syncWakeEvents"("babyID")
                """
            )
            .execute(db)
        }

        migrator.registerMigration("Add WakeEvent uniqueness + dedup") { db in
            // One-time dedup of any existing duplicates (keep earliest by rowid)
            try #sql("""
                DELETE FROM "syncWakeEvents"
                WHERE rowid NOT IN (
                    SELECT MIN(rowid) FROM "syncWakeEvents"
                    GROUP BY "babyID", "date"
                )
            """).execute(db)

            // Non-unique — CloudKit sync can't have UNIQUE constraints on synced tables.
            // Application-level dedup runs in autoCloseStaleEvents() instead.
            try #sql("""
                CREATE INDEX IF NOT EXISTS "idx_syncWakeEvents_babyID_date"
                ON "syncWakeEvents"("babyID", "date")
            """).execute(db)
        }

        migrator.registerMigration("Fix WakeEvent index uniqueness") { db in
            try #sql("""
                DROP INDEX IF EXISTS "idx_syncWakeEvents_babyID_date"
            """).execute(db)

            try #sql("""
                CREATE INDEX "idx_syncWakeEvents_babyID_date"
                ON "syncWakeEvents"("babyID", "date")
            """).execute(db)
        }

        try migrator.migrate(database)
    }
}
