//
//  MockData.swift
//  BabyTime
//

import Foundation

// MARK: - Preview Scenario

extension Scenario {

    /// January 29, 2026 at 3:15 PM scenario
    static let preview: Scenario = {

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

        return Scenario(
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

// MARK: - Computed Helpers

extension Scenario {

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

    // MARK: - WhatsNext Helpers

    var wakeWindowFormatted: String {
        guard let mins = minutesSinceLastWake else { return "--" }
        let hours = mins / 60
        let minutes = mins % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    var isWakeWindowExceeded: Bool {
        guard let mins = minutesSinceLastWake else { return false }
        return mins > targets.wakeWindowMinutes.upperBound
    }
}

// MARK: - Time Formatting

extension Date {
    func formatted(as style: Date.FormatStyle.TimeStyle) -> String {
        self.formatted(date: .omitted, time: style)
    }

    var shortTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: self)
    }
}
