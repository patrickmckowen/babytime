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

The migration from SwiftData to SQLiteData is phased. During migration,
both the old SwiftData models and new SQLiteData models coexist. The new
models use a `Sync` prefix (e.g. `SyncBaby`) until Phase 2 when the old
models are removed and the new models are renamed.

## Schema

All SQLiteData models are `@Table` structs (value types). Relationships
are modeled with foreign key columns, not object references.

### Tables

```
SyncBaby (→ Baby after Phase 2)
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

SyncFeedEvent (→ FeedEvent after Phase 2)
├── id: UUID (primary key)
├── babyID: UUID (foreign key → SyncBaby.id)
├── startTime: Date
├── endTime: Date?
├── feedKind: FeedKind (.bottle | .nursing)
├── bottleSource: BottleSource (.breastMilk | .formula)
├── amountOz: Double
├── nursingSide: NursingSide (.left | .right | .both)
├── caregiverName: String
└── deviceID: String

SyncSleepEvent (→ SleepEvent after Phase 2)
├── id: UUID (primary key)
├── babyID: UUID (foreign key → SyncBaby.id)
├── startTime: Date
├── endTime: Date?
├── isNightSleep: Bool
├── caregiverName: String
└── deviceID: String

SyncWakeEvent (→ WakeEvent after Phase 2)
├── id: UUID (primary key)
├── babyID: UUID (foreign key → SyncBaby.id)
├── date: Date (start of day — one per baby per day)
├── time: Date (actual wake time)
├── caregiverName: String
└── deviceID: String
```

### Relationships

```
SyncBaby 1──* SyncFeedEvent   (via babyID, cascade delete)
SyncBaby 1──* SyncSleepEvent  (via babyID, cascade delete)
SyncBaby 1──* SyncWakeEvent   (via babyID, cascade delete)
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
| 1. Foundation (package, models, DB setup) | **Complete** | 108 tests passing |
| 2. ActivityManager rewrite | Not started | Depends on Phase 1 |
| 3. View updates | Not started | Depends on Phase 2 |
| 4. Test migration | Not started | Parallel with Phase 3 |
| 5. CloudKit private sync | Not started | Depends on Phases 1-4 |
| 6. CloudKit sharing (CKShare) | Not started | Depends on Phase 5 |
| 7. Polish (migration, cleanup, sync UI) | Not started | Depends on Phase 6 |

## Files Involved

### New files (Phase 1)
- `BabyTime/Database/SyncModels.swift` — @Table structs
- `BabyTime/Database/AppDatabase.swift` — database setup
- `BabyTimeTests/SyncModelTests.swift` — schema verification tests

### Files to modify (Phase 2+)
- `BabyTime/Models/ActivityManager.swift` — ModelContext → DatabaseQueue
- `BabyTime/BabyTimeApp.swift` — ModelContainer → prepareDependencies
- All view files using `@Query` → `@FetchAll`
- Model files: rename Sync-prefixed types to final names

### Files unchanged
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
