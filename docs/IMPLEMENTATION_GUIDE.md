# BabyTime Production Data Model — Implementation Guide

This guide enables any agent to pick up implementation at any phase. Read `BABYTIME.md` for product vision, `docs/DAY_MODEL.md` for the day state model, and `CLAUDE.md` for tech conventions. Read `.claude/napkin.md` for accumulated project learnings.

---

## Architecture

```
SwiftUI Views ← DayState ← DayEngine (pure function)
                              ↑
                   ActivityManager (@Observable)
                              ↑
                   SwiftData + CloudKit (private DB)
```

- **DayEngine** is a pure function: `(Baby, [FeedEvent], [SleepEvent], Date) → (DayState, FeedState)`
- **ActivityManager** bridges SwiftData ↔ DayEngine ↔ Views
- **CloudKit** syncs via same Apple ID across devices (no CKShare needed)
- **Active timers** persist immediately (endTime = nil) for multi-device visibility + crash recovery
- **TimeProvider** — `() -> Date` closure for testable time

## Key Decisions (DO NOT CHANGE without discussing with user)

- SwiftData (not Core Data) — simpler API, private CloudKit sync is sufficient
- Full 8-state day model engine — all states from DAY_MODEL.md
- Multi-baby support from day one
- Single Apple ID sharing (caregivers share iCloud password)
- Swift Testing framework (not XCTest) for all new tests
- iOS 26+, Swift 6, strict concurrency
- `@Observable` (not ObservableObject/Combine)
- Semantic design tokens in DesignTokens.swift — preserve the warm, calm aesthetic

---

## Session Plan

### Session 1: Foundation (Data Models + Engine) — COMPLETE
### Session 2: Integration (Settings + UI Wiring) — COMPLETE
### Session 3: Verification (Tests + Preview Gallery + Cleanup)

---

## Phase 1: SwiftData Models
**Status: [x] COMPLETE (Session 1, 2026-02-11 · verified on simulator 2026-02-12)**

### Checklist
- [x] Create `BabyTime/Models/Baby.swift` — SwiftData `@Model`
- [x] Create `BabyTime/Models/FeedEvent.swift` — SwiftData `@Model`
- [x] Create `BabyTime/Models/SleepEvent.swift` — SwiftData `@Model`
- [x] Update `BabyTimeApp.swift` — add `.modelContainer(for:)`
- [x] Verify project compiles with new models
- [x] Test SwiftData schema initialization on simulator (CloudKit sync requires physical device)

### Implementation Notes

**Baby.swift**
```swift
import SwiftData
import Foundation

@Model
final class Baby {
    var name: String = ""
    var birthdate: Date = Date()

    // Schedule settings (store as hour+minute integers to avoid timezone issues)
    var bedtimeHour: Int = 19      // 7 PM default
    var bedtimeMinute: Int = 0
    var dreamFeedEnabled: Bool = false
    var dreamFeedHour: Int = 22    // 10 PM default
    var dreamFeedMinute: Int = 30

    var createdAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \FeedEvent.baby)
    var feedEvents: [FeedEvent]? = []

    @Relationship(deleteRule: .cascade, inverse: \SleepEvent.baby)
    var sleepEvents: [SleepEvent]? = []
}
```

Store bedtime as hour+minute integers (not Date) to avoid timezone issues. Bedtime is a time-of-day concept, not a point in time.

Computed helpers to add:
- `ageInDays: Int` — from birthdate to now
- `bedtimeToday(referenceDate:) -> Date` — constructs today's bedtime from hour+minute
- `dreamFeedToday(referenceDate:) -> Date?` — if enabled

**FeedEvent.swift**
```swift
@Model
final class FeedEvent {
    var startTime: Date = Date()
    var endTime: Date?              // nil = timer running
    var feedKind: String = "bottle" // "bottle" or "nursing"
    var bottleSource: String = "breastMilk"
    var amountOz: Double = 0
    var nursingSide: String = "both"
    var baby: Baby?
}
```

Use String stored properties (not Swift enums) for CloudKit compatibility. Add computed properties for type-safe access.

**SleepEvent.swift**
```swift
@Model
final class SleepEvent {
    var startTime: Date = Date()
    var endTime: Date?  // nil = still sleeping
    var baby: Baby?
}
```

Computed: `durationMinutes`, `isActive` (endTime == nil)

**CloudKit constraints (enforced by model design above):**
- All properties have defaults ✓
- No `@Attribute(.unique)` ✓
- All relationships optional ✓

### Transition Notes
During Phase 1, the existing UI will temporarily break because ActivityManager still expects mock data. Keep the old ActivityManager init alongside the new models temporarily so the app compiles between phases.

