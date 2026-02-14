//
//  AgeTable.swift
//  BabyTime
//
//  Age-based targets with progressive wake windows.
//  Data from docs/DAY_MODEL.md.
//

import Foundation

struct AgeTable: Sendable, Equatable {
    let ageLabel: String
    let ageRangeDays: Range<Int>
    let typicalNapsPerDay: ClosedRange<Int>

    /// Progressive wake windows: [WW1, WW2, ..., lastWW]
    /// Index = number of completed naps. Last entry is always the bedtime wake window.
    let wakeWindows: [ClosedRange<Int>]

    let feedIntervalMinutes: ClosedRange<Int>
    let expectedFeedsPerDay: ClosedRange<Int>

    /// Returns the appropriate wake window range given how many naps are done today.
    /// If completedNaps exceeds available slots, returns the last (bedtime) window.
    func currentWakeWindow(completedNaps: Int) -> ClosedRange<Int> {
        let index = min(completedNaps, wakeWindows.count - 1)
        return wakeWindows[index]
    }

    /// The last wake window — used for nap cutoff and bedtime calculations
    var lastWakeWindow: ClosedRange<Int> {
        wakeWindows[wakeWindows.count - 1]
    }

    /// Nursing oz-per-minute estimate for this age bracket
    var nursingOzPerMinute: Double {
        switch ageRangeDays.lowerBound {
        case 0..<30: return 0.1
        case 30..<60: return 0.15
        default: return 0.2
        }
    }

    /// Daily intake target in oz
    var dailyIntakeOz: ClosedRange<Int> {
        switch ageRangeDays.lowerBound {
        case 0..<60: return 14...28
        case 60..<120: return 24...32
        case 120..<210: return 24...36
        case 210..<300: return 24...32
        default: return 20...28
        }
    }

    /// Daily sleep target in hours
    var dailySleepHours: ClosedRange<Int> {
        switch ageRangeDays.lowerBound {
        case 0..<120: return 14...17
        case 120..<210: return 12...16
        default: return 12...15
        }
    }
}

// MARK: - Age Bracket Lookup

extension AgeTable {

    static func forAge(days: Int) -> AgeTable {
        allTables.first { $0.ageRangeDays.contains(days) } ?? allTables.last!
    }

    // Source: docs/DAY_MODEL.md wake window table
    //
    // | Age      | Naps | WW1       | WW2       | WW3       | WW4       | Last WW   |
    // |----------|------|-----------|-----------|-----------|-----------|-----------|
    // | 0–2 mo   | 4–5  | 45–60m    | 45–60m    | 45–60m    | 45–60m    | 45–60m    |
    // | 3–4 mo   | 3–4  | 75–90m    | 90–105m   | 90–105m   | 105–120m  | 105–120m  |
    // | 5–7 mo   | 2–3  | 105–150m  | 120–165m  | 135–180m  | —         | 150–180m  |
    // | 8–10 mo  | 2    | 150–180m  | 180–210m  | —         | —         | 180–240m  |
    // | 11–14 mo | 1–2  | 180–240m  | 210–270m  | —         | —         | 210–270m  |

    static let allTables: [AgeTable] = [
        // 0-2 months (0-59 days)
        AgeTable(
            ageLabel: "0-2 months",
            ageRangeDays: 0..<60,
            typicalNapsPerDay: 4...5,
            wakeWindows: [45...60, 45...60, 45...60, 45...60, 45...60],
            feedIntervalMinutes: 120...180,
            expectedFeedsPerDay: 8...12
        ),
        // 3-4 months (60-119 days)
        AgeTable(
            ageLabel: "3-4 months",
            ageRangeDays: 60..<120,
            typicalNapsPerDay: 3...4,
            wakeWindows: [75...90, 90...105, 90...105, 105...120, 105...120],
            feedIntervalMinutes: 150...210,
            expectedFeedsPerDay: 6...8
        ),
        // 5-7 months (120-209 days)
        AgeTable(
            ageLabel: "5-7 months",
            ageRangeDays: 120..<210,
            typicalNapsPerDay: 2...3,
            wakeWindows: [105...150, 120...165, 135...180, 150...180],
            feedIntervalMinutes: 180...240,
            expectedFeedsPerDay: 5...6
        ),
        // 8-10 months (210-299 days)
        AgeTable(
            ageLabel: "8-10 months",
            ageRangeDays: 210..<300,
            typicalNapsPerDay: 2...2,
            wakeWindows: [150...180, 180...210, 180...240],
            feedIntervalMinutes: 210...270,
            expectedFeedsPerDay: 4...5
        ),
        // 11-14 months (300-419 days)
        AgeTable(
            ageLabel: "11-14 months",
            ageRangeDays: 300..<420,
            typicalNapsPerDay: 1...2,
            wakeWindows: [180...240, 210...270, 210...270],
            feedIntervalMinutes: 210...270,
            expectedFeedsPerDay: 4...5
        ),
    ]
}
