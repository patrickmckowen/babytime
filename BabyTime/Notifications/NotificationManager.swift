//
//  NotificationManager.swift
//  BabyTime
//
//  Thin wrapper around UNUserNotificationCenter.
//  Handles permission requests and cancel-all + reschedule.
//

import UserNotifications

enum NotificationManager {

    static func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .notDetermined else {
            return settings.authorizationStatus == .authorized
        }
        return (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
    }

    /// Cancel all pending and schedule new triggers.
    /// Called after every snapshot recomputation.
    static func reschedule(_ triggers: [NotificationTrigger]) {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()

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
