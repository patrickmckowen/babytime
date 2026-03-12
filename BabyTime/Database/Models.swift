//
//  Models.swift
//  BabyTime
//
//  SQLiteData @Table models for the persistence layer.
//  @Table("tableName") preserves original SQL table names from Phase 1.
//  See SYNC.md for architecture and migration plan.
//

import Foundation
import SQLiteData

// MARK: - Baby

@Table("syncBabies")
nonisolated struct Baby: Identifiable, Hashable, Sendable {
    let id: UUID
    var stableID: String
    var name: String = ""
    var birthdate: Date
    var bedtimeHour: Int = 19
    var bedtimeMinute: Int = 0
    var dreamFeedEnabled: Bool = false
    var dreamFeedHour: Int = 22
    var dreamFeedMinute: Int = 30
    var customFeedIntervalMinutes: Int = 0
    var customFeedsPerDay: Int = 0
    var photoData: Data?
    var createdAt: Date
}

// MARK: - FeedEvent

@Table("syncFeedEvents")
nonisolated struct FeedEvent: Identifiable, Hashable, Sendable {
    let id: UUID
    var babyID: Baby.ID
    var startTime: Date
    var endTime: Date?
    var feedKind: FeedKind = .bottle
    var bottleSource: BottleSource = .breastMilk
    var amountOz: Double = 0
    var nursingSide: NursingSide = .both
    var caregiverName: String = ""
    var deviceID: String = ""

    var isActive: Bool { endTime == nil }
}

enum FeedKind: String, QueryBindable, CaseIterable, Sendable {
    case bottle
    case nursing

    var displayName: String {
        switch self {
        case .bottle: return "Bottle"
        case .nursing: return "Nursing"
        }
    }
}

enum BottleSource: String, QueryBindable, CaseIterable, Sendable {
    case breastMilk
    case formula

    var displayName: String {
        switch self {
        case .breastMilk: return "Breast milk"
        case .formula: return "Formula"
        }
    }
}

enum NursingSide: String, QueryBindable, CaseIterable, Sendable {
    case left
    case right
    case both

    var displayName: String {
        switch self {
        case .left: return "Left"
        case .right: return "Right"
        case .both: return "Both"
        }
    }
}

// MARK: - SleepEvent

@Table("syncSleepEvents")
nonisolated struct SleepEvent: Identifiable, Hashable, Sendable {
    let id: UUID
    var babyID: Baby.ID
    var startTime: Date
    var endTime: Date?
    var isNightSleep: Bool = false
    var caregiverName: String = ""
    var deviceID: String = ""

    var isActive: Bool { endTime == nil }
}

// MARK: - WakeEvent

@Table("syncWakeEvents")
nonisolated struct WakeEvent: Identifiable, Hashable, Sendable {
    let id: UUID
    var babyID: Baby.ID
    var date: Date
    var time: Date
    var caregiverName: String = ""
    var deviceID: String = ""
}

// MARK: - Baby Computed Helpers

extension Baby {

    var ageInDays: Int {
        Calendar.current.dateComponents([.day], from: birthdate, to: Date()).day ?? 0
    }

    func ageInDays(at referenceDate: Date) -> Int {
        Calendar.current.dateComponents([.day], from: birthdate, to: referenceDate).day ?? 0
    }

    func bedtimeToday(referenceDate: Date = Date()) -> Date {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: referenceDate)
        components.hour = bedtimeHour
        components.minute = bedtimeMinute
        components.second = 0
        return calendar.date(from: components) ?? referenceDate
    }

    func dreamFeedToday(referenceDate: Date = Date()) -> Date? {
        guard dreamFeedEnabled else { return nil }
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: referenceDate)
        components.hour = dreamFeedHour
        components.minute = dreamFeedMinute
        components.second = 0
        return calendar.date(from: components)
    }

    var effectiveFeedIntervalMinutes: Int {
        if customFeedIntervalMinutes > 0 {
            return customFeedIntervalMinutes
        }
        let table = AgeTable.forAge(days: ageInDays)
        return (table.feedIntervalMinutes.lowerBound + table.feedIntervalMinutes.upperBound) / 2
    }

    var effectiveFeedsPerDay: Int {
        if customFeedsPerDay > 0 {
            return customFeedsPerDay
        }
        let table = AgeTable.forAge(days: ageInDays)
        return (table.expectedFeedsPerDay.lowerBound + table.expectedFeedsPerDay.upperBound) / 2
    }

    var ageDescription: String {
        let days = ageInDays
        let months = days / 30
        if months > 0 {
            return "\(months) month\(months == 1 ? "" : "s") old"
        }
        return "\(days) day\(days == 1 ? "" : "s") old"
    }

    func ageDescription(at referenceDate: Date) -> String {
        let days = ageInDays(at: referenceDate)
        let months = days / 30
        if months > 0 {
            return "\(months) month\(months == 1 ? "" : "s") old"
        }
        return "\(days) day\(days == 1 ? "" : "s") old"
    }
}

// MARK: - Baby Convenience Init

