//
//  ContentView.swift
//  BabyTime
//
//  Created by Patrick McKowen on 1/27/26.
//

import SwiftUI
import SwiftData
import PhotosUI

struct ContentView: View {
    @Environment(ActivityManager.self) private var activityManager
    @AppStorage("selectedBabyID") private var selectedBabyID: String?

    @State private var showNursingSheet = false
    @State private var showBottleSheet = false
    @State private var showSleepSheet = false
    @State private var showSettings = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showPhotoPicker = false

    var body: some View {
        NavigationStack {
            Group {
                if activityManager.baby != nil {
                    HomeView(
                        onNursingTap: { showNursingSheet = true },
                        onBottleTap: { showBottleSheet = true },
                        onSleepTap: { showSleepSheet = true },
                        onPhotoTap: { showPhotoPicker = true }
                    )
                } else {
                    WelcomeView()
                }
            }
        }
        .toolbar {
            if activityManager.baby != nil {
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

                    Spacer()

                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
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
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .photosPicker(
            isPresented: $showPhotoPicker,
            selection: $selectedPhoto,
            matching: .images
        )
        .onChange(of: selectedPhoto) { _, newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let compressed = ImageUtilities.resizeForProfile(data: data) {
                    activityManager.setBabyPhoto(compressed)
                }
                selectedPhoto = nil
            }
        }
        .onAppear {
            selectBabyFromStorage()
        }
        .onChange(of: activityManager.allBabies.count) {
            if activityManager.baby == nil {
                selectBabyFromStorage()
            }
        }
    }

    // MARK: - Baby Selection

    private func selectBabyFromStorage() {
        activityManager.loadBabies()

        if let id = selectedBabyID,
           let baby = activityManager.allBabies.first(where: { $0.stableID == id }) {
            activityManager.selectBaby(baby)
        } else if let first = activityManager.allBabies.first {
            activityManager.selectBaby(first)
            selectedBabyID = first.stableID
        }
    }
}

#Preview {
    let container = try! ModelContainer(
        for: Baby.self, FeedEvent.self, SleepEvent.self, WakeEvent.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    ContentView()
        .environment(ActivityManager(modelContext: container.mainContext))
        .modelContainer(container)
}
