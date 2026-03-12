//
//  SettingsView.swift
//  BabyTime
//
//  Settings: baby info, schedule, baby list, add/delete.
//

import CloudKit
import Dependencies
import PhotosUI
import SQLiteData
import SwiftUI

struct SettingsView: View {
    @Environment(ActivityManager.self) private var activityManager
    @Environment(\.dismiss) private var dismiss
    @State private var sharedRecord: SharedRecord?
    @State private var shareError: String?
    @State private var showJoinShare = false
    @State private var engineRunning = false
    @State private var engineSyncing = false
    @State private var engineSending = false
    @State private var engineFetching = false
    @State private var babyToDelete: Baby?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: BTSpacing.cardGap) {
                    if let baby = activityManager.baby {
                        babyInfoCard(baby)
                        scheduleCard(baby)
                        sharingCard(baby)
                    }

                    if activityManager.allBabies.count > 1 {
                        babySelectorCard
                    }

                    addBabyButton
                    joinShareButton
                    syncDiagnosticsCard
                }
                .padding(.horizontal, BTSpacing.pageMargin)
                .padding(.vertical, 20)
            }
            .background(Color.btBackground)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $sharedRecord) { record in
                CloudSharingView(sharedRecord: record)
            }
            .alert("Sharing Error", isPresented: Binding(
                get: { shareError != nil },
                set: { if !$0 { shareError = nil } }
            )) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(shareError ?? "")
            }
            .sheet(isPresented: $showJoinShare) {
                JoinShareView()
            }
            .sheet(item: $babyToDelete) { baby in
                deleteBabyConfirmation(baby)
            }
        }
    }

    // MARK: - Baby Info Card

    private func babyInfoCard(_ baby: Baby) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Baby")
                .font(BTTypography.photoDate)
                .tracking(BTTracking.photoDate)
                .foregroundStyle(Color.btTextPrimary)

            LabeledField(label: "Name") {
                TextField("Name", text: Binding(
                    get: { baby.name },
                    set: { newName in activityManager.updateBaby { $0.name = newName } }
                ))
                .textContentType(.name)
            }

            LabeledField(label: "Birthday") {
                DatePicker(
                    "",
                    selection: Binding(
                        get: { baby.birthdate },
                        set: { newDate in activityManager.updateBaby { $0.birthdate = newDate } }
                    ),
                    displayedComponents: .date
                )
                .labelsHidden()
            }
        }
        .padding(.top, BTSpacing.cardPaddingTop)
        .padding(.horizontal, BTSpacing.cardPaddingHorizontal)
        .padding(.bottom, BTSpacing.cardPaddingBottom)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.btBackground)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.card, style: .continuous))
        .cardShadow()
    }

    // MARK: - Schedule Card

    private func scheduleCard(_ baby: Baby) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Schedule")
                .font(BTTypography.photoDate)
                .tracking(BTTracking.photoDate)
                .foregroundStyle(Color.btTextPrimary)

            LabeledField(label: "Bedtime") {
                DatePicker(
                    "",
                    selection: bedtimeBinding(baby),
                    displayedComponents: .hourAndMinute
                )
                .labelsHidden()
            }

            LabeledField(label: "Feeds Per Day") {
                Picker("", selection: feedsPerDayBinding(baby)) {
                    Text("Age default (\(ageDefaultFeedsPerDay(baby)))").tag(0)
                    ForEach(4...12, id: \.self) { count in
                        Text("\(count)").tag(count)
                    }
                }
                .labelsHidden()
            }

            LabeledField(label: "Feed Every") {
                Picker("", selection: feedIntervalBinding(baby)) {
                    Text("Age default").tag(0)
                    Text("1.5 hours").tag(90)
                    Text("2 hours").tag(120)
                    Text("2.5 hours").tag(150)
                    Text("3 hours").tag(180)
                    Text("3.5 hours").tag(210)
                    Text("4 hours").tag(240)
                }
                .labelsHidden()
            }

            LabeledField(label: "Dream Feed") {
                HStack {
                    Toggle("", isOn: Binding(
                        get: { baby.dreamFeedEnabled },
                        set: { newValue in activityManager.updateBaby { $0.dreamFeedEnabled = newValue } }
                    ))
                    .labelsHidden()

                    if baby.dreamFeedEnabled {
                        DatePicker(
                            "",
                            selection: dreamFeedBinding(baby),
                            displayedComponents: .hourAndMinute
                        )
                        .labelsHidden()
                    }
                }
            }
        }
        .padding(.top, BTSpacing.cardPaddingTop)
        .padding(.horizontal, BTSpacing.cardPaddingHorizontal)
        .padding(.bottom, BTSpacing.cardPaddingBottom)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.btBackground)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.card, style: .continuous))
        .cardShadow()
    }

    // MARK: - Sharing Card

    private func sharingCard(_ baby: Baby) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Sharing")
                .font(BTTypography.photoDate)
                .tracking(BTTracking.photoDate)
                .foregroundStyle(Color.btTextPrimary)

            if activityManager.isBabyShared(baby) {
                let count = activityManager.shareParticipantCount(baby)
                HStack {
                    Text("Shared with \(count) caregiver\(count == 1 ? "" : "s")")
                        .font(BTTypography.label)
                        .tracking(BTTracking.label)
                        .foregroundStyle(Color.btTextSecondary)

                    Spacer()

                    Button("Manage") {
                        openManageSharing(baby)
                    }
                    .font(BTTypography.label)
                    .tracking(BTTracking.label)
                    .foregroundStyle(Color.btFeedAccent)
                }
            } else {
                Button {
                    startSharing(baby)
                } label: {
                    HStack {
                        Image(systemName: "person.badge.plus")
                        Text("Share with Family")
                    }
                    .font(BTTypography.label)
                    .tracking(BTTracking.label)
                    .foregroundStyle(Color.btFeedAccent)
                }
            }
        }
        .padding(.top, BTSpacing.cardPaddingTop)
        .padding(.horizontal, BTSpacing.cardPaddingHorizontal)
        .padding(.bottom, BTSpacing.cardPaddingBottom)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.btBackground)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.card, style: .continuous))
        .cardShadow()
    }

    private func startSharing(_ baby: Baby) {
        Task {
            do {
                @Dependency(\.defaultSyncEngine) var syncEngine
                sharedRecord = try await syncEngine.share(record: baby) { share in
                    share[CKShare.SystemFieldKey.title] = "\(baby.name)'s BabyTime"
                    if let photoData = baby.photoData,
                       let thumbnail = ImageUtilities.resizeForProfile(
                           data: photoData, maxDimension: 256, quality: 0.5
                       ) {
                        share[CKShare.SystemFieldKey.thumbnailImageData] = thumbnail
                    }
                }
            } catch {
                shareError = "Share failed: \(error)"
            }
        }
    }

    private func openManageSharing(_ baby: Baby) {
        Task {
            do {
                @Dependency(\.defaultSyncEngine) var syncEngine
                sharedRecord = try await syncEngine.share(record: baby) { _ in }
            } catch {
                shareError = "Manage sharing failed: \(error)"
            }
        }
    }

    // MARK: - Join Shared Baby

    private var joinShareButton: some View {
        Button {
            showJoinShare = true
        } label: {
            HStack {
                Image(systemName: "person.crop.circle.badge.plus")
                Text("Join Shared Baby")
            }
            .font(BTTypography.label)
            .tracking(BTTracking.label)
            .foregroundStyle(Color.btFeedAccent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.btBackground)
            .clipShape(RoundedRectangle(cornerRadius: BTRadius.card, style: .continuous))
            .cardShadow()
        }
    }

    // MARK: - Sync Diagnostics

    private var syncDiagnosticsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Sync Diagnostics")
                    .font(BTTypography.photoDate)
                    .tracking(BTTracking.photoDate)
                    .foregroundStyle(Color.btTextPrimary)

                Spacer()

                Button {
                    refreshDiagnostics()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .foregroundStyle(Color.btFeedAccent)
                }
            }

            diagnosticRow("Engine", value: engineRunning ? "Running" : "Stopped")
            diagnosticRow("Syncing", value: engineSyncing ? "Yes" : "No")
            diagnosticRow("Sending", value: engineSending ? "Yes" : "No")
            diagnosticRow("Fetching", value: engineFetching ? "Yes" : "No")

            Divider()
                .foregroundStyle(Color.btDivider)

            ForEach(activityManager.allBabies, id: \.stableID) { baby in
                let hasServer = activityManager.hasSyncServerRecord(baby)
                let shared = activityManager.isBabyShared(baby)
                diagnosticRow(
                    baby.name.isEmpty ? "Unnamed" : baby.name,
                    value: hasServer ? (shared ? "Synced + Shared" : "Synced") : "Local Only"
                )
            }
        }
        .padding(.top, BTSpacing.cardPaddingTop)
        .padding(.horizontal, BTSpacing.cardPaddingHorizontal)
        .padding(.bottom, BTSpacing.cardPaddingBottom)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.btBackground)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.card, style: .continuous))
        .cardShadow()
        .task { refreshDiagnostics() }
    }

    private func diagnosticRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(BTTypography.label)
                .tracking(BTTracking.label)
                .foregroundStyle(Color.btTextSecondary)
            Spacer()
            Text(value)
                .font(BTTypography.label)
                .tracking(BTTracking.label)
                .foregroundStyle(value == "Local Only" || value == "Stopped" ? Color.orange : Color.btTextPrimary)
        }
    }

    private func refreshDiagnostics() {
        Task { @MainActor in
            @Dependency(\.defaultSyncEngine) var syncEngine
            engineRunning = syncEngine.isRunning
            engineSyncing = syncEngine.isSynchronizing
            engineSending = syncEngine.isSendingChanges
            engineFetching = syncEngine.isFetchingChanges
        }
    }

    // MARK: - Baby Selector

    private var babySelectorCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Babies")
                .font(BTTypography.photoDate)
                .tracking(BTTracking.photoDate)
                .foregroundStyle(Color.btTextPrimary)
                .padding(.top, BTSpacing.cardPaddingTop)
                .padding(.horizontal, BTSpacing.cardPaddingHorizontal)
                .padding(.bottom, 8)

            List {
                ForEach(activityManager.allBabies, id: \.stableID) { baby in
                    HStack(spacing: 12) {
                        babyAvatar(baby, size: 36)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(baby.name.isEmpty ? "Unnamed" : baby.name)
                                .font(BTTypography.label)
                                .tracking(BTTracking.label)
                                .foregroundStyle(Color.btTextPrimary)
                            Text(babySubtitle(baby))
                                .font(.caption)
                                .foregroundStyle(Color.btTextSecondary)
                        }

                        Spacer()

                        if baby.stableID == activityManager.baby?.stableID {
                            Image(systemName: "checkmark")
                                .foregroundStyle(Color.btFeedAccent)
                                .fontWeight(.semibold)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        activityManager.selectBaby(baby)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            babyToDelete = baby
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .listRowBackground(Color.btBackground)
                    .listRowSeparatorTint(Color.btDivider)
                    .listRowInsets(EdgeInsets(
                        top: 8,
                        leading: BTSpacing.cardPaddingHorizontal,
                        bottom: 8,
                        trailing: BTSpacing.cardPaddingHorizontal
                    ))
                }
            }
            .listStyle(.plain)
            .scrollDisabled(true)
            .scrollContentBackground(.hidden)
            .frame(height: CGFloat(activityManager.allBabies.count) * 56)
        }
        .background(Color.btBackground)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.card, style: .continuous))
        .cardShadow()
    }

    // MARK: - Baby Helpers

    @ViewBuilder
    private func babyAvatar(_ baby: Baby, size: CGFloat) -> some View {
        if let photoData = baby.photoData, let uiImage = UIImage(data: photoData) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                .fill(Color.btPhotoPlaceholder)
                .frame(width: size, height: size)
                .overlay {
                    Text(String((baby.name.isEmpty ? "?" : baby.name).prefix(1)).uppercased())
                        .font(.system(size: size * 0.44, weight: .semibold))
                        .foregroundStyle(Color.btTextMuted)
                }
        }
    }

    private func babySubtitle(_ baby: Baby) -> String {
        let status = activityManager.isBabyShared(baby) ? "Shared" : "Local only"
        return "\(status) · Added \(baby.createdAt.formatted(date: .abbreviated, time: .omitted))"
    }

    private func deleteBabyConfirmation(_ baby: Baby) -> some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 8)

            babyAvatar(baby, size: 80)

            VStack(spacing: 4) {
                Text(baby.name.isEmpty ? "Unnamed" : baby.name)
                    .font(.title3.weight(.semibold))
                Text(babySubtitle(baby))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Text("This will permanently delete this baby and all their tracked events.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Spacer()

            VStack(spacing: 12) {
                Button(role: .destructive) {
                    activityManager.deleteBaby(baby)
                    babyToDelete = nil
                } label: {
                    Text("Delete Baby")
                        .font(BTTypography.label)
                        .tracking(BTTracking.label)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(.red)
                        .clipShape(Capsule())
                }

                Button {
                    babyToDelete = nil
                } label: {
                    Text("Cancel")
                        .font(BTTypography.label)
                        .tracking(BTTracking.label)
                        .foregroundStyle(Color.btTextSecondary)
                }
            }
        }
        .padding(24)
        .presentationDetents([.medium])
    }

    // MARK: - Add Baby Button

    @State private var showAddBaby = false

    private var addBabyButton: some View {
        Button {
            showAddBaby = true
        } label: {
            HStack {
                Image(systemName: "plus.circle.fill")
                Text("Add Baby")
            }
            .font(BTTypography.label)
            .tracking(BTTracking.label)
            .foregroundStyle(Color.btFeedAccent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.btBackground)
            .clipShape(RoundedRectangle(cornerRadius: BTRadius.card, style: .continuous))
            .cardShadow()
        }
        .sheet(isPresented: $showAddBaby) {
            AddBabyView()
        }
    }

    // MARK: - Time Bindings

    private func feedsPerDayBinding(_ baby: Baby) -> Binding<Int> {
        Binding(
            get: { baby.customFeedsPerDay },
            set: { newValue in activityManager.updateBaby { $0.customFeedsPerDay = newValue } }
        )
    }

    private func ageDefaultFeedsPerDay(_ baby: Baby) -> Int {
        let table = AgeTable.forAge(days: baby.ageInDays)
        return (table.expectedFeedsPerDay.lowerBound + table.expectedFeedsPerDay.upperBound) / 2
    }

    private func feedIntervalBinding(_ baby: Baby) -> Binding<Int> {
        Binding(
            get: { baby.customFeedIntervalMinutes },
            set: { newValue in activityManager.updateBaby { $0.customFeedIntervalMinutes = newValue } }
        )
    }

    private func bedtimeBinding(_ baby: Baby) -> Binding<Date> {
        Binding(
            get: {
                var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
                components.hour = baby.bedtimeHour
                components.minute = baby.bedtimeMinute
                return Calendar.current.date(from: components) ?? Date()
            },
            set: { date in
                let components = Calendar.current.dateComponents([.hour, .minute], from: date)
                activityManager.updateBaby {
                    $0.bedtimeHour = components.hour ?? 19
                    $0.bedtimeMinute = components.minute ?? 0
                }
            }
        )
    }

    private func dreamFeedBinding(_ baby: Baby) -> Binding<Date> {
        Binding(
            get: {
                var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
                components.hour = baby.dreamFeedHour
                components.minute = baby.dreamFeedMinute
                return Calendar.current.date(from: components) ?? Date()
            },
            set: { date in
                let components = Calendar.current.dateComponents([.hour, .minute], from: date)
                activityManager.updateBaby {
                    $0.dreamFeedHour = components.hour ?? 22
                    $0.dreamFeedMinute = components.minute ?? 30
                }
            }
        )
    }
}

