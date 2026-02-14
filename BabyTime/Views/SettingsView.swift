//
//  SettingsView.swift
//  BabyTime
//
//  Settings: baby info, schedule, baby list, add/delete.
//

import SwiftUI
import SwiftData
import PhotosUI

struct SettingsView: View {
    @Environment(ActivityManager.self) private var activityManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: BTSpacing.cardGap) {
                    if let baby = activityManager.baby {
                        babyInfoCard(baby)
                        scheduleCard(baby)
                    }

                    if activityManager.allBabies.count > 1 {
                        babySelectorCard
                    }

                    addBabyButton
                }
                .padding(.horizontal, BTSpacing.pageMargin)
                .padding(.vertical, 20)
            }
            .background(Color.btBackground)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
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
                    set: { baby.name = $0 }
                ))
                .textContentType(.name)
            }

            LabeledField(label: "Birthday") {
                DatePicker(
                    "",
                    selection: Binding(
                        get: { baby.birthdate },
                        set: { baby.birthdate = $0 }
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

            LabeledField(label: "Dream Feed") {
                HStack {
                    Toggle("", isOn: Binding(
                        get: { baby.dreamFeedEnabled },
                        set: { baby.dreamFeedEnabled = $0 }
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

    // MARK: - Baby Selector

    private var babySelectorCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Babies")
                .font(BTTypography.photoDate)
                .tracking(BTTracking.photoDate)
                .foregroundStyle(Color.btTextPrimary)

            ForEach(activityManager.allBabies, id: \.stableID) { baby in
                HStack {
                    Text(baby.name.isEmpty ? "Unnamed" : baby.name)
                        .font(BTTypography.label)
                        .tracking(BTTracking.label)
                        .foregroundStyle(Color.btTextPrimary)

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

                if baby.stableID != activityManager.allBabies.last?.stableID {
                    Divider()
                        .foregroundStyle(Color.btDivider)
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
                baby.bedtimeHour = components.hour ?? 19
                baby.bedtimeMinute = components.minute ?? 0
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
                baby.dreamFeedHour = components.hour ?? 22
                baby.dreamFeedMinute = components.minute ?? 30
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

    @State private var name = ""
    @State private var birthdate = Date()
    @State private var bedtime = Calendar.current.date(
        from: DateComponents(hour: 19, minute: 0)
    ) ?? Date()
    @State private var dreamFeedEnabled = true
    @State private var dreamFeedTime = Calendar.current.date(
        from: DateComponents(hour: 22, minute: 0)
    ) ?? Date()
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var photoData: Data?

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
            .padding(.bottom, 40)
        }
        .padding(.horizontal, BTSpacing.pageMargin)
        .background(Color.btBackground)
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
