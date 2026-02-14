//
//  FeedEvent.swift
//  BabyTime
//
//  SwiftData model for a feeding event. Supports CloudKit sync.
//

import Foundation
import SwiftData

@Model
final class FeedEvent {
    var startTime: Date = Date()
    var endTime: Date?

    // Stored as strings for CloudKit compatibility
    var feedKind: String = "bottle"
    var bottleSource: String = "breastMilk"
    var amountOz: Double = 0
    var nursingSide: String = "both"

    var baby: Baby?

    init(
        startTime: Date = Date(),
        endTime: Date? = nil,
        kind: FeedKind = .bottle,
        source: BottleSource = .breastMilk,
        amountOz: Double = 0,
        side: NursingSide = .both,
        baby: Baby? = nil
    ) {
        self.startTime = startTime
        self.endTime = endTime
        self.feedKind = kind.rawValue
        self.bottleSource = source.rawValue
        self.amountOz = amountOz
        self.nursingSide = side.rawValue
        self.baby = baby
    }
}

// MARK: - Type-Safe Accessors

extension FeedEvent {

    var kind: FeedKind {
        get { FeedKind(rawValue: feedKind) ?? .bottle }
        set { feedKind = newValue.rawValue }
    }

    var source: BottleSource {
        get { BottleSource(rawValue: bottleSource) ?? .breastMilk }
        set { bottleSource = newValue.rawValue }
    }

    var side: NursingSide {
        get { NursingSide(rawValue: nursingSide) ?? .both }
        set { nursingSide = newValue.rawValue }
    }

    var isActive: Bool { endTime == nil }

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

    /// Estimated oz for nursing based on age-derived rate
    func estimatedOz(nursingOzPerMinute: Double) -> Double {
        switch kind {
        case .bottle:
            return amountOz
        case .nursing:
            return Double(durationMinutes ?? 0) * nursingOzPerMinute
        }
    }
}

// MARK: - Supporting Enums

enum FeedKind: String, CaseIterable, Sendable {
    case bottle
    case nursing

    var displayName: String {
        switch self {
        case .bottle: return "Bottle"
        case .nursing: return "Nursing"
        }
    }
}

enum BottleSource: String, CaseIterable, Sendable {
    case breastMilk
    case formula

    var displayName: String {
        switch self {
        case .breastMilk: return "Breast milk"
        case .formula: return "Formula"
        }
    }
}

enum NursingSide: String, CaseIterable, Sendable {
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
