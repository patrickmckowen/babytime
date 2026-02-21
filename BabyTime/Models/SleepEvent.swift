//
//  SleepEvent.swift
//  BabyTime
//
//  SwiftData model for a sleep event. Supports CloudKit sync.
//

import Foundation
import SwiftData

@Model
final class SleepEvent {
    var startTime: Date = Date()
    var endTime: Date?
    var isNightSleep: Bool = false

    // Multi-writer identity — stamped at creation, never modified after
    var caregiverName: String = ""
    var deviceID: String = ""

    var baby: Baby?

    init(
        startTime: Date = Date(),
        endTime: Date? = nil,
        isNightSleep: Bool = false,
        baby: Baby? = nil,
        caregiverName: String = DeviceIdentity.caregiverName,
        deviceID: String = DeviceIdentity.deviceID
    ) {
        self.startTime = startTime
        self.endTime = endTime
        self.isNightSleep = isNightSleep
        self.baby = baby
        self.caregiverName = caregiverName
        self.deviceID = deviceID
    }
}

// MARK: - Computed Helpers

extension SleepEvent {

    var isActive: Bool { endTime == nil }

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
