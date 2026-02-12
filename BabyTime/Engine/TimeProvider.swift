//
//  TimeProvider.swift
//  BabyTime
//
//  Clock abstraction for testable time-dependent logic.
//

import Foundation

struct TimeProvider: Sendable {
    var now: @Sendable () -> Date

    static let live = TimeProvider(now: { Date() })

    static func fixed(_ date: Date) -> TimeProvider {
        TimeProvider(now: { date })
    }
}
