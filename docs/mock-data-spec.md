# BABYTIME Mock Data Specification

## Current Moment

**Date:** Thursday, January 29, 2026  
**Time:** 3:15 PM

---

## Baby

| Field | Value |
|-------|-------|
| Name | Kaia |
| Birthdate | October 17, 2025 |
| Age | 3 months, 12 days |

---

## Today's Activities

### Feeds

| Time | Type | Source | Amount |
|------|------|--------|--------|
| 6:50 AM | Bottle | Breast milk | 4 oz |
| 9:00 AM | Bottle | Breast milk | 4 oz |
| 11:25 AM | Bottle | Breast milk | 5 oz |
| 1:50 PM | Bottle | Breast milk | 4 oz |

**Daily total:** 17 oz

### Sleep

| Start | End | Duration |
|-------|-----|----------|
| 8:02 AM | 8:44 AM | 42 min |
| 10:19 AM | 10:49 AM | 30 min |
| 12:55 PM | 1:15 PM | 20 min |

**Daily total:** 92 min (1h 32m)  
**Longest session:** 42 min  
**Session count:** 3

---

## Derived State (at 3:15 PM)

| Metric | Value |
|--------|-------|
| Time since last feed | 1h 25m |
| Time since last wake | 2h 00m |
| Wake window status | Exceeded (target: 75–90 min) |
| Feed interval status | Within range (target: 150–180 min) |

---

## Age-Based Targets (3 months)

| Target | Range | Notes |
|--------|-------|-------|
| Wake window | 75–90 min | Time between sleeps |
| Feed interval | 2.5–3 hours | Time between feeds |
| Daily intake | 24–32 oz | Total breast milk/formula |
| Daily sleep | 14–17 hours | Including overnight |

---

## Data Model Notes

### Feed Types
- **Bottle:** breast milk, formula
- **Nursing:** left, right, both (with duration per side)

### Activity Representation
Activities are stored as discrete events with:
- UUID
- Type (feed or sleep)
- Start time
- End time (for sleep) or duration (for nursing)
- Type-specific metadata (amount for bottles, side for nursing)

### Calculations
- "Time since X" is computed from current time minus last activity end time
- Wake window is time since last sleep ended
- Feed interval is time since last feed started
- Status thresholds derived from age-based targets

---

## Swift Data Model

```swift
import Foundation

// MARK: - Core Types

struct Baby {
    let id: UUID
    let name: String
    let birthdate: Date
    
    var ageInDays: Int {
        Calendar.current.dateComponents([.day], from: birthdate, to: .now).day ?? 0
    }
}

enum FeedType {
    case bottle(source: BottleSource, amountOz: Double)
    case nursing(side: NursingSide, durationMinutes: Int)
}

enum BottleSource: String {
    case breastMilk = "Breast milk"
    case formula = "Formula"
}

enum NursingSide {
    case left, right, both
}

struct FeedActivity {
    let id: UUID
    let startTime: Date
    let type: FeedType
}

struct SleepActivity {
    let id: UUID
    let startTime: Date
    let endTime: Date
    
    var durationMinutes: Int {
        Int(endTime.timeIntervalSince(startTime) / 60)
    }
}

struct AgeTargets {
    let wakeWindowMinutes: ClosedRange<Int>
    let feedIntervalMinutes: ClosedRange<Int>
    let dailyIntakeOz: ClosedRange<Int>
    let dailySleepHours: ClosedRange<Int>
}

struct DayLog {
    let date: Date
    let feeds: [FeedActivity]
    let sleeps: [SleepActivity]
}

struct MockScenario {
    let baby: Baby
    let currentTime: Date
    let today: DayLog
    let targets: AgeTargets
}
```

## Mock Data Instance

```swift
import Foundation

extension MockScenario {
    
    /// January 29, 2026 at 3:15 PM scenario
    static let preview: MockScenario = {
        
        let calendar = Calendar.current
        
        // Reference date: January 29, 2026
        let jan29 = DateComponents(year: 2026, month: 1, day: 29)
        
        func time(_ hour: Int, _ minute: Int) -> Date {
            var components = jan29
            components.hour = hour
            components.minute = minute
            return calendar.date(from: components)!
        }
        
        let baby = Baby(
            id: UUID(),
            name: "Kaia",
            birthdate: calendar.date(from: DateComponents(year: 2025, month: 10, day: 17))!
        )
        
        let feeds: [FeedActivity] = [
            FeedActivity(
                id: UUID(),
                startTime: time(6, 50),
                type: .bottle(source: .breastMilk, amountOz: 4)
            ),
            FeedActivity(
                id: UUID(),
                startTime: time(9, 00),
                type: .bottle(source: .breastMilk, amountOz: 4)
            ),
            FeedActivity(
                id: UUID(),
                startTime: time(11, 25),
                type: .bottle(source: .breastMilk, amountOz: 5)
            ),
            FeedActivity(
                id: UUID(),
                startTime: time(13, 50),
                type: .bottle(source: .breastMilk, amountOz: 4)
            )
        ]
        
        let sleeps: [SleepActivity] = [
            SleepActivity(
                id: UUID(),
                startTime: time(8, 02),
                endTime: time(8, 44)
            ),
            SleepActivity(
                id: UUID(),
                startTime: time(10, 19),
                endTime: time(10, 49)
            ),
            SleepActivity(
                id: UUID(),
                startTime: time(12, 55),
                endTime: time(13, 15)
            )
        ]
        
        let targets = AgeTargets(
            wakeWindowMinutes: 75...90,
            feedIntervalMinutes: 150...180,
            dailyIntakeOz: 24...32,
            dailySleepHours: 14...17
        )
        
        return MockScenario(
            baby: baby,
            currentTime: time(15, 15),
            today: DayLog(
                date: calendar.date(from: jan29)!,
                feeds: feeds,
                sleeps: sleeps
            ),
            targets: targets
        )
    }()
}
```

## Computed Helpers

```swift
extension MockScenario {
    
    var lastFeed: FeedActivity? {
        today.feeds.max(by: { $0.startTime < $1.startTime })
    }
    
    var lastSleep: SleepActivity? {
        today.sleeps.max(by: { $0.endTime < $1.endTime })
    }
    
    var minutesSinceLastFeed: Int? {
        guard let feed = lastFeed else { return nil }
        return Int(currentTime.timeIntervalSince(feed.startTime) / 60)
    }
    
    var minutesSinceLastWake: Int? {
        guard let sleep = lastSleep else { return nil }
        return Int(currentTime.timeIntervalSince(sleep.endTime) / 60)
    }
    
    var totalFeedOz: Double {
        today.feeds.reduce(0) { total, feed in
            switch feed.type {
            case .bottle(_, let oz): return total + oz
            case .nursing: return total
            }
        }
    }
    
    var totalSleepMinutes: Int {
        today.sleeps.reduce(0) { $0 + $1.durationMinutes }
    }
    
    var longestSleepMinutes: Int {
        today.sleeps.map(\.durationMinutes).max() ?? 0
    }
}
```
