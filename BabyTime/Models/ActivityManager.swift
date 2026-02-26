//
//  ActivityManager.swift
//  BabyTime
//
//  Observable data manager bridging SQLiteData ↔ DayEngine ↔ Views.
//  Persists active timers immediately for multi-device sync + crash recovery.
//

import Foundation
import SwiftUI
import SQLiteData
import UserNotifications

@Observable
final class ActivityManager {

    // MARK: - Core State

    private let database: any DatabaseWriter
    private(set) var baby: Baby?
    private(set) var allBabies: [Baby] = []

    // MARK: - Derived State

    private(set) var snapshot: DaySnapshot?
    private(set) var todayFeeds: [FeedEvent] = []
    private(set) var todaySleeps: [SleepEvent] = []
    private(set) var todayWakeEvent: WakeEvent?

    // MARK: - Active Event References

    private(set) var activeNursingEvent: FeedEvent?
    private(set) var activeSleepEvent: SleepEvent?

    // MARK: - Init

    init(database: any DatabaseWriter) {
        self.database = database
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
            id: UUID(),
            stableID: UUID().uuidString,
            name: name,
            birthdate: birthdate,
            bedtimeHour: bedtimeHour,
            bedtimeMinute: bedtimeMinute,
            dreamFeedEnabled: dreamFeedEnabled,
            dreamFeedHour: dreamFeedHour,
            dreamFeedMinute: dreamFeedMinute,
            photoData: photoData,
            createdAt: Date()
        )
        try? database.write { db in
            try Baby.insert { baby }.execute(db)
        }
        loadBabies()
        return baby
    }

    func deleteBaby(_ baby: Baby) {
        let wasSelected = self.baby?.stableID == baby.stableID
        try? database.write { db in
            try Baby.find(baby.id).delete().execute(db)
        }
        loadBabies()
        if wasSelected {
            self.baby = allBabies.first
            refresh()
        }
    }

    // MARK: - Data Loading

    func loadBabies() {
        allBabies = (try? database.read { db in
            try Baby.order { $0.createdAt.asc() }.fetchAll(db)
        }) ?? []
    }

    func refresh() {
        autoCloseStaleEvents()
        syncActiveEvents()
        loadTodayEvents()
        computeSnapshot()
        scheduleNotifications()
    }

    private func syncActiveEvents() {
        guard let baby else {
            activeNursingEvent = nil
            activeSleepEvent = nil
            return
        }

        if activeNursingEvent == nil {
            activeNursingEvent = try? database.read { db in
                try FeedEvent
                    .where { $0.babyID.eq(#bind(baby.id)) && $0.endTime.is(nil) && $0.feedKind.eq(#bind(FeedKind.nursing)) }
                    .fetchOne(db)
            }
        }

        if activeSleepEvent == nil {
            activeSleepEvent = try? database.read { db in
                try SleepEvent
                    .where { $0.babyID.eq(#bind(baby.id)) && $0.endTime.is(nil) && $0.isNightSleep.eq(false) }
                    .fetchOne(db)
            }
        }
    }

    private func scheduleNotifications() {
        guard let snapshot, let baby else {
            UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
            return
        }
        let prefix = "\(baby.id.uuidString.prefix(8))-"
        let triggers = NotificationScheduler.triggers(from: snapshot, baby: baby, now: Date(), idPrefix: prefix)
        NotificationManager.reschedule(triggers, removingPrefix: prefix)
    }

    private func loadTodayEvents() {
        guard let baby else {
            todayFeeds = []
            todaySleeps = []
            todayWakeEvent = nil
            return
        }

        let startOfDay = Calendar.current.startOfDay(for: Date())

        todayFeeds = (try? database.read { db in
            try FeedEvent
                .where { $0.babyID.eq(#bind(baby.id)) && $0.startTime >= #bind(startOfDay) }
                .order { $0.startTime.asc() }
                .fetchAll(db)
        }) ?? []

        todaySleeps = (try? database.read { db in
            try SleepEvent
                .where { $0.babyID.eq(#bind(baby.id)) && $0.startTime >= #bind(startOfDay) }
                .order { $0.startTime.asc() }
                .fetchAll(db)
        }) ?? []

        todayWakeEvent = try? database.read { db in
            try WakeEvent
                .where { $0.babyID.eq(#bind(baby.id)) && $0.date.eq(#bind(startOfDay)) }
                .fetchOne(db)
        }
    }

    private func computeSnapshot() {
        guard let baby else {
            snapshot = nil
            return
        }
        var sleeps = todaySleeps
        if let nightSleep = activeNightSleep,
           !sleeps.contains(where: { $0.id == nightSleep.id }) {
            sleeps.append(nightSleep)
        }
        if let completedNight = lastCompletedNightSleepEndedToday,
           !sleeps.contains(where: { $0.id == completedNight.id }) {
            sleeps.append(completedNight)
        }
        snapshot = DayEngine.snapshot(
            baby: baby,
            feeds: todayFeeds,
            sleeps: sleeps,
            wakeTime: todayWakeEvent?.time,
            now: Date()
        )
    }

    private func autoCloseStaleEvents() {
        guard let baby else { return }

        try? database.write { db in
            let staleThreshold = Date().addingTimeInterval(-48 * 60 * 60)
            let staleSleeps = try SleepEvent
                .where { $0.babyID.eq(#bind(baby.id)) && $0.isNightSleep.eq(true) && $0.endTime.is(nil) && $0.startTime < #bind(staleThreshold) }
                .fetchAll(db)
            for sleep in staleSleeps {
                let closeTime = sleep.startTime.addingTimeInterval(8 * 60 * 60)
                try SleepEvent.find(sleep.id)
                    .update { $0.endTime = #bind(closeTime) }
                    .execute(db)
            }

            let activeNursings = try FeedEvent
                .where { $0.babyID.eq(#bind(baby.id)) && $0.feedKind.eq(#bind(FeedKind.nursing)) && $0.endTime.is(nil) }
                .order { $0.startTime.asc() }
                .fetchAll(db)
            for event in activeNursings.dropFirst() {
                try FeedEvent.find(event.id)
                    .update { $0.endTime = #bind(event.startTime) }
                    .execute(db)
            }

            let activeNaps = try SleepEvent
                .where { $0.babyID.eq(#bind(baby.id)) && $0.isNightSleep.eq(false) && $0.endTime.is(nil) }
                .order { $0.startTime.asc() }
                .fetchAll(db)
            for nap in activeNaps.dropFirst() {
                try SleepEvent.find(nap.id)
                    .update { $0.endTime = #bind(nap.startTime) }
                    .execute(db)
            }
        }
    }

    // MARK: - Nursing Actions

    func startNursing(at startTime: Date? = nil, side: NursingSide = .both) {
        guard let baby else { return }
        let event = FeedEvent(
            id: UUID(),
            babyID: baby.id,
            startTime: startTime ?? Date(),
            feedKind: .nursing,
            nursingSide: side,
            caregiverName: DeviceIdentity.caregiverName,
            deviceID: DeviceIdentity.deviceID
        )
        try? database.write { db in
            try FeedEvent.insert { event }.execute(db)
        }
        activeNursingEvent = event
        refresh()
    }

    func resumeNursing() {
        guard let event = activeNursingEvent else { return }
        try? database.write { db in
            try FeedEvent.find(event.id)
                .update { $0.endTime = #bind(nil as Date?) }
                .execute(db)
        }
        activeNursingEvent?.endTime = nil
        refresh()
    }

    func stopNursing() {
        guard let event = activeNursingEvent, event.isActive else { return }
        let now = Date()
        try? database.write { db in
            try FeedEvent.find(event.id)
                .update { $0.endTime = #bind(now) }
                .execute(db)
        }
        activeNursingEvent?.endTime = now
        refresh()
    }

    func resetNursing() {
        if let event = activeNursingEvent {
            try? database.write { db in
                try FeedEvent.find(event.id).delete().execute(db)
            }
        }
        activeNursingEvent = nil
        refresh()
    }

    func saveNursing() {
        guard let event = activeNursingEvent else { return }
        if event.isActive {
            let now = Date()
            try? database.write { db in
                try FeedEvent.find(event.id)
                    .update { $0.endTime = #bind(now) }
                    .execute(db)
            }
        } else {
            // Persist any user edits to start/end times
            let startTime = event.startTime
            let endTime = event.endTime
            try? database.write { db in
                try FeedEvent.find(event.id)
                    .update {
                        $0.startTime = #bind(startTime)
                        $0.endTime = #bind(endTime)
                    }
                    .execute(db)
            }
        }
        activeNursingEvent = nil
        refresh()
    }

    func saveNursingManual(startTime: Date, endTime: Date) {
        guard let baby else { return }
        let event = FeedEvent(
            id: UUID(),
            babyID: baby.id,
            startTime: startTime,
            endTime: endTime,
            feedKind: .nursing,
            nursingSide: .both,
            caregiverName: DeviceIdentity.caregiverName,
            deviceID: DeviceIdentity.deviceID
        )
        try? database.write { db in
            try FeedEvent.insert { event }.execute(db)
        }
        activeNursingEvent = nil
        refresh()
    }

    // MARK: - Bottle Actions

    func saveBottle(amountOz: Double, source: BottleSource = .breastMilk, at time: Date = Date()) {
        guard let baby else { return }
        let event = FeedEvent(
            id: UUID(),
            babyID: baby.id,
            startTime: time,
            endTime: time,
            feedKind: .bottle,
            bottleSource: source,
            amountOz: amountOz,
            caregiverName: DeviceIdentity.caregiverName,
            deviceID: DeviceIdentity.deviceID
        )
        try? database.write { db in
            try FeedEvent.insert { event }.execute(db)
        }
        refresh()
    }

    // MARK: - Sleep Actions

    func startSleep(at startTime: Date? = nil) {
        guard let baby else { return }
        let event = SleepEvent(
            id: UUID(),
            babyID: baby.id,
            startTime: startTime ?? Date(),
            caregiverName: DeviceIdentity.caregiverName,
            deviceID: DeviceIdentity.deviceID
        )
        try? database.write { db in
            try SleepEvent.insert { event }.execute(db)
        }
        activeSleepEvent = event
        refresh()
    }

    func resumeSleep() {
        guard let event = activeSleepEvent else { return }
        try? database.write { db in
            try SleepEvent.find(event.id)
                .update { $0.endTime = #bind(nil as Date?) }
                .execute(db)
        }
        activeSleepEvent?.endTime = nil
        refresh()
    }

    func stopSleep() {
        guard let event = activeSleepEvent, event.isActive else { return }
        let now = Date()
        try? database.write { db in
            try SleepEvent.find(event.id)
                .update { $0.endTime = #bind(now) }
                .execute(db)
        }
        activeSleepEvent?.endTime = now
        refresh()
    }

    func resetSleep() {
        if let event = activeSleepEvent {
            try? database.write { db in
                try SleepEvent.find(event.id).delete().execute(db)
            }
        }
        activeSleepEvent = nil
        refresh()
    }

    func saveSleep() {
        guard let event = activeSleepEvent else { return }
        if event.isActive {
            let now = Date()
            try? database.write { db in
                try SleepEvent.find(event.id)
                    .update { $0.endTime = #bind(now) }
                    .execute(db)
            }
        } else {
            // Persist any user edits to start/end times
            let startTime = event.startTime
            let endTime = event.endTime
            try? database.write { db in
                try SleepEvent.find(event.id)
                    .update {
                        $0.startTime = #bind(startTime)
                        $0.endTime = #bind(endTime)
                    }
                    .execute(db)
            }
        }
        activeSleepEvent = nil
        refresh()
    }

    func saveSleepManual(startTime: Date, endTime: Date) {
        guard let baby else { return }
        let event = SleepEvent(
            id: UUID(),
            babyID: baby.id,
            startTime: startTime,
            endTime: endTime,
            caregiverName: DeviceIdentity.caregiverName,
            deviceID: DeviceIdentity.deviceID
        )
        try? database.write { db in
            try SleepEvent.insert { event }.execute(db)
        }
        activeSleepEvent = nil
        refresh()
    }

    // MARK: - Event Queries (all history)

    func allFeedEvents() -> [FeedEvent] {
        guard let baby else { return [] }
        return (try? database.read { db in
            try FeedEvent
                .where { $0.babyID.eq(#bind(baby.id)) }
                .order { $0.startTime.desc() }
                .fetchAll(db)
        }) ?? []
    }

    func allSleepEvents() -> [SleepEvent] {
        guard let baby else { return [] }
        return (try? database.read { db in
            try SleepEvent
                .where { $0.babyID.eq(#bind(baby.id)) }
                .order { $0.startTime.desc() }
                .fetchAll(db)
        }) ?? []
    }

    // MARK: - Event Queries (day-scoped)

    func feedEvents(for date: Date) -> [FeedEvent] {
        guard let baby else { return [] }
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return [] }
        return (try? database.read { db in
            try FeedEvent
                .where { $0.babyID.eq(#bind(baby.id)) && $0.startTime >= #bind(start) && $0.startTime < #bind(end) }
                .order { $0.startTime.asc() }
                .fetchAll(db)
        }) ?? []
    }

    func sleepEvents(for date: Date) -> [SleepEvent] {
        guard let baby else { return [] }
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return [] }
        return (try? database.read { db in
            try SleepEvent
                .where { $0.babyID.eq(#bind(baby.id)) && $0.isNightSleep.eq(false) && $0.startTime >= #bind(start) && $0.startTime < #bind(end) }
                .order { $0.startTime.asc() }
                .fetchAll(db)
        }) ?? []
    }

    func wakeEvent(for date: Date) -> WakeEvent? {
        guard let baby else { return nil }
        let startOfDay = Calendar.current.startOfDay(for: date)
        return try? database.read { db in
            try WakeEvent
                .where { $0.babyID.eq(#bind(baby.id)) && $0.date.eq(#bind(startOfDay)) }
                .fetchOne(db)
        }
    }

    func nightSleep(for date: Date) -> SleepEvent? {
        guard let baby else { return nil }
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return nil }
        return try? database.read { db in
            try SleepEvent
                .where { $0.babyID.eq(#bind(baby.id)) && $0.isNightSleep.eq(true) && $0.startTime >= #bind(start) && $0.startTime < #bind(end) }
                .fetchOne(db)
        }
    }

    func daysWithEvents() -> [Date] {
        guard let baby else { return [] }
        let calendar = Calendar.current
        let allFeeds = (try? database.read { db in
            try FeedEvent
                .where { $0.babyID.eq(#bind(baby.id)) }
                .fetchAll(db)
        }) ?? []
        let allSleeps = (try? database.read { db in
            try SleepEvent
                .where { $0.babyID.eq(#bind(baby.id)) }
                .fetchAll(db)
        }) ?? []
        var days = Set<Date>()
        for event in allFeeds {
            days.insert(calendar.startOfDay(for: event.startTime))
        }
        for event in allSleeps {
            days.insert(calendar.startOfDay(for: event.startTime))
        }
        return days.sorted(by: >)
    }

    // MARK: - Delete Events

    func deleteFeedEvent(_ event: FeedEvent) {
        if activeNursingEvent?.id == event.id {
            activeNursingEvent = nil
        }
        try? database.write { db in
            try FeedEvent.find(event.id).delete().execute(db)
        }
        refresh()
    }

    func deleteSleepEvent(_ event: SleepEvent) {
        if activeSleepEvent?.id == event.id {
            activeSleepEvent = nil
        }
        try? database.write { db in
            try SleepEvent.find(event.id).delete().execute(db)
        }
        refresh()
    }

    // MARK: - Update Events

    func updateFeedEvent(_ event: FeedEvent, amountOz: Double, at time: Date) {
        try? database.write { db in
            try FeedEvent.find(event.id)
                .update {
                    $0.startTime = #bind(time)
                    $0.endTime = #bind(time)
                    $0.amountOz = #bind(amountOz)
                }
                .execute(db)
        }
        refresh()
    }

    func updateNursingEvent(_ event: FeedEvent, startTime: Date, endTime: Date, side: NursingSide) {
        try? database.write { db in
            try FeedEvent.find(event.id)
                .update {
                    $0.startTime = #bind(startTime)
                    $0.endTime = #bind(endTime)
                    $0.nursingSide = #bind(side)
                }
                .execute(db)
        }
        refresh()
    }

    func updateSleepEvent(_ event: SleepEvent, startTime: Date, endTime: Date) {
        try? database.write { db in
            try SleepEvent.find(event.id)
                .update {
                    $0.startTime = #bind(startTime)
                    $0.endTime = #bind(endTime)
                }
                .execute(db)
        }
        refresh()
    }

    // MARK: - Wake Time Actions

    func setWakeTime(_ time: Date) {
        guard let baby else { return }
        let today = Calendar.current.startOfDay(for: time)

        try? database.write { db in
            let existing = try WakeEvent
                .where { $0.babyID.eq(#bind(baby.id)) && $0.date.eq(#bind(today)) }
                .fetchOne(db)

            if let existing {
                try WakeEvent.find(existing.id)
                    .update { $0.time = #bind(time) }
                    .execute(db)
            } else {
                try WakeEvent.insert {
                    WakeEvent.create(babyID: baby.id, time: time)
                }.execute(db)
            }
        }
        refresh()
    }

    var hasWakeTime: Bool { todayWakeEvent != nil }

    var wakeTimeFormatted: String { todayWakeEvent?.time.shortTime ?? "--" }

    // MARK: - Bedtime Actions

    func logBedtime(_ time: Date) {
        guard let baby else { return }
        let event = SleepEvent(
            id: UUID(),
            babyID: baby.id,
            startTime: time,
            isNightSleep: true,
            caregiverName: DeviceIdentity.caregiverName,
            deviceID: DeviceIdentity.deviceID
        )
        try? database.write { db in
            try SleepEvent.insert { event }.execute(db)
        }
        refresh()
    }

    func logWakeUp(at time: Date) {
        guard let nightSleep = activeNightSleep else { return }
        try? database.write { db in
            try SleepEvent.find(nightSleep.id)
                .update { $0.endTime = #bind(time) }
                .execute(db)
        }

        let hour = Calendar.current.component(.hour, from: time)
        if hour >= 5 {
            setWakeTime(time)
        }

        refresh()
    }

    func updateBedtime(_ time: Date) {
        guard let nightSleep = activeNightSleep ?? todayNightSleep else { return }
        try? database.write { db in
            try SleepEvent.find(nightSleep.id)
                .update { $0.startTime = #bind(time) }
                .execute(db)
        }
        refresh()
    }

    var todayNightSleep: SleepEvent? {
        todaySleeps.first { $0.isNightSleep }
    }

    var activeNightSleep: SleepEvent? {
        guard let baby else { return nil }
        return try? database.read { db in
            try SleepEvent
                .where { $0.babyID.eq(#bind(baby.id)) && $0.isNightSleep.eq(true) && $0.endTime.is(nil) }
                .fetchOne(db)
        }
    }

    private var lastCompletedNightSleepEndedToday: SleepEvent? {
        guard let baby else { return nil }
        let startOfDay = Calendar.current.startOfDay(for: Date())
        return try? database.read { db in
            try SleepEvent
                .where { $0.babyID.eq(#bind(baby.id)) && $0.isNightSleep.eq(true) && $0.endTime.isNot(nil) && $0.endTime >= #bind(startOfDay) }
                .order { $0.endTime.desc() }
                .fetchOne(db)
        }
    }

    var isOvernightWake: Bool {
        guard activeNightSleep == nil else { return false }
        guard !hasWakeTime else { return false }
        guard lastCompletedNightSleepEndedToday != nil else { return false }
        let hour = Calendar.current.component(.hour, from: Date())
        return hour < 5
    }

    var actualBedtimeFormatted: String? {
        (activeNightSleep ?? todayNightSleep)?.startTime.shortTime
    }

    var isAsleepForNight: Bool { activeNightSleep != nil }

    // MARK: - Nursing State (API compatibility with sheet views)

    var isNursingActive: Bool {
        activeNursingEvent != nil && activeNursingEvent?.endTime == nil
    }

    var hasNursingSession: Bool { activeNursingEvent != nil }

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

    var hasSleepSession: Bool { activeSleepEvent != nil }

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
            reference = date
        } else if let end = nursingEndTime {
            reference = end
        } else {
            return "00:00"
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

    var ageDisplayString: String { baby?.ageDescription ?? "" }
    var babyName: String { baby?.name ?? "" }

    var bedtimeFormatted: String? { baby?.bedtimeToday().shortTime }

    var dreamFeedEnabled: Bool { baby?.dreamFeedEnabled ?? false }

    var dreamFeedTimeFormatted: String? {
        guard let baby, baby.dreamFeedEnabled else { return nil }
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = baby.dreamFeedHour
        components.minute = baby.dreamFeedMinute
        return Calendar.current.date(from: components)?.shortTime
    }

    var babyPhotoData: Data? { baby?.photoData }

    func updateBaby(_ changes: (inout Baby) -> Void) {
        guard var baby else { return }
        changes(&baby)
        try? database.write { db in
            try Baby.find(baby.id)
                .update {
                    $0.name = #bind(baby.name)
                    $0.birthdate = #bind(baby.birthdate)
                    $0.bedtimeHour = #bind(baby.bedtimeHour)
                    $0.bedtimeMinute = #bind(baby.bedtimeMinute)
                    $0.dreamFeedEnabled = #bind(baby.dreamFeedEnabled)
                    $0.dreamFeedHour = #bind(baby.dreamFeedHour)
                    $0.dreamFeedMinute = #bind(baby.dreamFeedMinute)
                    $0.customFeedIntervalMinutes = #bind(baby.customFeedIntervalMinutes)
                    $0.photoData = #bind(baby.photoData)
                }
                .execute(db)
        }
        self.baby = baby
    }

    func setBabyPhoto(_ data: Data?) {
        updateBaby { $0.photoData = data }
    }

    var feedCount: Int { todayFeeds.count }
    var napCount: Int { todaySleeps.filter({ $0.endTime != nil && !$0.isNightSleep }).count }

    var totalIntakeOz: Double {
        guard let baby else { return 0 }
        let table = AgeTable.forAge(days: baby.ageInDays)
        return todayFeeds.reduce(0) { $0 + $1.estimatedOz(nursingOzPerMinute: table.nursingOzPerMinute(at: $1.startTime, ageInDays: baby.ageInDays)) }
    }

    var totalSleepMinutes: Int { todaySleeps.compactMap(\.durationMinutes).reduce(0, +) }
    var longestSleepMinutes: Int { todaySleeps.compactMap(\.durationMinutes).max() ?? 0 }

    // MARK: - Feed Recommendation Helpers

    var lastFeed: FeedEvent? { todayFeeds.last }
    var lastSleep: SleepEvent? { todaySleeps.filter({ $0.endTime != nil }).last }

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

    var remainingFeeds: Int { max(1, totalDailyFeeds - feedCount) }

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
        if nextTime <= Date() { return "Now" }
        return nextTime.shortTime
    }

    var lastFeedOzFormatted: String { lastFeed?.shortDescription ?? "--" }

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

    var lastSleepTimeFormatted: String { lastSleep?.endTime?.shortTime ?? "--" }
    var lastSleepDurationFormatted: String { lastSleep?.durationDescription ?? "--" }

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

    var totalOzFormatted: String { "\(Int(totalIntakeOz)) oz" }

    var averageOzFormatted: String {
        guard feedCount > 0 else { return "--" }
        let avg = totalIntakeOz / Double(feedCount)
        return String(format: "%.1f oz", avg)
    }
}
