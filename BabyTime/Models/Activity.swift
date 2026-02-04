//
//  Activity.swift
//  BabyTime
//

import Foundation

// MARK: - Baby

struct Baby: Identifiable {
    let id: UUID
    let name: String
    let birthdate: Date

    var ageInDays: Int {
        Calendar.current.dateComponents([.day], from: birthdate, to: .now).day ?? 0
    }

    var ageDescription: String {
        let months = ageInDays / 30
        let days = ageInDays % 30
        if months > 0 {
            return "\(months) month\(months == 1 ? "" : "s"), \(days) day\(days == 1 ? "" : "s")"
        }
        return "\(days) day\(days == 1 ? "" : "s")"
    }
}

// MARK: - Feed Types

enum BottleSource: String, CaseIterable {
    case breastMilk = "Breast milk"
    case formula = "Formula"
}

enum NursingSide: String, CaseIterable {
    case left = "Left"
    case right = "Right"
    case both = "Both"
}

enum FeedType {
    case bottle(source: BottleSource, amountOz: Double)
    case nursing(side: NursingSide, durationMinutes: Int)

    var displayDescription: String {
        switch self {
        case .bottle(let source, let oz):
            return "\(source.rawValue) • \(Int(oz)) oz"
        case .nursing(let side, let mins):
            return "Nursing \(side.rawValue.lowercased()) • \(mins) min"
        }
    }

    var shortDescription: String {
        switch self {
        case .bottle(_, let oz):
            return "\(Int(oz)) oz"
        case .nursing(_, let mins):
            return "\(mins) min"
        }
    }
}

// MARK: - Activities

struct FeedActivity: Identifiable {
    let id: UUID
    let startTime: Date
    let type: FeedType
}

struct SleepActivity: Identifiable {
    let id: UUID
    let startTime: Date
    let endTime: Date

    var durationMinutes: Int {
        Int(endTime.timeIntervalSince(startTime) / 60)
    }

    var durationDescription: String {
        let hours = durationMinutes / 60
        let mins = durationMinutes % 60
        if hours > 0 {
            return "\(hours)h \(mins)m"
        }
        return "\(mins)m"
    }
}

// MARK: - Unified Activity (for Timeline)

enum Activity: Identifiable {
    case feed(FeedActivity)
    case sleep(SleepActivity)

    var id: UUID {
        switch self {
        case .feed(let f): return f.id
        case .sleep(let s): return s.id
        }
    }

    var timestamp: Date {
        switch self {
        case .feed(let f): return f.startTime
        case .sleep(let s): return s.startTime
        }
    }

    var icon: String {
        switch self {
        case .feed: return "drop.fill"
        case .sleep: return "moon.zzz.fill"
        }
    }

    var title: String {
        switch self {
        case .feed: return "Feed"
        case .sleep: return "Sleep"
        }
    }

    var detail: String {
        switch self {
        case .feed(let f): return f.type.shortDescription
        case .sleep(let s): return s.durationDescription
        }
    }
}

// MARK: - Age Targets

struct AgeTargets {
    let wakeWindowMinutes: ClosedRange<Int>
    let feedIntervalMinutes: ClosedRange<Int>
    let dailyIntakeOz: ClosedRange<Int>
    let dailySleepHours: ClosedRange<Int>
}

// MARK: - Day Log

struct DayLog {
    let date: Date
    let feeds: [FeedActivity]
    let sleeps: [SleepActivity]

    var allActivities: [Activity] {
        let feedActivities = feeds.map { Activity.feed($0) }
        let sleepActivities = sleeps.map { Activity.sleep($0) }
        return (feedActivities + sleepActivities).sorted { $0.timestamp > $1.timestamp }
    }
}

// MARK: - Scenario (for previews and testing)

struct Scenario {
    let baby: Baby
    let currentTime: Date
    let today: DayLog
    let targets: AgeTargets
}
