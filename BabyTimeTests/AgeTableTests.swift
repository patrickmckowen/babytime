//
//  AgeTableTests.swift
//  BabyTimeTests
//
//  Tests for AgeTable age bracket lookup and progressive wake windows.
//

import Testing
import Foundation
@testable import BabyTime

@Suite("AgeTable — Age Bracket Targets")
struct AgeTableTests {

    @Test("All age brackets have valid tables",
          arguments: [0, 15, 30, 60, 90, 120, 150, 180, 210, 270, 300, 365, 400])
    func validBrackets(ageInDays: Int) {
        let table = AgeTable.forAge(days: ageInDays)
        #expect(table.wakeWindows.count >= 2, "Must have at least 2 wake windows (first + last)")
        #expect(table.feedIntervalMinutes.lowerBound > 0)
        #expect(table.expectedFeedsPerDay.lowerBound > 0)
        #expect(table.typicalNapsPerDay.lowerBound >= 1)
    }

    @Test("Wake windows are progressive (non-decreasing through the day)")
    func progressiveWindows() {
        for table in AgeTable.allTables {
            for i in 0..<(table.wakeWindows.count - 1) {
                let current = table.wakeWindows[i]
                let next = table.wakeWindows[i + 1]
                #expect(
                    current.lowerBound <= next.upperBound,
                    "Wake windows should be non-decreasing in \(table.ageLabel): WW\(i) \(current) vs WW\(i+1) \(next)"
                )
            }
        }
    }

    @Test("Age ranges cover 0 to 420 days without gaps")
    func noGaps() {
        let tables = AgeTable.allTables
        #expect(tables.first!.ageRangeDays.lowerBound == 0, "Should start at day 0")

        for i in 0..<(tables.count - 1) {
            #expect(
                tables[i].ageRangeDays.upperBound == tables[i + 1].ageRangeDays.lowerBound,
                "Gap between \(tables[i].ageLabel) and \(tables[i+1].ageLabel)"
            )
        }
    }

    @Test("currentWakeWindow clamps to last index for high nap counts")
    func clampToLast() {
        let table = AgeTable.forAge(days: 90) // 3-4 months, 5 wake windows
        let lastWW = table.lastWakeWindow
        let clamped = table.currentWakeWindow(completedNaps: 99)
        #expect(clamped == lastWW)
    }

    @Test("0-2 month old has flat wake windows (all the same)")
    func newbornFlat() {
        let table = AgeTable.forAge(days: 15)
        let firstWW = table.wakeWindows[0]
        for ww in table.wakeWindows {
            #expect(ww == firstWW, "Newborn wake windows should all be \(firstWW)")
        }
    }

    @Test("5-7 month old has 4 wake windows (WW1, WW2, WW3, lastWW)")
    func fiveMonthWindows() {
        let table = AgeTable.forAge(days: 150)
        #expect(table.wakeWindows.count == 4)
        #expect(table.ageLabel == "5-7 months")
    }

    @Test("Correct age bracket for boundary days",
          arguments: [
            (0, "0-2 months"),
            (59, "0-2 months"),
            (60, "3-4 months"),
            (119, "3-4 months"),
            (120, "5-7 months"),
            (209, "5-7 months"),
            (210, "8-10 months"),
            (299, "8-10 months"),
            (300, "11-14 months"),
            (419, "11-14 months"),
          ])
    func ageBoundaries(days: Int, expectedLabel: String) {
        let table = AgeTable.forAge(days: days)
        #expect(table.ageLabel == expectedLabel)
    }
}
