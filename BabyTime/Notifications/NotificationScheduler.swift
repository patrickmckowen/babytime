//
//  NotificationScheduler.swift
//  BabyTime
//
//  Pure function: snapshot + baby → notification trigger descriptors.
//  No side effects, no UNUserNotificationCenter calls.
//

import Foundation

struct NotificationTrigger: Equatable, Sendable {
    let id: String           // e.g. "ww-approaching", "feed-ready"
    let fireDate: Date
    let title: String
    let body: String
}

enum NotificationScheduler {

    static func triggers(
        from snapshot: DaySnapshot,
        baby: Baby,
        now: Date,
        idPrefix: String = ""
    ) -> [NotificationTrigger] {
        var result: [NotificationTrigger] = []
        let name = baby.name

        // Suppress all notifications when day hasn't started
        guard snapshot.dayState != .notStarted else { return [] }

        // When asleep for night, only dream feed is relevant
        if case .asleepForNight = snapshot.dayState {
            if let dreamFeedTime = baby.dreamFeedToday(), dreamFeedTime > now {
                result.append(NotificationTrigger(
                    id: "\(idPrefix)dream-feed",
                    fireDate: dreamFeedTime,
                    title: "Dream Feed",
                    body: "Dream feed time for \(name)"
                ))
            }
            return result
        }

        // --- Sleep triggers (suppress while sleeping) ---
        let isSleeping: Bool
        switch snapshot.dayState {
        case .sleepingNoPressure, .sleepingApproachingCutoff, .sleepingMustEnd:
            isSleeping = true
        default:
            isSleeping = false
        }

        if !isSleeping, let wakeRef = snapshot.wakeReference {
            let ww = snapshot.ageTable.currentWakeWindow(completedNaps: snapshot.completedNaps)

            // Wake window approaching (lower bound)
            let approachingDate = wakeRef.addingTimeInterval(Double(ww.lowerBound) * 60)
            if approachingDate > now && approachingDate < snapshot.napCutoff {
                result.append(NotificationTrigger(
                    id: "\(idPrefix)ww-approaching",
                    fireDate: approachingDate,
                    title: "Nap Window Opening",
                    body: "Start winding down — \(name) will need a nap soon"
                ))
            }

            // Wake window exceeded (upper bound)
            let exceededDate = wakeRef.addingTimeInterval(Double(ww.upperBound) * 60)
            if exceededDate > now && exceededDate < snapshot.napCutoff {
                result.append(NotificationTrigger(
                    id: "\(idPrefix)ww-exceeded",
                    fireDate: exceededDate,
                    title: "Nap Time",
                    body: "\(name) is probably pretty tired"
                ))
            }
        }

        // Nap cutoff approaching (30 min before cutoff)
        let cutoffApproaching = snapshot.napCutoff.addingTimeInterval(-30 * 60)
        if cutoffApproaching > now && !isSleeping {
            result.append(NotificationTrigger(
                id: "\(idPrefix)cutoff-approaching",
                fireDate: cutoffApproaching,
                title: "Nap Cutoff Soon",
                body: "Last chance for a nap — cutoff in 30 minutes"
            ))
        }

        // Nap cutoff reached (only while sleeping)
        if isSleeping && snapshot.napCutoff > now {
            result.append(NotificationTrigger(
                id: "\(idPrefix)cutoff-reached",
                fireDate: snapshot.napCutoff,
                title: "Wake \(name) Up",
                body: "Nap cutoff reached — time to wake up for bedtime"
            ))
        }

        // --- Feed triggers (suppress while feeding) ---
        if case .feedingNow = snapshot.feedState {
            // no feed notifications while actively feeding
        } else if isSleeping {
            // no feed notifications while napping
        } else if let feedRef = snapshot.lastFeedReference ?? snapshot.wakeReference {
            let interval = baby.customFeedIntervalMinutes > 0
                ? baby.customFeedIntervalMinutes...baby.customFeedIntervalMinutes
                : snapshot.ageTable.feedIntervalMinutes

            // Feed approaching (80% of lower bound)
            let approachingMin = Double(interval.lowerBound) * 0.8
            let feedApproaching = feedRef.addingTimeInterval(approachingMin * 60)
            if feedApproaching > now {
                result.append(NotificationTrigger(
                    id: "\(idPrefix)feed-approaching",
                    fireDate: feedApproaching,
                    title: "Feed Coming Up",
                    body: "Start getting ready — \(name) will want to eat soon"
                ))
            }

            // Feed ready (lower bound)
            let feedReady = feedRef.addingTimeInterval(Double(interval.lowerBound) * 60)
            if feedReady > now {
                result.append(NotificationTrigger(
                    id: "\(idPrefix)feed-ready",
                    fireDate: feedReady,
                    title: "Feed Time",
                    body: "Time to offer \(name) a feed"
                ))
            }
        }

        // --- Bedtime approaching (30 min before) ---
        let bedtimeApproaching = snapshot.bedtime.addingTimeInterval(-30 * 60)
        if bedtimeApproaching > now && !isSleeping {
            result.append(NotificationTrigger(
                id: "\(idPrefix)bedtime-approaching",
                fireDate: bedtimeApproaching,
                title: "Bedtime Soon",
                body: "Start winding down — bedtime in about 30 minutes"
            ))
        }

        return result
    }
}