---

## Phase 2: Day Engine (Pure Swift)
**Status: [x] COMPLETE (Session 1, 2026-02-11)**

### Checklist
- [x] Create `BabyTime/Engine/AgeTable.swift` — progressive wake windows by age
- [x] Create `BabyTime/Engine/DayState.swift` — state + feed state enums
- [x] Create `BabyTime/Engine/DayEngine.swift` — pure state derivation
- [x] Create `BabyTime/Engine/TimeProvider.swift` — clock abstraction
- [x] Write basic DayEngine tests — 46 tests, all passing
- [x] Verify all 8 states can be derived from test scenarios

### Implementation Notes

**AgeTable.swift**

Wake window table (from DAY_MODEL.md, converted to minutes):

| Age | WW1 | WW2 | WW3 | WW4 | Last WW |
|-----|-----|-----|-----|-----|---------|
| 0-2 mo | 45...60 | 45...60 | 45...60 | 45...60 | 45...60 |
| 3-4 mo | 75...90 | 90...105 | 90...105 | 105...120 | 105...120 |
| 5-7 mo | 105...150 | 120...165 | 135...180 | — | 150...180 |
| 8-10 mo | 150...180 | 180...210 | — | — | 180...240 |
| 11-14 mo | 180...240 | 210...270 | — | — | 210...270 |

Feed intervals:

| Age | Interval (min) | Feeds/Day |
|-----|---------------|-----------|
| 0-2 mo | 120...180 | 8...12 |
| 3-4 mo | 150...210 | 6...8 |
| 5-7 mo | 180...240 | 5...6 |
| 8-12 mo | 210...270 | 4...5 |

**DayState enum** — all 8 states from DAY_MODEL.md with associated values for display.

**DayEngine** — pure static function: `snapshot(baby:feeds:sleeps:now:) -> DaySnapshot`

State derivation logic:
1. No events today? → `.notStarted`
2. Currently sleeping?
   - Nap end time vs cutoff → `.sleepingNoPressure`, `.sleepingApproachingCutoff`, or `.sleepingMustEnd`
3. Awake — how long?
   - Past cutoff? → `.napWindowClosed`
   - Within bedtime buffer (30 min)? → `.bedtimeWindow`
   - Below WW lower bound? → `.awakeEarly`
   - Within WW range? → `.awakeApproaching`
   - Above WW upper bound? → `.awakeBeyond`

---

## Phase 3: Settings Screen
**Status: [x] COMPLETE (Session 2, 2026-02-11)**

### Checklist
- [x] Create `BabyTime/Views/SettingsView.swift`
- [x] Add baby creation flow (first launch / add baby)
- [x] Add baby selector (if multiple babies)
- [x] Add settings button to home screen bottom toolbar
- [x] Store selected baby ID in @AppStorage
- [x] Handle first launch (no babies yet) gracefully

### Implementation Notes

**SettingsView.swift** — Contains `SettingsView`, `AddBabyView`, `WelcomeView`, and `LabeledField` helper.
- Baby info card: name, birthdate (date picker)
- Schedule card: bedtime (time picker), dream feed toggle + time picker
- Baby selector card: shown when multiple babies exist
- Add baby button + `AddBabyView` sheet
- `WelcomeView` for first launch (no babies in store)
- Uses Binding wrappers to convert bedtime/dreamFeed hour+minute ↔ DatePicker Date values

**ContentView.swift** — `@AppStorage("selectedBabyID")` persists selected baby across launches.
- Gear icon button in bottom toolbar opens settings sheet
- `selectBabyFromStorage()` matches stableID from @AppStorage to baby, falls back to first baby
- Shows `WelcomeView` when no baby selected, `HomeView` otherwise

**Baby.swift** — Added `stableID: String = UUID().uuidString` for @AppStorage selection and CloudKit dedup. PersistentModelID isn't trivially serializable, so stableID provides a stable string identifier.

---

## Phase 4: Wire Engine to UI
**Status: [x] COMPLETE (Session 2, 2026-02-11)**

### Checklist
- [x] Refactor `ActivityManager` to use SwiftData + DayEngine
- [x] Update `HomeView` to render based on DayState
- [x] Update `FeedCard` with feed-state-aware modes
- [x] Update `SleepCard` with wake-window-aware modes
- [ ] Update `TodaySummaryCard` to query SwiftData — deferred (still uses legacy data)
- [x] Update sheet views (Nursing, Bottle, Sleep) to persist via SwiftData
- [x] Wire bedtime countdown for states 7-8
- [x] Verify timer start persists immediately (multi-device)
- [ ] Remove MockData.swift and old Activity.swift enums — deferred (LogView/TimelineView still use legacy types)

