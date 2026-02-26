//
//  BabyTimeApp.swift
//  BabyTime
//
//  Created by Patrick McKowen on 1/27/26.
//

import Dependencies
import SwiftUI
import UserNotifications

@main
struct BabyTimeApp: App {
    @State private var activityManager: ActivityManager
    @Environment(\.scenePhase) private var scenePhase

    init() {
        UNUserNotificationCenter.current().delegate = NotificationManager.delegate
        let manager: ActivityManager
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            manager = withDependencies {
                try! $0.bootstrapTestDatabase()
            } operation: {
                @Dependency(\.defaultDatabase) var database
                return ActivityManager(database: database)
            }
        } else {
            manager = withDependencies {
                try! $0.bootstrapDatabase()
            } operation: {
                @Dependency(\.defaultDatabase) var database
                return ActivityManager(database: database)
            }
        }
        self._activityManager = State(initialValue: manager)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(activityManager)
                .preferredColorScheme(.light)
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        activityManager.refresh()
                    }
                }
        }
    }
}
