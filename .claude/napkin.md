# Napkin

## Corrections
| Date | Source | What Went Wrong | What To Do Instead |
|------|--------|----------------|-------------------|
| 2026-02-11 | user | Didn't check `.git/config` for remote URL, asked user instead | Always check `.git/config` for remote info before asking |
| 2026-02-11 | self | Tried running bash commands in Explore mode | Remember: Explore mode = read-only, use Read/Glob/Grep tools only |
| 2026-02-11 | self | REBASE_HEAD existed but no rebase was active - stale file | Git state files can be stale; check `git status` for truth |
| 2026-02-11 | self | `git mv` into an existing empty dir nests instead of replacing | When `git mv A B` and B already exists as a dir, A goes INSIDE B. Check target doesn't exist first, or use temp names |
| 2026-02-11 | user | Replaced native iOS 26 toolbar with custom HStack bottom bar | User prefers native iOS 26 toolbar — fix placement in hierarchy, don't replace with custom views |
| 2026-02-11 | self | DayEngine test wake window expectations wrong | Progressive wake windows: nap count determines WW index. 1 completed nap → WW2, not WW1. Always account for nap count in test scenarios |
| 2026-02-11 | self | Introduced naming conflicts (Baby, BottleSource, NursingSide) between new SwiftData models and old structs | When adding new types that share names with existing ones, rename old types first (Legacy prefix) before creating new ones |
| 2026-02-12 | self | saveSleep()/saveNursing() cleared active reference without setting endTime — orphaned active event in SwiftData | Any "finalize" action on a persist-on-start timer MUST set endTime before clearing the reference |

## User Preferences
- Ask questions, don't guess or assume
- Prefers thorough research before action
- Remote: https://github.com/patrickmckowen/babytime.git

## Patterns That Work
- Using Explore agent for full directory tree discovery
- Reading .git/config for repo metadata
- Feature branches for safe refactoring (reversible by deleting branch)
- PBXFileSystemSynchronizedRootGroup allows moving dirs without editing pbxproj (paths are relative to xcodeproj parent)
- Use temp names when moving dirs that collide (e.g., BabyTime_src → BabyTime)
- iOS 26 `.toolbar(.bottomBar)`: attach to NavigationStack (outer), not child views inside it, to avoid UIKit subview warning
- XcodeBuildMCP session defaults reset between messages — re-set scheme/simulator before each build
- DayEngine as pure function (no side effects) makes it trivially testable — 46 tests, instant execution
- Store bedtime as hour+minute integers (not Date) to avoid timezone issues
- Use String stored properties in SwiftData models for CloudKit compat, with computed type-safe accessors
- Legacy prefix pattern for gradual migration (LegacyBaby, LegacyBottleSource, etc.)
- Simulator: iPhone 17 Pro `D999AB6D-9DB9-4F67-A02A-5E058C719792` iOS 26.2
- Persist-on-start pattern for timers: create SwiftData event immediately (endTime=nil), stop sets endTime, reset deletes, save just clears reference
- `stableID` (UUID string) on Baby model for @AppStorage — PersistentModelID can't be trivially serialized
- Manual ModelContainer in App.init() to inject mainContext into ActivityManager before body evaluates
- Computed get/set properties on ActivityManager for sheet view compatibility (delegating to SwiftData event objects)
- Preview pattern: in-memory ModelContainer → pass container.mainContext to ActivityManager → inject via .environment()
- Draft state pattern for timer sheets: use `@State` local vars for pre-event times, `effectiveTime` computed props that prefer event over draft, route bindings to correct source via `hasSleepSession` check
- Timer resume: add `resumeSleep()` that clears endTime, don't reset+restart. Only Reset button should delete the event

## Patterns That Don't Work
- Glob can't find directories (like .xcodeproj) - it only finds files
- Bash commands blocked in Explore mode
- `Image.scaledToFill().aspectRatio()` — layout size overflows the frame, bleeds behind sibling views. Use `Color.clear.aspectRatio().overlay { Image.scaledToFill() }.clipped()` instead

## Domain Notes
- BabyTime: iOS SwiftUI app, iOS 26+, Swift 6, CloudKit
- Xcode 26.2 project using PBXFileSystemSynchronizedRootGroup (auto-sync with filesystem)
- .xcodeproj relative paths: BabyTime, BabyTimeTests, BabyTimeUITests (relative to xcodeproj parent)
- CODE_SIGN_ENTITLEMENTS = BabyTime/BabyTime.entitlements (relative to project root)
- Implementation guide: docs/IMPLEMENTATION_GUIDE.md — read this first in new sessions
- Phase 1+2 complete: SwiftData models + DayEngine + 46 tests passing
- Phase 3+4 complete: Settings screen + UI wiring (Session 2)
- Deferred: TodaySummaryCard, LogView, TimelineView still use legacy types
- Deferred: MockData.swift and Activity.swift legacy types not yet removed
- Next: Session 3 = Run tests, verify on simulator, cleanup legacy types, preview gallery
- All changes uncommitted on `feature/bottle-sheet` branch
