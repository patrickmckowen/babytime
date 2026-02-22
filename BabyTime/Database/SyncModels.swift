//
//  SyncModels.swift
//  BabyTime
//
//  SQLiteData @Table models for the CloudKit sync migration.
//  Prefixed with "Sync" to coexist with existing SwiftData models
//  during the migration. Will be renamed in Phase 2.
//
//  See SYNC.md for architecture and migration plan.
//

import Foundation
import SQLiteData

// MARK: - Baby

@Table
nonisolated struct SyncBaby: Identifiable, Hashable, Sendable {
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
    var photoData: Data?
    var createdAt: Date
}

// MARK: - FeedEvent

@Table
nonisolated struct SyncFeedEvent: Identifiable, Hashable, Sendable {
    let id: UUID
    var babyID: SyncBaby.ID
    var startTime: Date
    var endTime: Date?
    var feedKind: SyncFeedKind = .bottle
    var bottleSource: SyncBottleSource = .breastMilk
    var amountOz: Double = 0
    var nursingSide: SyncNursingSide = .both
    var caregiverName: String = ""
    var deviceID: String = ""

    var isActive: Bool { endTime == nil }
}

enum SyncFeedKind: String, QueryBindable, CaseIterable, Sendable {
    case bottle
    case nursing

    var displayName: String {
        switch self {
        case .bottle: return "Bottle"
        case .nursing: return "Nursing"
        }
    }
}

enum SyncBottleSource: String, QueryBindable, CaseIterable, Sendable {
    case breastMilk
    case formula

    var displayName: String {
        switch self {
        case .breastMilk: return "Breast milk"
        case .formula: return "Formula"
        }
    }
}

enum SyncNursingSide: String, QueryBindable, CaseIterable, Sendable {
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

@Table
nonisolated struct SyncSleepEvent: Identifiable, Hashable, Sendable {
    let id: UUID
    var babyID: SyncBaby.ID
    var startTime: Date
    var endTime: Date?
    var isNightSleep: Bool = false
    var caregiverName: String = ""
    var deviceID: String = ""

    var isActive: Bool { endTime == nil }
}

// MARK: - WakeEvent

@Table
nonisolated struct SyncWakeEvent: Identifiable, Hashable, Sendable {
    let id: UUID
    var babyID: SyncBaby.ID
    var date: Date
    var time: Date
    var caregiverName: String = ""
    var deviceID: String = ""
}
