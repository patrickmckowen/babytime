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
    @State private var showLog = false

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
            .safeAreaInset(edge: .bottom) {
                if activityManager.baby != nil {
                    HStack {
                        // Left: Settings
                        Button {
                            showSettings = true
                        } label: {
                            Image(systemName: "slider.horizontal.3")
                                .font(.body)
                                .foregroundStyle(Color.btTextPrimary)
                                .frame(width: 44, height: 44)
                        }
                        .glassEffect(.regular.interactive(), in: .circle)

                        Spacer()

                        // Center: Log actions grouped in capsule
                        HStack(spacing: 0) {
                            Button {
                                showNursingSheet = true
                            } label: {
                                Image(systemName: "drop.fill")
                                    .font(.body)
                                    .foregroundStyle(Color.btTextPrimary)
                                    .frame(width: 44, height: 44)
                            }

                            Button {
                                showBottleSheet = true
                            } label: {
                                Image(systemName: "waterbottle.fill")
                                    .font(.body)
                                    .foregroundStyle(Color.btTextPrimary)
                                    .frame(width: 44, height: 44)
                            }

                            Button {
                                showSleepSheet = true
                            } label: {
                                Image(systemName: "moon.zzz.fill")
                                    .font(.body)
                                    .foregroundStyle(Color.btTextPrimary)
                                    .frame(width: 44, height: 44)
                            }
                        }
                        .glassEffect(.regular.interactive(), in: .capsule)

                        Spacer()

                        // Right: Calendar → Activity Log
                        Button {
                            showLog = true
                        } label: {
                            Image(systemName: "calendar")
                                .font(.body)
                                .foregroundStyle(Color.btTextPrimary)
                                .frame(width: 44, height: 44)
                        }
                        .glassEffect(.regular.interactive(), in: .circle)
                    }
                    .padding(.horizontal, BTSpacing.pageMargin)
                }
            }
            .navigationDestination(isPresented: $showLog) {
                ActivityLogView()
            }
            .navigationDestination(isPresented: $showSettings) {
                SettingsView()
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
