# SYNC.md — Multi-Device Sync Architecture

> This document is the source of truth for BabyTime's multi-device sync
> implementation. Read it before touching any sync-related code. Update it
> when you make architectural decisions.

## Strategy

BabyTime uses [SQLiteData](https://github.com/pointfreeco/sqlite-data)
(by PointFree) for persistence and multi-device sync. SQLiteData is built
on SQLite + GRDB and integrates with CloudKit for:

1. **Private sync** — one user's data syncs across their own devices
   (same iCloud account)
2. **Sharing** — a caregiver shares a Baby with another caregiver via
   CKShare (different iCloud accounts)

SwiftData was evaluated and rejected because it does not support CloudKit
sharing between different iCloud accounts.

## Migration Approach

The migration from SwiftData to SQLiteData is phased. Phases 1-2 are
complete: the old SwiftData `@Model` classes have been removed and the
`@Table` structs are now the canonical types (`Baby`, `FeedEvent`,
`SleepEvent`, `WakeEvent`). The SQLite tables retain the `sync` prefix
(e.g. `syncBabies`) for future CloudKit compatibility.

## Schema

All SQLiteData models are `@Table` structs (value types). Relationships
are modeled with foreign key columns, not object references.

### Tables

```
Baby  (table: syncBabies)
├── id: UUID (primary key)
├── stableID: String (for @AppStorage baby selection)
├── name: String
├── birthdate: Date
├── bedtimeHour: Int
├── bedtimeMinute: Int
├── dreamFeedEnabled: Bool
├── dreamFeedHour: Int
├── dreamFeedMinute: Int
├── customFeedIntervalMinutes: Int
├── photoData: Data? (@Column(.externalData) → CKAsset)
└── createdAt: Date

FeedEvent  (table: syncFeedEvents)
├── id: UUID (primary key)
├── babyID: UUID (foreign key → Baby.id)
├── startTime: Date
├── endTime: Date?
├── feedKind: FeedKind (.bottle | .nursing)
├── bottleSource: BottleSource (.breastMilk | .formula)
├── amountOz: Double
├── nursingSide: NursingSide (.left | .right | .both)
├── caregiverName: String
└── deviceID: String

SleepEvent  (table: syncSleepEvents)
├── id: UUID (primary key)
├── babyID: UUID (foreign key → Baby.id)
├── startTime: Date
├── endTime: Date?
├── isNightSleep: Bool
├── caregiverName: String
└── deviceID: String

WakeEvent  (table: syncWakeEvents)
├── id: UUID (primary key)
├── babyID: UUID (foreign key → Baby.id)
├── date: Date (start of day — one per baby per day)
├── time: Date (actual wake time)
├── caregiverName: String
└── deviceID: String
```

### Relationships

```
Baby 1──* FeedEvent   (via babyID, cascade delete)
Baby 1──* SleepEvent  (via babyID, cascade delete)
Baby 1──* WakeEvent   (via babyID, cascade delete)
```

### Enums

SQLiteData supports `RawRepresentable` enums directly — no String
intermediary needed.

- `FeedKind: String` — `bottle`, `nursing`
- `BottleSource: String` — `breastMilk`, `formula`
- `NursingSide: String` — `left`, `right`, `both`

## Multi-Writer Identity

Every event is stamped at creation with:
- `caregiverName` — display name from `DeviceIdentity.caregiverName`
- `deviceID` — stable UUID from `DeviceIdentity.deviceID`

These fields are **never modified after creation**. Each device has its
own identity stored in UserDefaults (never synced).

## Conflict Resolution

### Detection (DayEngine)
DayEngine detects conflicts when building a `DaySnapshot`:
- Multiple active feeds → `SyncConflict.multipleActiveFeeds`
- Multiple active naps → `SyncConflict.multipleActiveSleeps`

### Auto-Resolution (ActivityManager)
On every `refresh()`, ActivityManager resolves conflicts:
- **Multiple active nursing events** → keep earliest, close others
- **Multiple active naps** → keep earliest, close others
- **Stale night sleeps (>48 hours)** → auto-close with 8-hour duration

### Resolution Principle
**Earliest event wins.** Deterministic across devices regardless of
sync order.

## CloudKit Architecture

### Share Model
- **Share root:** Baby record
- **Cascading:** All events with matching `babyID` share automatically
- **Permissions:** Read-write for all participants

### Sharing Flow
```
Mom creates Baby → Baby is in Mom's private zone
Mom taps "Share" → SyncEngine creates CKShare
  → UICloudSharingController presents invite
  → Mom sends invite via iMessage/email
Dad accepts → SyncEngine discovers shared zone
  → Baby + all events sync to Dad's device
```

## Active Event Discovery

`syncActiveEvents()` scans for active events (endTime == nil) only when
the local reference is nil. This prevents overwriting a stopped-but-not-
yet-saved event.

**Critical rule:** Only scan when reference `== nil`. Never overwrite a
non-nil reference with a sync discovery.

## CloudKit Private Sync (Phase 5)

### SyncEngine Initialization
SyncEngine is created in `BabyTimeApp.init()` **after** `bootstrapDatabase()`,
keeping the database bootstrap signature unchanged. All four tables are passed
via `tables:` (not `privateTables:`) so they remain shareable for Phase 6.

```swift
$0.defaultSyncEngine = try! SyncEngine(
    for: $0.defaultDatabase,
    tables: Baby.self, FeedEvent.self, SleepEvent.self, WakeEvent.self,
    containerIdentifier: "iCloud.com.patrickmckowen.BabyTime",
    delegate: delegate
)
```

Tests use in-memory `DatabaseQueue` with no SyncEngine — no test breakage.

### SyncDelegate (Account Changes)
`SyncDelegate` implements `SyncEngineDelegate` and shows an alert on
`.signOut` / `.switchAccounts`. The user can keep local data or call
`syncEngine.deleteLocalData()` to reset.

### WakeEvent Dedup (Application-Level)
SQLiteData's SyncEngine does not allow UNIQUE constraints on synchronized
tables — CloudKit sync can produce temporary duplicates during conflict
resolution. Migration "Add WakeEvent composite index + dedup" adds a
non-unique composite index `(babyID, date)` for query performance and
deduplicates existing rows. Ongoing dedup runs in `autoCloseStaleEvents()`
on every `refresh()` — keeps earliest WakeEvent per baby/date, deletes
the rest. The existing query-then-upsert pattern in `setWakeTime()` is
preserved.

### autoCloseStaleEvents — Multi-Device Filter
Duplicate-closing for active nursings and naps now filters by
`DeviceIdentity.deviceID` so Device A cannot close Device B's legitimate
active event. **Stale night sleep closure (>48h) remains global** — a
48-hour-old event is genuinely stale regardless of origin.

### Real-Time Refresh (DatabaseRegionObservation)
`ActivityManager` observes all four sync tables via GRDB's
`DatabaseRegionObservation`. When CloudKit pushes changes and SQLiteData
writes them locally, the observer triggers `loadBabies()` + `refresh()`.
The existing `scenePhase == .active` handler stays as a safety net.

## WakeEvent Upsert Pattern

One WakeEvent per baby per day. Query for existing before creating.
Last-write-wins is acceptable (wake time is the same either way).

## Testing

- Use in-memory `DatabaseQueue()` — no file system, no CloudKit
- Test command: `xcodebuild test -only-testing:BabyTimeTests
  -parallel-testing-enabled NO -skipMacroValidation`
- `-skipMacroValidation` is required — the project uses SPM macro packages
  (StructuredQueries, Perception) that won't compile without it
- DayEngine tests are pure-functional and don't touch the database
- 133 tests across 31 suites, runs in <2 seconds

## Migration State

| Phase | Status | Notes |
|---|---|---|
| 1. Foundation (package, models, DB setup) | **Complete** | SQLiteData + StructuredQueries |
| 2. ActivityManager rewrite | **Complete** | ModelContext → DatabaseWriter, all queries use StructuredQueries |
| 3. View updates | **Complete** | SwiftData imports removed, bindings use ActivityManager |
| 4. Test migration | **Complete** | 109 tests across 22 suites passing |
| 4a. SwiftData → SQLite data migration | **Complete** | One-time first-launch migration via GRDB raw SQL; idempotent via UserDefaults flag |
| 5. CloudKit private sync | **Complete** | SyncEngine init, SyncDelegate, DatabaseRegionObservation, WakeEvent unique constraint, autoClose deviceID filter |
| 6. CloudKit sharing (CKShare) | Not started | Depends on Phase 5 |
| 7. Polish (migration, cleanup, sync UI) | Not started | Depends on Phase 6 |

## Files Involved

### Database layer
- `BabyTime/Database/Models.swift` — `@Table` structs (Baby, FeedEvent, SleepEvent, WakeEvent)
- `BabyTime/Database/AppDatabase.swift` — database setup + DependencyValues extensions
- `BabyTime/Database/SyncDelegate.swift` — SyncEngineDelegate for iCloud account changes
- `BabyTime/Database/SwiftDataMigrator.swift` — one-time migration from old SwiftData (CoreData) store
- `BabyTimeTests/SyncModelTests.swift` — schema verification and CRUD tests
- `BabyTimeTests/SwiftDataMigrationTests.swift` — migration logic tests

### Application layer
- `BabyTime/Models/ActivityManager.swift` — all persistence via `DatabaseWriter`
- `BabyTime/BabyTimeApp.swift` — `prepareDependencies` bootstrap

### Pure logic (no database dependency)
- `BabyTime/Engine/DayEngine.swift` — pure functions
- `BabyTime/Engine/AgeTable.swift` — pure data
- `BabyTime/Models/DeviceIdentity.swift` — UserDefaults only
- `BabyTime/Models/DayState.swift` — pure value types

## StructuredQueries API Reference

The project uses [StructuredQueries](https://github.com/pointfreeco/swift-structured-queries)
(v0.31.0) for type-safe SQL. Key patterns an agent must follow:

### Filtering (`.where`)
```swift
// Equality — use .eq(), NOT ==  (== is intentionally unavailable)
.where { $0.babyID.eq(#bind(babyID)) }

// Nil checks — use .is(nil) / .isNot(nil), NOT == nil
.where { $0.endTime.is(nil) }
.where { $0.endTime.isNot(nil) }

// Comparison operators work directly
.where { $0.startTime >= #bind(cutoff) }
.where { $0.startTime < #bind(endOfDay) }

// Multiple conditions — must be a SINGLE expression with &&
// Do NOT use multi-line statements (result builder won't compile)
.where { $0.babyID.eq(#bind(id)) && $0.endTime.is(nil) && $0.isNightSleep.eq(true) }
```

### Ordering (`.order`)
```swift
.order { $0.startTime.asc() }
.order { $0.startTime.desc() }
```

### Updates (`.update`)
```swift
// ALL variable values need #bind()
.update { $0.endTime = #bind(now) }
.update { $0.name = #bind(baby.name) }

// nil needs #bind with explicit type cast
.update { $0.endTime = #bind(nil as Date?) }

// String/bool/int LITERALS work without #bind
.update { $0.name = "Updated" }
.update { $0.isNightSleep = true }
```

### Common operations
```swift
// Fetch
try Baby.all().fetchAll(db)
try FeedEvent.where { $0.babyID.eq(#bind(id)) }.fetchOne(db)
try FeedEvent.where { $0.babyID.eq(#bind(id)) }.fetchCount(db)

// Insert
try Baby.insert { ... }.execute(db)

// Update by ID
try Baby.find(id).update { $0.name = #bind(name) }.execute(db)

// Delete
try Baby.find(id).delete().execute(db)
```

## Agent Coordination Rules

1. **Claim a phase** before starting. Update the Migration State table.
2. **Don't modify files outside your phase** without coordinating.
3. **Phase 1 must complete before other phases start.**
4. **Phases 3 and 4 can run in parallel** after Phase 2.
5. **Read this document before starting work.**
6. **Update this document** when making architectural decisions.
7. **Don't change the schema** without updating this document first.
