//
//  ContentView.swift
//  BabyTime
//
//  Created by Patrick McKowen on 1/27/26.
//

import SwiftUI

struct ContentView: View {
    @Environment(ActivityManager.self) private var activityManager
    @State private var showNursingSheet = false
    @State private var showBottleSheet = false
    @State private var showSleepSheet = false

    var body: some View {
        NavigationStack {
            HomeView(
                onNursingTap: { showNursingSheet = true },
                onSleepTap: { showSleepSheet = true }
            )
        }
        .toolbar {
            ToolbarItemGroup(placement: .bottomBar) {
                Button {
                    showNursingSheet = true
                } label: {
                    Image(systemName: "drop.fill")
                }

                Button {
                    showBottleSheet = true
                } label: {
                    Image(systemName: "waterbottle.fill")
                }

                Button {
                    showSleepSheet = true
                } label: {
                    Image(systemName: "moon.zzz.fill")
                }
            }
        }
        .sheet(isPresented: $showNursingSheet) {
            NursingSheetView()
        }
        .sheet(isPresented: $showBottleSheet) {
            BottleSheetView()
        }
        .sheet(isPresented: $showSleepSheet) {
            SleepSheetView()
        }
    }
}

#Preview {
    ContentView()
        .environment(ActivityManager())
}
