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

    var body: some View {
        NavigationStack {
            HomeView(onNursingTap: { showNursingSheet = true })
                .toolbar {
                    ToolbarItemGroup(placement: .bottomBar) {
                        Button {
                            showNursingSheet = true
                        } label: {
                            Image(systemName: "drop.fill")
                        }

                        Button {
                            // Bottle — placeholder
                        } label: {
                            Image(systemName: "waterbottle.fill")
                        }

                        Button {
                            // Nap — placeholder
                        } label: {
                            Image(systemName: "moon.zzz.fill")
                        }
                    }
                }
        }
        .sheet(isPresented: $showNursingSheet) {
            NursingSheetView()
        }
    }
}

#Preview {
    ContentView()
        .environment(ActivityManager())
}
