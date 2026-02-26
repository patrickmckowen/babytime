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

## WakeEvent Upsert Pattern

One WakeEvent per baby per day. Query for existing before creating.
Last-write-wins is acceptable (wake time is the same either way).

## Testing

- Use in-memory `DatabaseQueue()` — no file system, no CloudKit
- Test command: `xcodebuild test -only-testing:BabyTimeTests
  -parallel-testing-enabled NO`
- DayEngine tests are pure-functional and don't touch the database

## Migration State

| Phase | Status | Notes |
|---|---|---|
| 1. Foundation (package, models, DB setup) | **Complete** | SQLiteData + StructuredQueries |
| 2. ActivityManager rewrite | **Complete** | ModelContext → DatabaseWriter, all queries use StructuredQueries |
| 3. View updates | **Complete** | SwiftData imports removed, bindings use ActivityManager |
| 4. Test migration | **Complete** | 109 tests across 22 suites passing |
| 5. CloudKit private sync | Not started | Depends on Phases 1-4 |
| 6. CloudKit sharing (CKShare) | Not started | Depends on Phase 5 |
| 7. Polish (migration, cleanup, sync UI) | Not started | Depends on Phase 6 |

## Files Involved

### Database layer
- `BabyTime/Database/Models.swift` — `@Table` structs (Baby, FeedEvent, SleepEvent, WakeEvent)
- `BabyTime/Database/AppDatabase.swift` — database setup + DependencyValues extensions
- `BabyTimeTests/SyncModelTests.swift` — schema verification and CRUD tests

### Application layer
- `BabyTime/Models/ActivityManager.swift` — all persistence via `DatabaseWriter`
- `BabyTime/BabyTimeApp.swift` — `prepareDependencies` bootstrap

### Pure logic (no database dependency)
- `BabyTime/Engine/DayEngine.swift` — pure functions
- `BabyTime/Engine/AgeTable.swift` — pure data
- `BabyTime/Models/DeviceIdentity.swift` — UserDefaults only
- `BabyTime/Models/DayState.swift` — pure value types

## Agent Coordination Rules

1. **Claim a phase** before starting. Update the Migration State table.
2. **Don't modify files outside your phase** without coordinating.
3. **Phase 1 must complete before other phases start.**
4. **Phases 3 and 4 can run in parallel** after Phase 2.
5. **Read this document before starting work.**
6. **Update this document** when making architectural decisions.
7. **Don't change the schema** without updating this document first.