### Implementation Notes

**ActivityManager.swift** — Full rewrite from mock-data to SwiftData + DayEngine:
- `init(modelContext: ModelContext)` — takes context, loads babies, recovers active events
- Persist-on-start pattern: `startNursing()` creates FeedEvent (endTime=nil) immediately in SwiftData
- `stopNursing()` sets endTime, `resetNursing()` deletes event, `saveNursing()` clears active reference
- `recoverActiveEvents()` finds events with endTime==nil on app launch (crash recovery)
- API-compatible with sheet views: `nursingStartTime`, `nursingEndTime`, `sleepStartTime`, `sleepEndTime` are computed get/set properties delegating to SwiftData event objects
- All formatted display helpers (`feedCount`, `napCount`, `totalIntakeOz`, etc.) derive from SwiftData queries

**BabyTimeApp.swift** — Manual ModelContainer creation in `init()` to pass `mainContext` to ActivityManager before body is evaluated.

**HomeView.swift** — `sleepCardMode(from:)` maps all 8 DayStates to SleepCard.Mode variants. `feedCardMode(from:)` maps FeedState to FeedCard display.

**SleepCard.swift** — Simplified Mode enum:
- `.awake(label:duration:detail:)` — configurable text for all awake states
- `.sleeping(label:duration:detail:)` — engine-reported sleeping (blue accent label)
- `.sleepActive` — live timer (unchanged)

**Sheet views** — Updated `toggleTimer()` for persist-on-start pattern: if active→stop, if has session→reset+start, else→start.

**DateFormatting.swift** — Moved `Date.shortTime` extension from MockData.swift to `BabyTime/Design/DateFormatting.swift` (shared location).

**Deferred items:**
- `TodaySummaryCard` still uses legacy data — will update in a future pass
- `MockData.swift` and `Activity.swift` legacy types preserved for `LogView`/`TimelineView` previews
- `LogView` and `TimelineView` still use legacy types — planned for later cleanup

### Card State Mapping

| DayState | SleepCard Mode | Tone |
|----------|---------------|------|
| notStarted | "Good morning" | Calm |
| awakeEarly | "Awake for Xm" | Calm, informational |
| awakeApproaching | "Awake for Xm" + subtle sleep accent | Gentle awareness |
| awakeBeyond | "Awake for Xm" + prominent sleep signal | Calm urgency |
| sleepingNoPressure | "Sleeping Xm" | Restful |
| sleepingApproachingCutoff | "Sleeping Xm · Wake by HH:MM" | Heads-up |
| sleepingMustEnd | "Wake her up" | Direct but calm |
| napWindowClosed | "Bridging to bedtime · Xm" | Supportive |
| bedtimeWindow | "Bedtime in Xm" | Winding down |

---

## Phase 5: Tests
**Status: [~] Partially Complete (DayEngine + AgeTable tests from Session 1)**

### Checklist
- [x] Create `BabyTimeTests/DayEngineTests.swift` — parameterized state derivation (Session 1)
- [x] Create `BabyTimeTests/AgeTableTests.swift` — age bracket validation (Session 1)
- [ ] Create `BabyTimeTests/ModelTests.swift` — SwiftData CRUD + queries
- [x] `FeedStateTests` — included in DayEngineTests.swift (Session 1)
- [x] `NapCutoffTests` — included in DayEngineTests.swift (Session 1)
- [ ] Create `BabyTimeTests/ActivityManagerTests.swift` — integration tests
- [ ] Verify all tests pass after Phase 3-4 changes

### Testing Strategy

- All engine functions accept `now: Date` directly — no global state
- Parameterized tests with Swift Testing for age brackets × time scenarios
- SwiftData tests use in-memory container
- Edge cases: no events, short nap, past bedtime, nap transitions, active timers, retroactive edits

---

## Phase 6: Preview Gallery
**Status: [ ] Not Started**

### Checklist
- [ ] Create `BabyTime/Previews/PreviewHelpers.swift` — scenario factory
- [ ] Create `BabyTime/Previews/DayStateGallery.swift` — one preview per state
- [ ] Create time-lapse slider preview
- [ ] Verify all 8 states render correctly in Xcode previews
- [ ] Test at multiple age brackets (newborn, 3mo, 6mo, 10mo)

---

## File Map

