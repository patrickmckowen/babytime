//
//  WakeEvent.swift
//  BabyTime
//
//  SwiftData model for a daily wake event. Persisted historically for analytics.
//  One WakeEvent per baby per day (upsert pattern).
//

import Foundation
import SwiftData

@Model
final class WakeEvent {
    /// Calendar day (start of day) — used to find "today's" event and for analytics queries
    var date: Date = Date()
    /// Actual wake time the user recorded
    var time: Date = Date()

    // Multi-writer identity — stamped at creation, never modified after
    var caregiverName: String = ""
    var deviceID: String = ""

    var baby: Baby?

    init(
        date: Date = Date(),
        time: Date = Date(),
        baby: Baby? = nil,
        caregiverName: String = DeviceIdentity.caregiverName,
        deviceID: String = DeviceIdentity.deviceID
    ) {
        self.date = Calendar.current.startOfDay(for: date)
        self.time = time
        self.baby = baby
        self.caregiverName = caregiverName
        self.deviceID = deviceID
    }
}
