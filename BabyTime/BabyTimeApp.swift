//
//  BabyTimeApp.swift
//  BabyTime
//
//  Created by Patrick McKowen on 1/27/26.
//

import Dependencies
import SwiftUI
import SQLiteData
import UserNotifications

@main
struct BabyTimeApp: App {
    @State private var activityManager: ActivityManager
    @State private var syncDelegate: SyncDelegate?
    @Environment(\.scenePhase) private var scenePhase

    init() {
        UNUserNotificationCenter.current().delegate = NotificationManager.delegate
        let manager: ActivityManager
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            // Tests: in-memory DB, no SyncEngine
            manager = withDependencies {
                try! $0.bootstrapTestDatabase()
            } operation: {
                @Dependency(\.defaultDatabase) var database
                return ActivityManager(database: database)
            }
            self._activityManager = State(initialValue: manager)
            self._syncDelegate = State(initialValue: nil)
        } else {
            // Production: database + SyncEngine
            let delegate = SyncDelegate()
            manager = withDependencies {
                try! $0.bootstrapDatabase()
                $0.defaultSyncEngine = try! SyncEngine(
                    for: $0.defaultDatabase,
                    tables: Baby.self, FeedEvent.self, SleepEvent.self, WakeEvent.self,
                    containerIdentifier: "iCloud.com.patrickmckowen.BabyTime",
                    delegate: delegate
                )
            } operation: {
                @Dependency(\.defaultDatabase) var database
                return ActivityManager(database: database)
            }
            self._activityManager = State(initialValue: manager)
            self._syncDelegate = State(initialValue: delegate)
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(activityManager)
                .preferredColorScheme(.light)
                .task {
                    UIApplication.shared.registerForRemoteNotifications()
                }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        activityManager.refresh()
                    }
                }
                .alert("iCloud Account Changed", isPresented: Binding(
                    get: { syncDelegate?.showResetDataAlert ?? false },
                    set: { syncDelegate?.showResetDataAlert = $0 }
                )) {
                    Button("Keep Local Data", role: .cancel) { }
                    Button("Reset Data", role: .destructive) {
                        Task {
                            @Dependency(\.defaultSyncEngine) var syncEngine
                            try? await syncEngine.deleteLocalData()
                        }
                    }
                } message: {
                    Text("Your iCloud account changed. Keep existing data or start fresh?")
                }
        }
    }
}
