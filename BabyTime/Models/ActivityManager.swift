//
//  ActivityManager.swift
//  BabyTime
//
//  Observable data manager for activity state and nursing timer.
//

import Foundation
import SwiftUI

@Observable
final class ActivityManager {

    // MARK: - Scenario Data (mutable copies)

    var baby: Baby
    var targets: AgeTargets
    private(set) var feeds: [FeedActivity]
    private(set) var sleeps: [SleepActivity]
    var currentTime: Date

    // MARK: - Nursing Timer State

    private(set) var isNursingActive: Bool = false
    var nursingStartTime: Date?
    var nursingEndTime: Date?

    // MARK: - Sleep Timer State

    private(set) var isSleepActive: Bool = false
    var sleepStartTime: Date?
    var sleepEndTime: Date?

    // MARK: - Init

    init(scenario: Scenario = .preview) {
        self.baby = scenario.baby
        self.targets = scenario.targets
        self.feeds = scenario.today.feeds
        self.sleeps = scenario.today.sleeps
        self.currentTime = scenario.currentTime
    }

    // MARK: - Nursing Timer Actions

    func startNursing() {
        nursingStartTime = Date()
        nursingEndTime = nil
        isNursingActive = true
    }

    func stopNursing() {
        nursingEndTime = Date()
        isNursingActive = false
    }

    func resetNursing() {
        nursingStartTime = nil
        nursingEndTime = nil
        isNursingActive = false
    }

    func saveNursing() {
        guard let start = nursingStartTime else { return }
        let end = nursingEndTime ?? Date()
        let durationMinutes = max(1, Int(end.timeIntervalSince(start) / 60))

        let feed = FeedActivity(
            id: UUID(),
            startTime: start,
            type: .nursing(side: .both, durationMinutes: durationMinutes)
        )
        feeds.append(feed)
        currentTime = Date()
        resetNursing()
    }

    // MARK: - Bottle Actions

    func saveBottle(amountOz: Double) {
        let feed = FeedActivity(
            id: UUID(),
            startTime: Date(),
            type: .bottle(source: .formula, amountOz: amountOz)
        )
        feeds.append(feed)
        currentTime = Date()
    }

    // MARK: - Sleep Timer Actions

    func startSleep() {
        sleepStartTime = Date()
        sleepEndTime = nil
        isSleepActive = true
    }

    func stopSleep() {
        sleepEndTime = Date()
        isSleepActive = false
    }

    func resetSleep() {
        sleepStartTime = nil
        sleepEndTime = nil
        isSleepActive = false
    }

    func saveSleep() {
        guard let start = sleepStartTime else { return }
        let end = sleepEndTime ?? Date()

        let sleep = SleepActivity(
            id: UUID(),
            startTime: start,
            endTime: end
        )
        sleeps.append(sleep)
        currentTime = Date()
        resetSleep()
    }

    // MARK: - Sleep Display Helpers

    var sleepElapsedSeconds: TimeInterval {
        guard let start = sleepStartTime else { return 0 }
        if let end = sleepEndTime {
            return end.timeIntervalSince(start)
        }
        return Date().timeIntervalSince(start)
    }

    var hasSleepSession: Bool {
        sleepStartTime != nil
    }