// MARK: - Add Baby View

struct AddBabyView: View {
    @Environment(ActivityManager.self) private var activityManager
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var birthdate = Date()
    @State private var bedtime = Calendar.current.date(
        from: DateComponents(hour: 19, minute: 0)
    ) ?? Date()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: BTSpacing.cardGap) {
                    VStack(alignment: .leading, spacing: 16) {
                        LabeledField(label: "Name") {
                            TextField("Baby's name", text: $name)
                                .textContentType(.name)
                        }

                        LabeledField(label: "Birthday") {
                            DatePicker("", selection: $birthdate, displayedComponents: .date)
                                .labelsHidden()
                        }

                        LabeledField(label: "Bedtime") {
                            DatePicker("", selection: $bedtime, displayedComponents: .hourAndMinute)
                                .labelsHidden()
                        }
                    }
                    .padding(.top, BTSpacing.cardPaddingTop)
                    .padding(.horizontal, BTSpacing.cardPaddingHorizontal)
                    .padding(.bottom, BTSpacing.cardPaddingBottom)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.btBackground)
                    .clipShape(RoundedRectangle(cornerRadius: BTRadius.card, style: .continuous))
                    .cardShadow()
                }
                .padding(.horizontal, BTSpacing.pageMargin)
                .padding(.vertical, 20)
            }
            .background(Color.btBackground)
            .navigationTitle("Add Baby")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let components = Calendar.current.dateComponents([.hour, .minute], from: bedtime)
                        let baby = activityManager.addBaby(
                            name: name,
                            birthdate: birthdate,
                            bedtimeHour: components.hour ?? 19,
                            bedtimeMinute: components.minute ?? 0
                        )
                        activityManager.selectBaby(baby)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

