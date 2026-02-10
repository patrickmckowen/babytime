//
//  BabyTimeApp.swift
//  BabyTime
//
//  Created by Patrick McKowen on 1/27/26.
//

import SwiftUI

@main
struct BabyTimeApp: App {
    @State private var activityManager = ActivityManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(activityManager)
        }
    }
}
