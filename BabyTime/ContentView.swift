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
    @Namespace private var sheetTransition
    @State private var showLog = false

    var body: some View {
        NavigationStack {
            Group {
                if activityManager.baby != nil {
                    HomeView(
                        sheetTransition: sheetTransition,
                        onNursingTap: { showNursingSheet = true },
                        onBottleTap: { showBottleSheet = true },
                        onSleepTap: { showSleepSheet = true },
                        onPhotoTap: { showPhotoPicker = true },
                        onLogTap: { showLog = true },
                        onSettingsTap: { showSettings = true }
                    )
                } else {
                    WelcomeView()
                }
            }
            .navigationDestination(isPresented: $showLog) {
                DayPagerView()
            }
            .navigationDestination(isPresented: $showSettings) {
                SettingsView()
            }
        }
        .sheet(isPresented: $showNursingSheet) {
            NursingSheetView()
                .presentationDetents([.medium, .large])
                .navigationTransition(.zoom(sourceID: "feedSheet", in: sheetTransition))
        }
        .sheet(isPresented: $showBottleSheet) {
            BottleSheetView()
                .presentationDetents([.medium, .large])
                .navigationTransition(.zoom(sourceID: "feedSheet", in: sheetTransition))
        }
        .sheet(isPresented: $showSleepSheet) {
            SleepSheetView()
                .presentationDetents([.medium, .large])
                .navigationTransition(.zoom(sourceID: "sleepSheet", in: sheetTransition))
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

        if activityManager.baby != nil {
            Task {
                await NotificationManager.requestPermission()
            }
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
