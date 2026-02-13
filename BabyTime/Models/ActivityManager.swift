//
//  ActivityManager.swift
//  BabyTime
//
//  Observable data manager bridging SwiftData ↔ DayEngine ↔ Views.
//  Persists active timers immediately for multi-device sync + crash recovery.
//

import Foundation
import SwiftUI
import SwiftData

@Observable
final class ActivityManager {

    // MARK: - Core State

    private(set) var modelContext: ModelContext
    private(set) var baby: Baby?
    private(set) var allBabies: [Baby] = []

    // MARK: - Derived State

    private(set) var snapshot: DaySnapshot?
    private(set) var todayFeeds: [FeedEvent] = []
    private(set) var todaySleeps: [SleepEvent] = []

    // MARK: - Active Event References

    /// Active nursing event (persisted in SwiftData, endTime == nil)
    private(set) var activeNursingEvent: FeedEvent?

    /// Active sleep event (persisted in SwiftData, endTime == nil)
    private(set) var activeSleepEvent: SleepEvent?

    // MARK: - Init

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        loadBabies()
    }

    // MARK: - Baby Management

    func selectBaby(_ baby: Baby) {
        self.baby = baby
        recoverActiveEvents()
        refresh()
    }

    @discardableResult
    func addBaby(
        name: String,
        birthdate: Date,
        bedtimeHour: Int = 19,
        bedtimeMinute: Int = 0,
        dreamFeedEnabled: Bool = false,
        dreamFeedHour: Int = 22,
        dreamFeedMinute: Int = 0
    ) -> Baby {
        let baby = Baby(
            name: name,
            birthdate: birthdate,
            bedtimeHour: bedtimeHour,
            bedtimeMinute: bedtimeMinute,
            dreamFeedEnabled: dreamFeedEnabled,
            dreamFeedHour: dreamFeedHour,
            dreamFeedMinute: dreamFeedMinute
        )
        modelContext.insert(baby)
        save()
        loadBabies()
        return baby
    }

    func deleteBaby(_ baby: Baby) {
        let wasSelected = self.baby?.stableID == baby.stableID
        modelContext.delete(baby)
        save()
        loadBabies()
        if wasSelected {
            self.baby = allBabies.first
            recoverActiveEvents()
            refresh()
        }
    }

    // MARK: - Data Loading

    func loadBabies() {
        let descriptor = FetchDescriptor<Baby>(sortBy: [SortDescriptor(\.createdAt)])
        allBabies = (try? modelContext.fetch(descriptor)) ?? []
    }

    func refresh() {
        loadTodayEvents()
        computeSnapshot()
    }

    private func loadTodayEvents() {
        guard let baby else {
            todayFeeds = []
            todaySleeps = []
            return
        }

        let startOfDay = Calendar.current.startOfDay(for: Date())

        let allFeeds = baby.feedEvents ?? []
        todayFeeds = allFeeds
            .filter { $0.startTime >= startOfDay }
            .sorted { $0.startTime < $1.startTime }

        let allSleeps = baby.sleepEvents ?? []
        todaySleeps = allSleeps
            .filter { $0.startTime >= startOfDay }
            .sorted { $0.startTime < $1.startTime }
    }

    private func computeSnapshot() {
        guard let baby else {
            snapshot = nil
            return
        }
        snapshot = DayEngine.snapshot(
            baby: baby,
            feeds: todayFeeds,
            sleeps: todaySleeps,
            now: Date()
        )
    }

    /// Recover in-progress events after app launch or baby switch
    private func recoverActiveEvents() {
        guard let baby else {
            activeNursingEvent = nil
            activeSleepEvent = nil
            return
        }

        let feeds = baby.feedEvents ?? []
        activeNursingEvent = feeds.first { $0.kind == .nursing && $0.isActive }

        let sleeps = baby.sleepEvents ?? []
        activeSleepEvent = sleeps.first { $0.isActive }
    }

    // MARK: - Nursing Actions

    func startNursing(side: NursingSide = .both) {
        guard let baby else { return }
        let event = FeedEvent(
            startTime: Date(),
            kind: .nursing,
            side: side,
            baby: baby
        )
        modelContext.insert(event)
        save()
        activeNursingEvent = event
        refresh()
    }

    func stopNursing() {
        guard let event = activeNursingEvent, event.isActive else { return }
        event.endTime = Date()
        save()
        refresh()
    }

    func resetNursing() {
        if let event = activeNursingEvent {
            modelContext.delete(event)
            save()
        }
        activeNursingEvent = nil
        refresh()
    }

    func saveNursing() {
        if let event = activeNursingEvent, event.isActive {
            event.endTime = Date()
            save()
        }
        activeNursingEvent = nil
        refresh()
    }

    // MARK: - Bottle Actions

    func saveBottle(amountOz: Double, source: BottleSource = .breastMilk, at time: Date = Date()) {
        guard let baby else { return }
        let event = FeedEvent(
            startTime: time,
            endTime: time,
            kind: .bottle,
            source: source,
            amountOz: amountOz,
            baby: baby
        )
        modelContext.insert(event)
        save()
        refresh()
    }

    // MARK: - Sleep Actions

    func startSleep(at startTime: Date? = nil) {
        guard let baby else { return }
        let event = SleepEvent(startTime: startTime ?? Date(), baby: baby)
        modelContext.insert(event)
        save()
        activeSleepEvent = event
        refresh()
    }

    func resumeSleep() {
        guard let event = activeSleepEvent else { return }
        event.endTime = nil
        save()
        refresh()
    }

    func stopSleep() {
        guard let event = activeSleepEvent, event.isActive else { return }
        event.endTime = Date()
        save()
        refresh()
    }

    func resetSleep() {
        if let event = activeSleepEvent {
            modelContext.delete(event)
            save()
        }
        activeSleepEvent = nil
        refresh()
    }

    func saveSleep() {
        if let event = activeSleepEvent, event.isActive {
            event.endTime = Date()
            save()
        }
        activeSleepEvent = nil
        refresh()
    }

    func saveSleepManual(startTime: Date, endTime: Date) {
        guard let baby else { return }
        let event = SleepEvent(startTime: startTime, endTime: endTime, baby: baby)
        modelContext.insert(event)
        save()
        activeSleepEvent = nil
        refresh()
    }

    // MARK: - Persistence

    private func save() {
        try? modelContext.save()
    }

    // MARK: - Nursing State (API compatibility with sheet views)

    var isNursingActive: Bool {
        activeNursingEvent != nil && activeNursingEvent?.endTime == nil
    }

    var hasNursingSession: Bool {
        activeNursingEvent != nil
    }

    var nursingStartTime: Date? {
        get { activeNursingEvent?.startTime }
        set { if let v = newValue { activeNursingEvent?.startTime = v } }
    }

    var nursingEndTime: Date? {
        get { activeNursingEvent?.endTime }
        set { activeNursingEvent?.endTime = newValue }
    }

    // MARK: - Sleep State (API compatibility with sheet views)

    var isSleepActive: Bool {
        activeSleepEvent != nil && activeSleepEvent?.endTime == nil
    }

    var hasSleepSession: Bool {
        activeSleepEvent != nil
    }

    var sleepStartTime: Date? {
        get { activeSleepEvent?.startTime }
        set { if let v = newValue { activeSleepEvent?.startTime = v } }
    }

    var sleepEndTime: Date? {
        get { activeSleepEvent?.endTime }
        set { activeSleepEvent?.endTime = newValue }
    }

    // MARK: - Timer Display Helpers

    func nursingTimerString(at date: Date = Date()) -> String {
        guard let start = nursingStartTime else { return "00:00" }
        let reference = nursingEndTime ?? date
        let elapsed = max(0, reference.timeIntervalSince(start))
        let minutes = Int(elapsed) / 60
        let seconds = Int(elapsed) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    func sleepTimerString(at date: Date = Date()) -> String {
        guard let start = sleepStartTime else { return "00:00" }
        let reference = sleepEndTime ?? date
        let elapsed = max(0, reference.timeIntervalSince(start))
        let minutes = Int(elapsed) / 60
        let seconds = Int(elapsed) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    // MARK: - Formatted Display Helpers

    var dateDisplayString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: Date())
    }

    var ageDisplayString: String {
        baby?.ageDescription ?? ""
    }

    var babyName: String {
        baby?.name ?? ""
    }

    var feedCount: Int { todayFeeds.count }
    var napCount: Int { todaySleeps.filter({ $0.endTime != nil }).count }

    var totalIntakeOz: Double {
        guard let baby else { return 0 }
        let table = AgeTable.forAge(days: baby.ageInDays)
        return todayFeeds.reduce(0) { $0 + $1.estimatedOz(nursingOzPerMinute: table.nursingOzPerMinute) }
    }

    var totalSleepMinutes: Int {
        todaySleeps.compactMap(\.durationMinutes).reduce(0, +)
    }

    var longestSleepMinutes: Int {
        todaySleeps.compactMap(\.durationMinutes).max() ?? 0
    }

    // MARK: - Feed Recommendation Helpers

    var lastFeed: FeedEvent? {
        todayFeeds.last
    }

    var lastSleep: SleepEvent? {
        todaySleeps.filter({ $0.endTime != nil }).last
    }

    var minutesSinceLastFeed: Int? {
        guard let feed = lastFeed else { return nil }
        return Int(Date().timeIntervalSince(feed.startTime) / 60)
    }

    var minutesSinceLastWake: Int? {
        guard let sleep = lastSleep, let endTime = sleep.endTime else { return nil }
        return Int(Date().timeIntervalSince(endTime) / 60)
    }

    var totalDailyFeeds: Int { 7 }

    var remainingFeeds: Int {
        max(1, totalDailyFeeds - feedCount)
    }

    var remainingOz: Double {
        guard let baby else { return 0 }
        let table = AgeTable.forAge(days: baby.ageInDays)
        let midpoint = Double(table.dailyIntakeOz.lowerBound + table.dailyIntakeOz.upperBound) / 2
        return max(0, midpoint - totalIntakeOz)
    }

    var offerAmountOz: Int {
        let amount = remainingOz / Double(remainingFeeds)
        return max(1, Int(amount.rounded()))
    }

    var nextFeedTimeFormatted: String {
        guard let feed = lastFeed, let baby else { return "--" }
        let table = AgeTable.forAge(days: baby.ageInDays)
        let midpoint = Double(table.feedIntervalMinutes.lowerBound + table.feedIntervalMinutes.upperBound) / 2
        let nextTime = feed.startTime.addingTimeInterval(midpoint * 60)
        return nextTime.shortTime
    }

    var lastFeedOzFormatted: String {
        guard let feed = lastFeed else { return "--" }
        return feed.shortDescription
    }

    var timeSinceLastFeedDuration: String {
        guard let mins = minutesSinceLastFeed else { return "--" }
        let hours = mins / 60
        let minutes = mins % 60
        return hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m"
    }

    var wakeWindowFormatted: String {
        guard let mins = minutesSinceLastWake else { return "--" }
        let hours = mins / 60
        let minutes = mins % 60
        return hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m"
    }

    var lastSleepTimeFormatted: String {
        lastSleep?.endTime?.shortTime ?? "--"
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
}