### New Files
| Path | Phase | Purpose |
|------|-------|---------|
| `BabyTime/Models/Baby.swift` | 1 | SwiftData baby model |
| `BabyTime/Models/FeedEvent.swift` | 1 | SwiftData feed event |
| `BabyTime/Models/SleepEvent.swift` | 1 | SwiftData sleep event |
| `BabyTime/Engine/AgeTable.swift` | 2 | Progressive wake windows by age |
| `BabyTime/Engine/DayState.swift` | 2 | State enums |
| `BabyTime/Engine/DayEngine.swift` | 2 | Pure state derivation |
| `BabyTime/Engine/TimeProvider.swift` | 2 | Clock abstraction |
| `BabyTime/Views/SettingsView.swift` | 3 | Baby + schedule settings + WelcomeView + AddBabyView |
| `BabyTime/Design/DateFormatting.swift` | 4 | Date.shortTime extension (shared) |
| `BabyTime/Previews/PreviewHelpers.swift` | 6 | Scenario factory |
| `BabyTime/Previews/DayStateGallery.swift` | 6 | Preview per state |
| `BabyTimeTests/DayEngineTests.swift` | 5 | Engine tests |
| `BabyTimeTests/AgeTableTests.swift` | 5 | Age bracket tests |
| `BabyTimeTests/ModelTests.swift` | 5 | SwiftData tests |
| `BabyTimeTests/FeedStateTests.swift` | 5 | Feed state tests |
| `BabyTimeTests/NapCutoffTests.swift` | 5 | Cutoff tests |

### Modified Files
| Path | Phase | Changes |
|------|-------|---------|
| `BabyTimeApp.swift` | 1 | Add modelContainer |
| `ContentView.swift` | 3,4 | Settings button, baby context |
| `HomeView.swift` | 4 | DayState-driven rendering |
| `FeedCard.swift` | 4 | Feed state modes |
| `SleepCard.swift` | 4 | Wake window modes |
| `TodaySummaryCard.swift` | 4 | SwiftData queries |
| `ActivityManager.swift` | 4 | Full rewrite with SwiftData + DayEngine |
| `NursingSheetView.swift` | 4 | Persist via SwiftData |
| `BottleSheetView.swift` | 4 | Persist via SwiftData |
| `SleepSheetView.swift` | 4 | Persist via SwiftData |

### Removed Files
| Path | When | Replaced By |
|------|------|------------|
| `Models/MockData.swift` | Phase 6 | PreviewHelpers.swift |
| `Models/Activity.swift` | Phase 4 | Baby.swift, FeedEvent.swift, SleepEvent.swift |

### Unchanged Files
| Path | Reason |
|------|--------|
| `Design/DesignTokens.swift` | Design system preserved |
| `Design/CardShadowModifier.swift` | Styling preserved |
| `Components/BabyPhotoHeader.swift` | No changes needed |
| `Views/LogView.swift` | Data source changes only |
| `Views/TimelineView.swift` | Data source changes only |

---

## Agent Handoff Notes

When starting a new session:
1. Read this file first
2. Read `BABYTIME.md`, `docs/DAY_MODEL.md`, `CLAUDE.md`, `.claude/napkin.md`
3. Check which phases are marked complete above
4. Run `git log --oneline -10` to see recent commits
5. Run a build to verify current state compiles
6. Pick up the next incomplete phase

**Important conventions:**
- XcodeBuildMCP session defaults reset between messages — re-set scheme/simulator before each build
- iOS 26 toolbar: attach `.toolbar(.bottomBar)` to NavigationStack, not child views
- PBXFileSystemSynchronizedRootGroup: adding files to filesystem auto-syncs to Xcode project
- Use absolute paths for all bash commands (working dir may differ from project dir)
- Simulator: iPhone 17 Pro, ID `D999AB6D-9DB9-4F67-A02A-5E058C719792`, iOS 26.2
- Project path: `/Users/patrickmckowen/babytime/BabyTime.xcodeproj`, scheme: `BabyTime`

**Legacy type migration (current state after Session 2):**
- Old types in `Activity.swift` renamed to `LegacyBaby`, `LegacyBottleSource`, `LegacyNursingSide`
- `ActivityManager` now fully uses SwiftData models (Phase 4 complete)
- New types: `Baby` (@Model), `FeedEvent` (@Model), `SleepEvent` (@Model), `FeedKind`, `BottleSource`, `NursingSide`
- `FeedType`, `FeedActivity`, `SleepActivity`, `AgeBracket`, `AgeTargets`, `DayLog`, `Scenario` remain as legacy in `Activity.swift` and `MockData.swift`
- Legacy types still used by: `LogView.swift`, `TimelineView.swift`, `TodaySummaryCard.swift`
- Full legacy removal deferred to Session 3 cleanup
