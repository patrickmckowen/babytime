//
//  NotificationManager.swift
//  BabyTime
//
//  Thin wrapper around UNUserNotificationCenter.
//  Handles permission requests and cancel-all + reschedule.
//

import UserNotifications

final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}

enum NotificationManager {

    static let delegate = NotificationDelegate()

    static func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .notDetermined else {
            return settings.authorizationStatus == .authorized
        }
        return (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
    }

    /// Remove stale notifications for this baby and schedule new ones.
    /// Called after every snapshot recomputation.
    static func reschedule(_ triggers: [NotificationTrigger], removingPrefix prefix: String) {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { requests in
            let stale = requests
                .filter { $0.identifier.hasPrefix(prefix) }
                .map(\.identifier)
            center.removePendingNotificationRequests(withIdentifiers: stale)

            for trigger in triggers {
                let content = UNMutableNotificationContent()
                content.title = trigger.title
                content.body = trigger.body
                content.sound = .default

                let interval = max(1, trigger.fireDate.timeIntervalSinceNow)
                let timeTrigger = UNTimeIntervalNotificationTrigger(
                    timeInterval: interval,
                    repeats: false
                )

                let request = UNNotificationRequest(
                    identifier: trigger.id,
                    content: content,
                    trigger: timeTrigger
                )
                center.add(request)
            }
        }
    }
}
