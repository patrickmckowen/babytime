# BabyTime Day Model

The app does not plan the day. It reacts to what's logged, tells you what it means for what's left, and works backward from bedtime. There is no schedule — only anchors, constraints, and the current moment.

## Inputs

| Input | Type | Purpose |
|---|---|---|
| **Baby's birthday** | Date | Derives age → drives all targets via `AgeTable` |
| **Bedtime** | Time (e.g., 7:00 PM) | Fixed anchor. All nap cutoff and end-of-day logic works backward from this. |
| **Wake time** | Time (optional, per day) | Explicit morning wake. Used as wake reference when no sleep events exist yet. |
| **Custom feed interval** | Minutes (optional, 0 = use age default) | Overrides the age-based feed interval on `Baby.customFeedIntervalMinutes`. |
| **Dream feed** | Toggle + time (optional) | Late feed reminder after baby is asleep for the night. Does not affect day model calculations. |

Everything else is derived from age and from what the parent logs.

## Core Engine

`DayEngine.snapshot()` is a **pure function** — no side effects, no persistence, no UI.

```
DayEngine.snapshot(baby, feeds, sleeps, wakeTime, now) → DaySnapshot
```

### Wake Reference

The engine resolves "when did baby last wake up?" using this priority chain:

```
wakeReference = lastSleepEnd ?? wakeTime ?? firstEventTime
```

- `lastSleepEnd` — most recent completed nap's end time (always wins if naps exist)
- `wakeTime` — explicit morning wake time from `WakeEvent`
- `firstEventTime` — earliest logged event of any kind

If all are nil → state is `.notStarted`.

### DaySnapshot Output

```swift
struct DaySnapshot {
    let dayState: DayState          // Current sleep/wake state (10 cases)
    let feedState: FeedState         // Current feed state (5 cases)
    let completedNaps: Int
    let totalFeedCount: Int
    let napCutoff: Date              // Last possible nap end time
    let bedtime: Date
    let ageTable: AgeTable
    let wakeTime: Date?
    let wakeReference: Date?         // For live awake-duration display
    let lastFeedReference: Date?     // For live "last fed X ago" display
}
```

The view layer uses `wakeReference` and `lastFeedReference` with `TimelineView(.periodic(by: 60))` to live-update durations without recomputing the full snapshot.

## Age-Derived Targets

`AgeTable.forAge(days:)` maps baby age to developmental bracket. All values in **minutes**.

### Wake Windows

Progressive throughout the day — indexed by completed nap count: `wakeWindows[min(completedNaps, count-1)]`. The last entry is always the bedtime wake window, also used for nap cutoff.

| Age | Days | Naps | WW1 | WW2 | WW3 | WW4 | Last WW |
|---|---|---|---|---|---|---|---|
| 0–2 mo | 0–59 | 4–5 | 45–60 | 45–60 | 45–60 | 45–60 | 45–60 |
| 3–4 mo | 60–149 | 3–4 | 75–90 | 90–105 | 90–105 | 105–120 | 105–120 |
| 5–7 mo | 150–209 | 2–3 | 105–150 | 120–165 | 135–180 | — | 150–180 |
| 8–10 mo | 210–299 | 2 | 150–180 | 180–210 | — | — | 180–240 |
| 11–14 mo | 300–419 | 1–2 | 180–240 | 210–270 | — | — | 210–270 |

### Feed Intervals

| Age | Days | Interval (min) | Feeds/Day |
|---|---|---|---|
| 0–2 mo | 0–59 | 120–180 | 8–12 |
| 3–4 mo | 60–149 | 150–210 | 6–8 |
| 5–7 mo | 150–209 | 180–240 | 5–6 |
| 8–10 mo | 210–299 | 210–270 | 4–5 |
| 11–14 mo | 300–419 | 210–270 | 4–5 |

Custom feed interval (`baby.customFeedIntervalMinutes > 0`) overrides the age-based range with a fixed value.

### Nap Cutoff

Single computed timestamp:

```
napCutoff = bedtime − lastWakeWindow.upperBound
```

Example: 3–4 mo baby, bedtime 7:00 PM, last WW upper = 120 min → cutoff = 5:00 PM.

The UI clamps "nap by" suggestions: `napByTime = min(wakeReference + WW.upperBound, napCutoff)`.

## Day States

`DayState` is a 10-case enum. The engine derives exactly one state from inputs.

| # | State | Condition | What the UI shows |
|---|---|---|---|
| 0 | `notStarted` | No wake reference (no events, no wake time) | "When did {name} wake up?" + time picker |
| 1 | `awakeEarly` | Awake minutes < WW lower bound | "Awake {dur}" · "Nap by {time}" |
| 2 | `awakeApproaching` | Awake minutes within WW range | "Awake {dur}" · "Nap by {time}" |
| 3 | `awakeBeyond` | Awake minutes > WW upper bound | "Awake {dur}" · "Wake window ended at {time}" |
| 4 | `sleepingNoPressure` | Active nap, cutoff > 30 min away | "Asleep {dur}" · "Started at {time}" |
| 5 | `sleepingApproachingCutoff` | Active nap, cutoff ≤ 30 min away | "Asleep {dur}" · "Wake in {X}m for bedtime" |
| 6 | `sleepingMustEnd` | Active nap, past cutoff | "Asleep {dur}" · "Past cutoff for bedtime" |
| 7 | `napWindowClosed` | Awake, past cutoff, bedtime > 30 min away | "Awake {dur}" · "No more naps today" |
| 8 | `bedtimeWindow` | Awake, bedtime ≤ 30 min away (or past) | "Time for bed" · "Went to bed" button → sheet |
| 9 | `asleepForNight` | Active sleep with `isNightSleep` flag | "Asleep {dur}" · "Fell asleep at {time}" · "Woke up" button → sheet |