// MARK: - Welcome View (first launch)

struct WelcomeView: View {
    @Environment(ActivityManager.self) private var activityManager
    @AppStorage("selectedBabyID") private var selectedBabyID: String?

    @State private var name = "Kaia"
    @State private var birthdate = Calendar.current.date(
        from: DateComponents(year: 2025, month: 10, day: 17)
    ) ?? Date()
    @State private var bedtime = Calendar.current.date(
        from: DateComponents(hour: 19, minute: 0)
    ) ?? Date()
    @State private var dreamFeedEnabled = true
    @State private var dreamFeedTime = Calendar.current.date(
        from: DateComponents(hour: 22, minute: 0)
    ) ?? Date()
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var photoData: Data?
    @State private var showJoinShare = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Text("Who's your baby?")
                .font(.system(size: 28, weight: .bold))
                .tracking(-1)
                .foregroundStyle(Color.btTextPrimary)

            Spacer()

            // Profile image picker
            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                Group {
                    if let photoData, let uiImage = UIImage(data: photoData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 200, height: 200)
                            .clipShape(RoundedRectangle(cornerRadius: BTRadius.card, style: .continuous))
                    } else {
                        RoundedRectangle(cornerRadius: BTRadius.card, style: .continuous)
                            .fill(Color.btPhotoPlaceholder)
                            .frame(width: 200, height: 200)
                            .overlay {
                                Image(systemName: "photo.on.rectangle.angled")
                                    .font(.system(size: 48))
                                    .foregroundStyle(Color.btTextMuted)
                            }
                    }
                }
                .animation(.easeInOut(duration: 0.3), value: photoData)
            }
            .onChange(of: selectedPhoto) { _, newItem in
                guard let newItem else { return }
                Task {
                    if let data = try? await newItem.loadTransferable(type: Data.self),
                       let compressed = ImageUtilities.resizeForProfile(data: data) {
                        photoData = compressed
                    }
                    selectedPhoto = nil
                }
            }

            Spacer()

            VStack(alignment: .leading, spacing: 16) {
                TextField("Baby's name", text: $name)
                    .textContentType(.name)
                    .font(.system(size: 22, weight: .medium))
                    .tracking(-0.4)

                LabeledField(label: "Birthday") {
                    DatePicker("", selection: $birthdate, displayedComponents: .date)
                        .labelsHidden()
                }

                LabeledField(label: "Bedtime") {
                    DatePicker("", selection: $bedtime, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                }

                LabeledField(label: "Dream Feed") {
                    Toggle("", isOn: $dreamFeedEnabled)
                        .labelsHidden()
                }

                if dreamFeedEnabled {
                    LabeledField(label: "Dream Feed Time") {
                        DatePicker("", selection: $dreamFeedTime, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .padding(.top, BTSpacing.cardPaddingTop)
            .padding(.horizontal, BTSpacing.cardPaddingHorizontal)
            .padding(.bottom, BTSpacing.cardPaddingBottom)
            .background(Color.btBackground)
            .clipShape(RoundedRectangle(cornerRadius: BTRadius.card, style: .continuous))
            .cardShadow()
            .animation(.spring(response: 0.5, dampingFraction: 0.85), value: dreamFeedEnabled)

            Spacer()

            Button {
                let bedtimeComponents = Calendar.current.dateComponents([.hour, .minute], from: bedtime)
                let dreamFeedComponents = Calendar.current.dateComponents([.hour, .minute], from: dreamFeedTime)
                let baby = activityManager.addBaby(
                    name: name,
                    birthdate: birthdate,
                    bedtimeHour: bedtimeComponents.hour ?? 19,
                    bedtimeMinute: bedtimeComponents.minute ?? 0,
                    dreamFeedEnabled: dreamFeedEnabled,
                    dreamFeedHour: dreamFeedComponents.hour ?? 22,
                    dreamFeedMinute: dreamFeedComponents.minute ?? 0,
                    photoData: photoData
                )
                activityManager.selectBaby(baby)
                selectedBabyID = baby.stableID
            } label: {
                Text("Get Started")
                    .font(BTTypography.label)
                    .tracking(BTTracking.label)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.btFeedAccent)
                    .clipShape(Capsule())
                    .cardShadow()
            }
            .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)

            Button {
                showJoinShare = true
            } label: {
                Text("Join shared baby")
                    .font(BTTypography.label)
                    .tracking(BTTracking.label)
                    .foregroundStyle(Color.btFeedAccent)
            }
            .padding(.bottom, 40)
        }
        .padding(.horizontal, BTSpacing.pageMargin)
        .background(Color.btBackground)
        .sheet(isPresented: $showJoinShare) {
            JoinShareView()
        }
    }
}

// MARK: - Labeled Field Helper

private struct LabeledField<Content: View>: View {
    let label: String
    @ViewBuilder let content: Content

    var body: some View {
        HStack {
            Text(label)
                .font(BTTypography.label)
                .tracking(BTTracking.label)
                .foregroundStyle(Color.btTextSecondary)

            Spacer()

            content
        }
    }
}
