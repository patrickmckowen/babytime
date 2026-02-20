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
| 2026-02-14 | user | "Awake for" card showed stale value (26m instead of 82m) — DayEngine.snapshot bakes wakeMinutes as static Int, never refreshed | Time-dependent display values need live updates via TimelineView, not static snapshot values |
| 2026-02-14 | self | Complex SwiftUI body with existential types `(any Protocol)?` + nested ForEach/Section caused "unable to type-check" | Break up body into extracted computed properties/methods; use concrete enum instead of protocol existential; use List not ScrollView for swipeActions |
| 2026-02-14 | user | Bottle source (breastMilk vs formula) not used in display | Don't include "of Breast Milk" in activity descriptions |
| 2026-02-15 | self | DatePicker shows `?? Date()` default but `@State` draft stays nil until user interacts | When one draft time is set, auto-initialize the companion to `Date()` so displayed value matches internal state |
| 2026-02-15 | self | Running `xcodebuild test` without `-only-testing` included BabyTimeUITests, which spawns simulator clones per UI config (runsForEachTargetApplicationUIConfiguration) and OOM'd the machine | ALWAYS use `-only-testing:BabyTimeTests`. Never run BabyTimeUITests. See CLAUDE.md Testing section and xcodebuildmcp guide.md |
| 2026-02-17 | self | Tried to extract `matchedTransitionSource` config closure into a static func with `MatchedTransitionSourceConfiguration.Source` type | `Source` is not a member type of the protocol — opaque return types. Keep closure inline, reference design tokens within it |
| 2026-02-17 | self+user | Shadow flash on zoom transition — `.cardShadow()` before `.matchedTransitionSource` caused shadow to disappear/reappear during animation | Apply `.cardShadow()` AFTER `.matchedTransitionSource`. Don't duplicate shadow in config closure — only `.background()` and `.clipShape()`. The config `.shadow()` renders on a different backing layer than `View.shadow()`, causing the flash. See ios-fluid-components gotchas.md |
| 2026-02-17 | user | SleepSheetView manual logging broken — draft time bindings didn't auto-initialize companion time | When duplicating sheet patterns, verify ALL branches of binding setters are copied — the no-session else branch with auto-init is easy to miss |
| 2026-02-17 | self | napByTimeString() computed "Nap by X" from wakeReference + currentWW.upperBound without clamping to napCutoff — suggested naps 30 min before bedtime | When DayEngine exposes a boundary (napCutoff, bedtime), the UI MUST respect it. Don't recompute from raw inputs when a pre-computed limit exists on the snapshot |
| 2026-02-20 | self | SwiftData tests crashed with "ModelContext.reset destroyed model instance" — test's ModelContainer was deallocated when `makeManager()` returned | Use `withExtendedLifetime(container)` to keep ModelContainer alive for the full test scope. Never let a container become a temporary local that outlives its function |
| 2026-02-20 | self | `syncActiveEvents()` cleared stopped event references during `refresh()` — `stopSleep()` → `refresh()` → sync sees event not active → sets to nil | Only scan for new active events when no event is currently tracked (`== nil`). Stopped events must be preserved until explicit save/reset |
| 2026-02-20 | self | `nursingOzPerMinute` used `ageRangeDays.lowerBound` in switch but 0-2mo bracket has lowerBound=0, making `case 30..<60` dead code | Pass `ageInDays` explicitly when the distinction within a bracket matters. Don't rely on bracket boundaries for intra-bracket logic |
| 2026-02-20 | self | No shared scheme → Xcode 26.2 auto-generated scheme with parallel distributed testing, spawning 11 simulator clones | Always commit a shared scheme at `xcshareddata/xcschemes/`. Set `parallelizable="NO"` on test targets. Use `-parallel-testing-enabled NO` as belt-and-suspenders |
| 2026-02-20 | self | `AgeTableTests` had wrong boundary: `(120, "5-7 months")` but day 120 is in `60..<150` = "3-4 months" | Always verify parameterized test data against the actual source ranges. Day 150 is the real boundary for "5-7 months" |
| 2026-02-20 | self | In-memory ModelContainer in test host app + test containers collided | Give each container a unique name: `ModelConfiguration("test-\(UUID())")` for tests, `ModelConfiguration("test-host")` for the app's test-mode container |

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
- For time-dependent display values: expose reference Date on snapshot, compute elapsed time at the view layer via TimelineView(.periodic), not in the engine snapshot
- Edit mode on existing sheets: add optional `editingEvent` param, `isEditing` computed prop, seed `@State` drafts in `.onAppear`, branch save/reset logic on isEditing
- LogEntry enum wrapping FeedEvent/SleepEvent works well for unified list display with PersistentIdentifier as Identifiable id
- `.swipeActions` requires List context, not LazyVStack — use List with .plain style + .scrollContentBackground(.hidden) for custom backgrounds
- Always use `-only-testing:BabyTimeTests -parallel-testing-enabled NO` for test runs — pure unit tests, in-memory SwiftData, no simulator UI, completes in seconds
- SwiftData test pattern: `withExtendedLifetime(container) { ... }` to keep ModelContainer alive for the full test scope
- Named ModelConfigurations in tests (`"test-\(UUID())"`) prevent container collisions with the app host
- Shared scheme committed at `xcshareddata/xcschemes/BabyTime.xcscheme` — do not delete, controls parallel testing

