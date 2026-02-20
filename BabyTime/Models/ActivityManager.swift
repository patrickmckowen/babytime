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
import UserNotifications

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
    private(set) var todayWakeEvent: WakeEvent?

    // MARK: - Active Event References

    /// Active nursing event. Updated from data on every refresh() cycle,
    /// so external writes (from another device via CloudKit) are discovered
    /// automatically when the app returns to foreground.
    private(set) var activeNursingEvent: FeedEvent?

    /// Active sleep event (nap only, not nighttime sleep).
    private(set) var activeSleepEvent: SleepEvent?

    // MARK: - Init

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        loadBabies()
    }

    // MARK: - Baby Management

    func selectBaby(_ baby: Baby) {
        self.baby = baby
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
        dreamFeedMinute: Int = 0,
        photoData: Data? = nil
    ) -> Baby {
        let baby = Baby(
            name: name,
            birthdate: birthdate,
            bedtimeHour: bedtimeHour,
            bedtimeMinute: bedtimeMinute,
            dreamFeedEnabled: dreamFeedEnabled,
            dreamFeedHour: dreamFeedHour,
            dreamFeedMinute: dreamFeedMinute,
            photoData: photoData
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
            refresh()
        }
    }

    // MARK: - Data Loading

    func loadBabies() {
        let descriptor = FetchDescriptor<Baby>(sortBy: [SortDescriptor(\.createdAt)])
        allBabies = (try? modelContext.fetch(descriptor)) ?? []
    }

    func refresh() {
        autoCloseStaleEvents()
        syncActiveEvents()
        loadTodayEvents()
        computeSnapshot()
        scheduleNotifications()
    }

    /// Discover active events from the full relationship, including events
    /// created by other devices via CloudKit sync. Called every refresh cycle.
    /// Only scans when no event is currently tracked — stopped events are
    /// preserved until the user explicitly saves or resets them.
    private func syncActiveEvents() {
        guard let baby else {
            activeNursingEvent = nil
            activeSleepEvent = nil
            return
        }

        if activeNursingEvent == nil {
            let feeds = baby.feedEvents ?? []
            activeNursingEvent = feeds.first { $0.kind == .nursing && $0.isActive }
        }

        if activeSleepEvent == nil {
            let sleeps = baby.sleepEvents ?? []
            activeSleepEvent = sleeps.first { $0.isActive && !$0.isNightSleep }
        }
    }

    private func scheduleNotifications() {
        guard let snapshot, let baby else {
            UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
            return
        }
        let triggers = NotificationScheduler.triggers(from: snapshot, baby: baby, now: Date())
        NotificationManager.reschedule(triggers)
    }

    private func loadTodayEvents() {
        guard let baby else {
            todayFeeds = []
            todaySleeps = []
            todayWakeEvent = nil
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

        let allWakes = baby.wakeEvents ?? []
        todayWakeEvent = allWakes.first { $0.date == startOfDay }
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
            wakeTime: todayWakeEvent?.time,
            now: Date()
        )
    }

    /// Auto-close stale events and resolve multi-writer conflicts.
    /// Called on baby selection and refresh to clean up data from any source.
    private func autoCloseStaleEvents() {
        guard let baby else { return }

        let sleeps = baby.sleepEvents ?? []
        let startOfDay = Calendar.current.startOfDay(for: Date())

        // Close overnight night sleeps from previous days
        for sleep in sleeps where sleep.isNightSleep && sleep.isActive && sleep.startTime < startOfDay {
            sleep.endTime = startOfDay
        }

        // Auto-resolve feed conflicts: keep earliest active nursing, close later ones
        let activeNursings = (baby.feedEvents ?? [])
            .filter { $0.kind == .nursing && $0.isActive }
            .sorted { $0.startTime < $1.startTime }
        for event in activeNursings.dropFirst() {
            event.endTime = event.startTime
        }

        // Auto-resolve sleep conflicts: keep earliest active nap, close later ones
        let activeNaps = sleeps
            .filter { $0.isActive && !$0.isNightSleep }
            .sorted { $0.startTime < $1.startTime }
        for event in activeNaps.dropFirst() {
            event.endTime = event.startTime
        }

        if !activeNursings.dropFirst().isEmpty || !activeNaps.dropFirst().isEmpty {
            save()
        }
    }

    // MARK: - Nursing Actions

    func startNursing(at startTime: Date? = nil, side: NursingSide = .both) {
        guard let baby else { return }
        let event = FeedEvent(
            startTime: startTime ?? Date(),
            kind: .nursing,
            side: side,
            baby: baby
        )
        modelContext.insert(event)
        save()
        activeNursingEvent = event
        refresh()
    }

    func resumeNursing() {
        guard let event = activeNursingEvent else { return }
        event.endTime = nil
        save()
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
        guard let event = activeNursingEvent else { return }
        if event.isActive {
            event.endTime = Date()
        }
        save()
        activeNursingEvent = nil
        refresh()
    }

    func saveNursingManual(startTime: Date, endTime: Date) {
        guard let baby else { return }
        let event = FeedEvent(
            startTime: startTime,
            endTime: endTime,
            kind: .nursing,
            side: .both,
            baby: baby
        )
        modelContext.insert(event)
        save()
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
        guard let event = activeSleepEvent else { return }
        if event.isActive {
            event.endTime = Date()
        }
        save()
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

    // MARK: - Event Queries (all history)

    func allFeedEvents() -> [FeedEvent] {
        guard let baby else { return [] }
        return (baby.feedEvents ?? []).sorted { $0.startTime > $1.startTime }
    }

    func allSleepEvents() -> [SleepEvent] {
        guard let baby else { return [] }
        return (baby.sleepEvents ?? []).sorted { $0.startTime > $1.startTime }
    }

    // MARK: - Event Queries (day-scoped)

    func feedEvents(for date: Date) -> [FeedEvent] {
        guard let baby else { return [] }
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return [] }
        return (baby.feedEvents ?? [])
            .filter { $0.startTime >= start && $0.startTime < end }
            .sorted { $0.startTime < $1.startTime }
    }

    func sleepEvents(for date: Date) -> [SleepEvent] {
        guard let baby else { return [] }
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return [] }
        return (baby.sleepEvents ?? [])
            .filter { !$0.isNightSleep && $0.startTime >= start && $0.startTime < end }
            .sorted { $0.startTime < $1.startTime }
    }

    func wakeEvent(for date: Date) -> WakeEvent? {
        guard let baby else { return nil }
        let startOfDay = Calendar.current.startOfDay(for: date)
        return (baby.wakeEvents ?? []).first { $0.date == startOfDay }
    }

    func nightSleep(for date: Date) -> SleepEvent? {
        guard let baby else { return nil }
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return nil }
        return (baby.sleepEvents ?? [])
            .first { $0.isNightSleep && $0.startTime >= start && $0.startTime < end }
    }

    func daysWithEvents() -> [Date] {
        guard let baby else { return [] }
        let calendar = Calendar.current
        var days = Set<Date>()
        for event in baby.feedEvents ?? [] {
            days.insert(calendar.startOfDay(for: event.startTime))
        }
        for event in baby.sleepEvents ?? [] {
            days.insert(calendar.startOfDay(for: event.startTime))
        }
        return days.sorted(by: >)
    }

    // MARK: - Delete Events

    func deleteFeedEvent(_ event: FeedEvent) {
        if activeNursingEvent === event {
            activeNursingEvent = nil
        }
        modelContext.delete(event)
        save()
        refresh()
    }

    func deleteSleepEvent(_ event: SleepEvent) {
        if activeSleepEvent === event {
            activeSleepEvent = nil
        }
        modelContext.delete(event)
        save()
        refresh()
    }

    // MARK: - Update Events

    func updateFeedEvent(_ event: FeedEvent, amountOz: Double, at time: Date) {
        event.startTime = time
        event.endTime = time
        event.amountOz = amountOz
        save()
        refresh()
    }

    func updateNursingEvent(_ event: FeedEvent, startTime: Date, endTime: Date, side: NursingSide) {
        event.startTime = startTime
        event.endTime = endTime
        event.side = side
        save()
        refresh()
    }

    func updateSleepEvent(_ event: SleepEvent, startTime: Date, endTime: Date) {
        event.startTime = startTime
        event.endTime = endTime
        save()
        refresh()
    }

    // MARK: - Wake Time Actions

    func setWakeTime(_ time: Date) {
        guard let baby else { return }
        let startOfDay = Calendar.current.startOfDay(for: Date())

        if let existing = todayWakeEvent {
            // Upsert: update existing wake event for today
            existing.time = time
        } else {
            // Create new wake event
            let event = WakeEvent(date: startOfDay, time: time, baby: baby)
            modelContext.insert(event)
        }
        save()
        refresh()
    }

    var hasWakeTime: Bool {
        todayWakeEvent != nil
    }

    var wakeTimeFormatted: String {
        todayWakeEvent?.time.shortTime ?? "--"
    }

    // MARK: - Bedtime Actions

    func logBedtime(_ time: Date) {
        guard let baby else { return }
        let event = SleepEvent(startTime: time, isNightSleep: true, baby: baby)
        modelContext.insert(event)
        save()
        refresh()
    }

    func updateBedtime(_ time: Date) {
        guard let nightSleep = todayNightSleep else { return }
        nightSleep.startTime = time
        save()
        refresh()
    }

    var todayNightSleep: SleepEvent? {
        todaySleeps.first { $0.isNightSleep }
    }

    var actualBedtimeFormatted: String? {
        todayNightSleep?.startTime.shortTime
    }

    var isAsleepForNight: Bool {
        todayNightSleep != nil
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

        let reference: Date
        if isNursingActive {
            reference = date              // live ticking
        } else if let end = nursingEndTime {
            reference = end               // static stopped duration
        } else {
            return "00:00"                // no valid state
        }

        let elapsed = max(0, reference.timeIntervalSince(start))
        let minutes = Int(elapsed) / 60
        let seconds = Int(elapsed) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    func sleepTimerString(at date: Date = Date()) -> String {
        guard let start = sleepStartTime else { return "00:00" }

        let reference: Date
        if isSleepActive {
            reference = date
        } else if let end = sleepEndTime {
            reference = end
        } else {
            return "00:00"
        }

        let elapsed = max(0, reference.timeIntervalSince(start))
        let minutes = Int(elapsed) / 60
        let seconds = Int(elapsed) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    func nursingTimerMinutesString(at date: Date = Date()) -> String {
        guard let start = nursingStartTime else { return "" }

        let reference: Date
        if isNursingActive {
            reference = date
        } else if let end = nursingEndTime {
            reference = end
        } else {
            return ""
        }

        let elapsed = max(0, reference.timeIntervalSince(start))
        let totalMinutes = Int(elapsed) / 60
        if totalMinutes == 0 { return "" }
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(totalMinutes)m"
    }

    func sleepTimerMinutesString(at date: Date = Date()) -> String {
        guard let start = sleepStartTime else { return "" }

        let reference: Date
        if isSleepActive {
            reference = date
        } else if let end = sleepEndTime {
            reference = end
        } else {
            return ""
        }

        let elapsed = max(0, reference.timeIntervalSince(start))
        let totalMinutes = Int(elapsed) / 60
        if totalMinutes == 0 { return "" }
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(totalMinutes)m"
    }

    // MARK: - Formatted Display Helpers

    var dateDisplayString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: Date())
    }

    var shortDateDisplayString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: Date())
    }

    var dayOfWeekString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: Date())
    }

    var ageDisplayString: String {
        baby?.ageDescription ?? ""
    }

    var babyName: String {
        baby?.name ?? ""
    }

    var bedtimeFormatted: String? {
        baby?.bedtimeToday().shortTime
    }

    var dreamFeedEnabled: Bool {
        baby?.dreamFeedEnabled ?? false
    }

    var dreamFeedTimeFormatted: String? {
        guard let baby, baby.dreamFeedEnabled else { return nil }
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = baby.dreamFeedHour
        components.minute = baby.dreamFeedMinute
        return Calendar.current.date(from: components)?.shortTime
    }

    var babyPhotoData: Data? {
        baby?.photoData
    }

    func setBabyPhoto(_ data: Data?) {
        baby?.photoData = data
        save()
    }

    var feedCount: Int { todayFeeds.count }
    var napCount: Int { todaySleeps.filter({ $0.endTime != nil }).count }

    var totalIntakeOz: Double {
        guard let baby else { return 0 }
        let table = AgeTable.forAge(days: baby.ageInDays)
        return todayFeeds.reduce(0) { $0 + $1.estimatedOz(nursingOzPerMinute: table.nursingOzPerMinute(at: $1.startTime, ageInDays: baby.ageInDays)) }
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

    var totalDailyFeeds: Int {
        guard let baby else { return 7 }
        let table = AgeTable.forAge(days: baby.ageInDays)
        let range = table.expectedFeedsPerDay
        return (range.lowerBound + range.upperBound) / 2
    }

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
        return max(1, min(6, Int(amount.rounded())))
    }

    var nextFeedTimeFormatted: String {
        guard let feed = lastFeed, let baby else { return "--" }
        let intervalMinutes = Double(baby.effectiveFeedIntervalMinutes)
        let nextTime = feed.startTime.addingTimeInterval(intervalMinutes * 60)
        if nextTime <= Date() {
            return "Now"
        }
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