extension Baby {
    /// Convenience init matching the old SwiftData Baby init signature.
    /// Auto-generates id, stableID, and createdAt.
    init(
        name: String,
        birthdate: Date,
        bedtimeHour: Int = 19,
        bedtimeMinute: Int = 0,
        dreamFeedEnabled: Bool = false,
        dreamFeedHour: Int = 22,
        dreamFeedMinute: Int = 30,
        customFeedIntervalMinutes: Int = 0,
        customFeedsPerDay: Int = 0,
        photoData: Data? = nil
    ) {
        self.init(
            id: UUID(),
            stableID: UUID().uuidString,
            name: name,
            birthdate: birthdate,
            bedtimeHour: bedtimeHour,
            bedtimeMinute: bedtimeMinute,
            dreamFeedEnabled: dreamFeedEnabled,
            dreamFeedHour: dreamFeedHour,
            dreamFeedMinute: dreamFeedMinute,
            customFeedIntervalMinutes: customFeedIntervalMinutes,
            customFeedsPerDay: customFeedsPerDay,
            photoData: photoData,
            createdAt: Date()
        )
    }
}

// MARK: - FeedEvent Type-Safe Accessors

extension FeedEvent {

    /// Alias for `feedKind` — matches old SwiftData computed property name.
    var kind: FeedKind {
        get { feedKind }
        set { feedKind = newValue }
    }

    /// Alias for `bottleSource` — matches old SwiftData computed property name.
    var source: BottleSource {
        get { bottleSource }
        set { bottleSource = newValue }
    }

    /// Alias for `nursingSide` — matches old SwiftData computed property name.
    var side: NursingSide {
        get { nursingSide }
        set { nursingSide = newValue }
    }

    var durationMinutes: Int? {
        guard let end = endTime else { return nil }
        return max(0, Int(end.timeIntervalSince(startTime) / 60))
    }

    var displayDescription: String {
        switch kind {
        case .bottle:
            return "\(source.displayName) · \(Int(amountOz)) oz"
        case .nursing:
            let mins = durationMinutes ?? 0
            return "Nursing \(side.displayName.lowercased()) · \(mins) min"
        }
    }

    var shortDescription: String {
        switch kind {
        case .bottle:
            return "\(Int(amountOz)) oz"
        case .nursing:
            let mins = durationMinutes ?? 0
            return "\(mins) min"
        }
    }

    func estimatedOz(nursingOzPerMinute: Double) -> Double {
        switch kind {
        case .bottle:
            return amountOz
        case .nursing:
            return Double(durationMinutes ?? 0) * nursingOzPerMinute
        }
    }
}

// MARK: - FeedEvent Convenience Init

extension FeedEvent {
    /// Convenience init matching the old SwiftData FeedEvent init signature.
    /// Auto-generates id. Uses a placeholder babyID (for in-memory / test use).
    init(
        startTime: Date = Date(),
        endTime: Date? = nil,
        kind: FeedKind = .bottle,
        source: BottleSource = .breastMilk,
        amountOz: Double = 0,
        side: NursingSide = .both,
        caregiverName: String = DeviceIdentity.caregiverName,
        deviceID: String = DeviceIdentity.deviceID
    ) {
        self.init(
            id: UUID(),
            babyID: UUID(),
            startTime: startTime,
            endTime: endTime,
            feedKind: kind,
            bottleSource: source,
            amountOz: amountOz,
            nursingSide: side,
            caregiverName: caregiverName,
            deviceID: deviceID
        )
    }
}

// MARK: - SleepEvent Computed Helpers

extension SleepEvent {

    var durationMinutes: Int? {
        guard let end = endTime else { return nil }
        return max(0, Int(end.timeIntervalSince(startTime) / 60))
    }

    var durationDescription: String {
        guard let mins = durationMinutes else { return "—" }
        let hours = mins / 60
        let remaining = mins % 60
        if hours > 0 {
            return "\(hours)h \(remaining)m"
        }
        return "\(mins)m"
    }
}

// MARK: - SleepEvent Convenience Init

extension SleepEvent {
    /// Convenience init matching the old SwiftData SleepEvent init signature.
    /// Auto-generates id. Uses a placeholder babyID (for in-memory / test use).
    init(
        startTime: Date = Date(),
        endTime: Date? = nil,
        isNightSleep: Bool = false,
        caregiverName: String = DeviceIdentity.caregiverName,
        deviceID: String = DeviceIdentity.deviceID
    ) {
        self.init(
            id: UUID(),
            babyID: UUID(),
            startTime: startTime,
            endTime: endTime,
            isNightSleep: isNightSleep,
            caregiverName: caregiverName,
            deviceID: deviceID
        )
    }
}

// MARK: - WakeEvent Convenience Init & Factory

extension WakeEvent {
    /// Convenience init matching the old SwiftData WakeEvent init signature.
    /// Auto-generates id. Normalizes date to start of day.
    init(
        date: Date = Date(),
        time: Date = Date(),
        caregiverName: String = DeviceIdentity.caregiverName,
        deviceID: String = DeviceIdentity.deviceID
    ) {
        self.init(
            id: UUID(),
            babyID: UUID(),
            date: Calendar.current.startOfDay(for: date),
            time: time,
            caregiverName: caregiverName,
            deviceID: deviceID
        )
    }

    /// Preferred way to create a WakeEvent with a real baby — normalizes date to start of day.
    static func create(babyID: UUID, time: Date) -> WakeEvent {
        WakeEvent(
            id: UUID(),
            babyID: babyID,
            date: Calendar.current.startOfDay(for: time),
            time: time,
            caregiverName: DeviceIdentity.caregiverName,
            deviceID: DeviceIdentity.deviceID
        )
    }
}