## Patterns That Don't Work
- Glob can't find directories (like .xcodeproj) - it only finds files
- Bash commands blocked in Explore mode
- `Image.scaledToFill().aspectRatio()` — layout size overflows the frame, bleeds behind sibling views. Use `Color.clear.aspectRatio().overlay { Image.scaledToFill() }.clipped()` instead
- `xcodebuild test` without `-only-testing:BabyTimeTests` — runs BabyTimeUITests which spawns simulator clones and OOMs the machine. Always scope to unit tests only

## Domain Notes
- BabyTime: iOS SwiftUI app, iOS 26+, Swift 6, CloudKit
- Xcode 26.2 project using PBXFileSystemSynchronizedRootGroup (auto-sync with filesystem)
- .xcodeproj relative paths: BabyTime, BabyTimeTests, BabyTimeUITests (relative to xcodeproj parent)
- CODE_SIGN_ENTITLEMENTS = BabyTime/BabyTime.entitlements (relative to project root)
- Read BABYTIME.md for product vision and principles
- Not using bottle source (breastMilk vs formula) in display — user preference

### Fluid Transition: FeedCard → Nursing/Bottle Sheets
- **Approach chosen:** Zoom transition (`.navigationTransition(.zoom)` + `.matchedTransitionSource`)
- **Rejected:** Glass morph (cards use `Color.btBackground` not glass — glass is for chrome), matchedGeometryEffect (over-engineered, no free dismiss gestures)
- **Implementation:** `@Namespace` declared in ContentView, threaded via `Namespace.ID` param through HomeView → FeedCard
- **Source ID:** `"feedSheet"` on the **card container** (not buttons) — shared by both nursing and bottle sheets since they originate from the same card
- **Why card-level:** Buttons disappear when timer is active (`.nursingActive` mode), breaking the zoom-back animation. Card container is always visible across all modes.
- **Sheet side:** `.presentationDetents([.medium, .large])` + `.navigationTransition(.zoom(sourceID: "feedSheet", in:))` on both NursingSheetView and BottleSheetView
- **Two sheets, one sourceID:** Safe because only one sheet is presented at a time. System resolves matchedTransitionSource at present/dismiss time.
- **Active timer tap:** Card tap in `.nursingActive` mode now also gets zoom transition since the card container is the source
- **Known risk:** iOS 26 beta 3 has occasional glitchiness with sheet zoom transitions. Fallback: swap `.sheet` to `.fullScreenCover` if zoom is unreliable

### Fluid Transition: SleepCard → SleepSheetView
- **Source ID:** `"sleepSheet"` on the **card container** (not the Sleep button)
- **Why card-level:** Same reason as feed — Sleep button disappears in `.sleepActive` mode
- Card container always visible across all modes (`.awake`, `.sleepActive`, `.sleeping`, `.wakeTimePrompt`, `.bedtimePrompt`)
- Active timer tap in `.sleepActive` mode now also gets zoom transition
