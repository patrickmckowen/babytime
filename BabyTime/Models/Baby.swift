//
//  Baby.swift
//  BabyTime
//
//  SwiftData model for a baby. Supports CloudKit sync.
//

import Foundation
import SwiftData

@Model
final class Baby {
    /// Stable identifier for @AppStorage selection and CloudKit dedup
    var stableID: String = UUID().uuidString

    var name: String = ""
    var birthdate: Date = Date()

    // Schedule — store as integers to avoid timezone issues
    var bedtimeHour: Int = 19
    var bedtimeMinute: Int = 0
    var dreamFeedEnabled: Bool = false
    var dreamFeedHour: Int = 22
    var dreamFeedMinute: Int = 30

    /// Profile photo — stored externally via CloudKit CKAsset
    @Attribute(.externalStorage) var photoData: Data?

    var createdAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \FeedEvent.baby)
    var feedEvents: [FeedEvent]? = []

    @Relationship(deleteRule: .cascade, inverse: \SleepEvent.baby)
    var sleepEvents: [SleepEvent]? = []

    @Relationship(deleteRule: .cascade, inverse: \WakeEvent.baby)
    var wakeEvents: [WakeEvent]? = []

    init(
        name: String,
        birthdate: Date,
        bedtimeHour: Int = 19,
        bedtimeMinute: Int = 0,
        dreamFeedEnabled: Bool = false,
        dreamFeedHour: Int = 22,
        dreamFeedMinute: Int = 30,
        photoData: Data? = nil
    ) {
        self.stableID = UUID().uuidString
        self.name = name
        self.birthdate = birthdate
        self.bedtimeHour = bedtimeHour
        self.bedtimeMinute = bedtimeMinute
        self.dreamFeedEnabled = dreamFeedEnabled
        self.dreamFeedHour = dreamFeedHour
        self.dreamFeedMinute = dreamFeedMinute
        self.photoData = photoData
        self.createdAt = Date()
    }
}

// MARK: - Computed Helpers

extension Baby {

    var ageInDays: Int {
        Calendar.current.dateComponents([.day], from: birthdate, to: Date()).day ?? 0
    }

    func ageInDays(at referenceDate: Date) -> Int {
        Calendar.current.dateComponents([.day], from: birthdate, to: referenceDate).day ?? 0
    }

    /// Constructs today's bedtime as a full Date from hour+minute
    func bedtimeToday(referenceDate: Date = Date()) -> Date {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: referenceDate)
        components.hour = bedtimeHour
        components.minute = bedtimeMinute
        components.second = 0
        return calendar.date(from: components) ?? referenceDate
    }

    /// Constructs today's dream feed time, if enabled
    func dreamFeedToday(referenceDate: Date = Date()) -> Date? {
        guard dreamFeedEnabled else { return nil }
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: referenceDate)
        components.hour = dreamFeedHour
        components.minute = dreamFeedMinute
        components.second = 0
        return calendar.date(from: components)
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
