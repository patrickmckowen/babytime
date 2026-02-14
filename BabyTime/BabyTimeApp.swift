//
//  BabyTimeApp.swift
//  BabyTime
//
//  Created by Patrick McKowen on 1/27/26.
//

import SwiftUI
import SwiftData

@main
struct BabyTimeApp: App {
    let container: ModelContainer
    @State private var activityManager: ActivityManager

    init() {
        let container: ModelContainer
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
            container = try! ModelContainer(
                for: Baby.self, FeedEvent.self, SleepEvent.self, WakeEvent.self,
                configurations: config
            )
        } else {
            container = try! ModelContainer(for: Baby.self, FeedEvent.self, SleepEvent.self, WakeEvent.self)
        }
        self.container = container
        self._activityManager = State(initialValue: ActivityManager(modelContext: container.mainContext))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(activityManager)
                .modelContainer(container)
        }
    }
}