**Derivation priority** (evaluated top-to-bottom, first match wins):

1. No wake reference → `notStarted`
2. Active sleep + `isNightSleep` → `asleepForNight`
3. Active sleep + past cutoff → `sleepingMustEnd`
4. Active sleep + cutoff ≤ 30 min → `sleepingApproachingCutoff`
5. Active sleep → `sleepingNoPressure`
6. Bedtime ≤ 30 min away → `bedtimeWindow`
7. Past bedtime → `bedtimeWindow(0)`
8. Past cutoff → `napWindowClosed`
9. Awake < WW lower → `awakeEarly`
10. Awake ≤ WW upper → `awakeApproaching`
11. Awake > WW upper → `awakeBeyond`

## Feed States (Parallel Track)

`FeedState` runs independently of `DayState`. Five cases:

| State | Condition |
|---|---|
| `noFeedsYet` | No completed feeds today |
| `feedingNow` | Active nursing session (no endTime) |
| `recentlyFed` | Minutes since last feed < 80% of interval lower bound |
| `approaching` | Minutes since last feed ≥ 80% of interval lower bound |
| `ready` | Minutes since last feed ≥ interval lower bound |

Feed time is measured from the last completed feed's **startTime**.

When `asleepForNight`, the feed card shows "Dream feed at {time}" (if configured) or "Sweet dreams" instead of the standard offer.

## State Transitions

States change from logged events and elapsed time. The app never asks the parent to declare intent.

| Trigger | Transition |
|---|---|
| Wake time set or first event logged | `notStarted` → awake state (1–3 based on elapsed time) |
| Wake minutes cross WW lower bound | `awakeEarly` → `awakeApproaching` |
| Wake minutes cross WW upper bound | `awakeApproaching` → `awakeBeyond` |
| Sleep started | Any awake state → sleeping state (4–6 based on cutoff proximity) |
| Active nap cutoff ≤ 30 min | `sleepingNoPressure` → `sleepingApproachingCutoff` |
| Active nap past cutoff | `sleepingApproachingCutoff` → `sleepingMustEnd` |
| Nap ended, before cutoff | → awake state (1–3 based on new WW for incremented nap count) |
| Nap ended, after cutoff | → `napWindowClosed` |
| Bedtime ≤ 30 min away | → `bedtimeWindow` |
| Night sleep logged (`isNightSleep` flag) | → `asleepForNight` |
| "Woke up" logged ≥ 5 AM | `asleepForNight` → night sleep closed + wake time set → awake state (1–3) |
| "Woke up" logged < 5 AM | `asleepForNight` → night sleep closed → `bedtimeWindow` (overnight wake cycle) |
| "Went to bed" after overnight wake | `bedtimeWindow` → new night sleep created → `asleepForNight` |

### Overnight Wake Flow

When the baby wakes during the night (before 5 AM), the parent taps "Woke up" on the sleep card. This closes the current night sleep but does **not** set the morning wake time. The card cycles back to `bedtimeWindow` with a "Went to bed" button. Once the baby falls back asleep, the parent taps "Went to bed" to create a new night sleep, returning to `asleepForNight`.

This cycle repeats for each overnight waking:

```
asleepForNight → "Woke up" (< 5 AM) → bedtimeWindow → "Went to bed" → asleepForNight → ...
```

When the baby wakes after 5 AM, the wake time is set as the morning wake, ending the overnight cycle and transitioning to a normal daytime awake state.

## Edge Cases

- **No naps logged, long awake time** — Engine reports facts. Wake window signal handles urgency naturally.
- **Very short nap** — Wake window resets with incremented nap count. Next WW may be wider, so re-entry into approaching range adjusts automatically.
- **Retroactive logging** — All events accept adjusted times. Snapshot recomputes from corrected data.
- **Nap transitions (e.g., 3→2 naps)** — Wake window index adapts to actual nap count. If only 1 nap by cutoff, the model uses WW2 naturally.
- **Late nap suggestion clamping** — If `wakeReference + WW.upperBound > napCutoff`, the UI displays `napCutoff` instead, preventing suggestions past the safe window.
- **Cross-day night sleep** — Night sleep logged at 8 PM on day N is still active on day N+1. `activeNightSleep` queries all baby sleep events (not just today's) for an active `isNightSleep` event. The snapshot includes it for correct `asleepForNight` state derivation.
- **Orphaned night sleep** — If a night sleep is never closed (app crash, forgotten), a 48-hour safety net auto-closes it with an 8-hour assumed duration. This replaces the previous midnight auto-close which lost data.
- **Morning wake threshold** — 5 AM hardcoded. Wakes before 5 AM are treated as overnight wakings; wakes at or after 5 AM set the morning wake time.
- **Nap count excludes night sleep** — Only completed sleeps where `isNightSleep == false` count toward `completedNaps`. This prevents night sleep from advancing the wake window index.