    func sleepTimerString(at date: Date = Date()) -> String {
        guard let start = sleepStartTime else { return "00:00" }
        let reference = sleepEndTime ?? date
        let elapsed = max(0, reference.timeIntervalSince(start))
        let minutes = Int(elapsed) / 60
        let seconds = Int(elapsed) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    // MARK: - Nursing Display Helpers

    /// Elapsed seconds since nursing started (for live timer display)
    var nursingElapsedSeconds: TimeInterval {
        guard let start = nursingStartTime else { return 0 }
        if let end = nursingEndTime {
            return end.timeIntervalSince(start)
        }
        return Date().timeIntervalSince(start)
    }

    /// Whether the timer has been started (active or stopped but not reset/saved)
    var hasNursingSession: Bool {
        nursingStartTime != nil
    }

    /// Formatted elapsed time "MM:SS"
    func nursingTimerString(at date: Date = Date()) -> String {
        guard let start = nursingStartTime else { return "00:00" }
        let reference = nursingEndTime ?? date
        let elapsed = max(0, reference.timeIntervalSince(start))
        let minutes = Int(elapsed) / 60
        let seconds = Int(elapsed) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    // MARK: - Computed Helpers (mirror Scenario extension)

    var lastFeed: FeedActivity? {
        feeds.max(by: { $0.startTime < $1.startTime })
    }

    var lastSleep: SleepActivity? {
        sleeps.max(by: { $0.endTime < $1.endTime })
    }

    var minutesSinceLastFeed: Int? {
        guard let feed = lastFeed else { return nil }
        return Int(currentTime.timeIntervalSince(feed.startTime) / 60)
    }

    var minutesSinceLastWake: Int? {
        guard let sleep = lastSleep else { return nil }
        return Int(currentTime.timeIntervalSince(sleep.endTime) / 60)
    }

    var feedCount: Int { feeds.count }
    var napCount: Int { sleeps.count }

    var totalIntakeOz: Double {
        feeds.reduce(0) { total, feed in
            total + feed.type.estimatedOz(for: baby.ageBracket)
        }
    }

    var totalSleepMinutes: Int {
        sleeps.reduce(0) { $0 + $1.durationMinutes }
    }

    var longestSleepMinutes: Int {
        sleeps.map(\.durationMinutes).max() ?? 0
    }

    // MARK: - Formatted Strings

    var wakeWindowFormatted: String {
        guard let mins = minutesSinceLastWake else { return "--" }
        let hours = mins / 60
        let minutes = mins % 60
        return hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m"
    }

    var lastSleepTimeFormatted: String {
        lastSleep?.endTime.shortTime ?? "--"
    }

    var lastSleepDurationFormatted: String {
        lastSleep?.durationDescription ?? "--"
    }

    var totalSleepFormatted: String {
        let hours = totalSleepMinutes / 60
        let mins = totalSleepMinutes % 60
        return hours > 0 ? "\(hours)h \(mins)m" : "\(mins)m"
    }

    var longestSleepFormatted: String {
        let mins = longestSleepMinutes
        guard mins > 0 else { return "--" }
        let hours = mins / 60
        let remaining = mins % 60
        return hours > 0 ? "\(hours)h \(remaining)m" : "\(mins)m"
    }

    var totalOzFormatted: String {
        "\(Int(totalIntakeOz)) oz"
    }

    var averageOzFormatted: String {
        guard feedCount > 0 else { return "--" }
        let avg = totalIntakeOz / Double(feedCount)
        return String(format: "%.1f oz", avg)
    }

    var dateDisplayString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: currentTime)
    }

    var ageDisplayString: String {
        let days = Calendar.current.dateComponents([.day], from: baby.birthdate, to: currentTime).day ?? 0
        let months = days / 30
        if months > 0 {
            return "\(months) month\(months == 1 ? "" : "s") old"
        }
        return "\(days) day\(days == 1 ? "" : "s") old"
    }

    // Feed recommendation helpers

    var totalDailyFeeds: Int { 7 }

    var remainingFeeds: Int {
        max(1, totalDailyFeeds - feedCount)
    }

    var remainingOz: Double {
        let midpoint = Double(targets.dailyIntakeOz.lowerBound + targets.dailyIntakeOz.upperBound) / 2
        return max(0, midpoint - totalIntakeOz)
    }

    var offerAmountOz: Int {
        let amount = remainingOz / Double(remainingFeeds)
        return max(1, Int(amount.rounded()))
    }

    var nextFeedTimeFormatted: String {
        guard let feed = lastFeed else { return "--" }
        let midpointInterval = Double(targets.feedIntervalMinutes.lowerBound + targets.feedIntervalMinutes.upperBound) / 2
        let nextTime = feed.startTime.addingTimeInterval(midpointInterval * 60)
        return nextTime.shortTime
    }

    var lastFeedOzFormatted: String {
        guard let feed = lastFeed else { return "--" }
        switch feed.type {
        case .bottle(_, let oz): return "\(Int(oz)) oz"
        case .nursing(_, let mins): return "\(mins) min"
        }
    }

    var timeSinceLastFeedDuration: String {
        guard let mins = minutesSinceLastFeed else { return "--" }
        let hours = mins / 60
        let minutes = mins % 60
        return hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m"
    }
}
