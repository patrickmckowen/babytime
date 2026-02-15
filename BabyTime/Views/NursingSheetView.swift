//
//  NursingSheetView.swift
//  BabyTime
//
//  Nursing session sheet: start/stop timer, editable times, save/reset.
//  Supports both live timer and manual past-nursing logging.
//  Timer persists immediately to SwiftData for multi-device sync.
//

import SwiftUI
import SwiftData

struct NursingSheetView: View {
    @Environment(ActivityManager.self) private var activityManager
    @Environment(\.dismiss) private var dismiss

    var editingEvent: FeedEvent?

    // Draft times for manual entry (before any SwiftData event exists)
    @State private var draftStartTime: Date?
    @State private var draftEndTime: Date?

    // Cooldown: suppresses timer toggle briefly after a DatePicker tap
    @State private var pickerInteractionDate: Date?

    private var isEditing: Bool { editingEvent != nil }

    // Effective times: editing event → active timer event → draft
    private var effectiveStartTime: Date? {
        if isEditing { return draftStartTime }
        return activityManager.nursingStartTime ?? draftStartTime
    }

    private var effectiveEndTime: Date? {
        if isEditing { return draftEndTime }
        return activityManager.nursingEndTime ?? draftEndTime
    }

    private var canSave: Bool {
        if isEditing { return draftStartTime != nil && draftEndTime != nil }
        return activityManager.hasNursingSession || (draftStartTime != nil && draftEndTime != nil)
    }

    private var canReset: Bool {
        if isEditing { return false }
        return activityManager.hasNursingSession || draftStartTime != nil || draftEndTime != nil
    }

    private var isPickerRecentlyActive: Bool {
        guard let d = pickerInteractionDate else { return false }
        return Date().timeIntervalSince(d) < 0.5
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Timer tap target — entire area from navbar to timesList
                VStack {
                    Spacer()
                    timerDisplay
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .onTapGesture {
                    guard !isEditing, !isPickerRecentlyActive else { return }
                    toggleTimer()
                }

                // Start / End time rows (always visible)
                timesList

                // Reset / Save buttons
                actionButtons
                    .padding(.top, 24)
            }
            .padding(.horizontal, BTSpacing.pageMargin)
            .padding(.bottom, BTSpacing.pageMargin)
            .background(Color.btBackground)
            .navigationTitle(isEditing ? "Edit Nursing" : "Nursing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.down")
                            .fontWeight(.semibold)
                    }
                }
            }
        }
        .onAppear {
            if let event = editingEvent {
                draftStartTime = event.startTime
                draftEndTime = event.endTime
            }
        }
    }

    // MARK: - Timer Actions

    private func toggleTimer() {
        if activityManager.isNursingActive {
            activityManager.stopNursing()
        } else if activityManager.hasNursingSession {
            activityManager.resumeNursing()
        } else {
            activityManager.startNursing(at: draftStartTime)
            draftStartTime = nil
            draftEndTime = nil
        }
    }

    // MARK: - Timer Display

    private func durationString(at date: Date) -> String {
        guard let start = effectiveStartTime else { return "00:00" }

        let reference: Date
        if activityManager.isNursingActive {
            reference = date                      // live ticking
        } else if let end = effectiveEndTime {
            reference = end                       // static stopped/draft duration
        } else {
            return "00:00"                        // draft start only → no duration yet
        }

        let elapsed = max(0, reference.timeIntervalSince(start))
        let minutes = Int(elapsed) / 60
        let seconds = Int(elapsed) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private var timerDisplay: some View {
        VStack(spacing: 8) {
            SwiftUI.TimelineView(.periodic(from: .now, by: 1)) { context in
                Text(durationString(at: context.date))
                    .font(.system(size: 64, weight: .regular, design: .default))
                    .monospacedDigit()
                    .tracking(-2)
                    .foregroundStyle(Color.btTextPrimary)
            }

            Text(timerHintText)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.btTextSecondary)
        }
    }

    private var timerHintText: String {
        if isEditing {
            return "duration"
        } else if activityManager.isNursingActive {
            return "Tap to stop"
        } else if activityManager.hasNursingSession {
            return "Tap to resume"
        } else {
            return "Tap to start"
        }
    }

    // MARK: - Times List

    @ViewBuilder
    private var timesList: some View {
        VStack(spacing: 0) {
            // Start time row
            HStack {
                Text("Start")
                    .font(BTTypography.label)
                    .tracking(BTTracking.label)
                    .foregroundStyle(Color.btTextSecondary)

                Spacer()

                DatePicker(
                    "",
                    selection: startTimeBinding,
                    in: ...Date(),
                    displayedComponents: [.hourAndMinute]
                )
                .labelsHidden()
                .simultaneousGesture(TapGesture().onEnded { pickerInteractionDate = Date() })
            }
            .padding(.vertical, 14)

            Divider()
                .foregroundStyle(Color.btDivider)

            // End time row
            HStack {
                Text("End")
                    .font(BTTypography.label)
                    .tracking(BTTracking.label)
                    .foregroundStyle(Color.btTextSecondary)

                Spacer()

                DatePicker(
                    "",
                    selection: endTimeBinding,
                    in: ...Date(),
                    displayedComponents: [.hourAndMinute]
                )
                .labelsHidden()
                .disabled(!isEditing && activityManager.isNursingActive)
                .opacity(!isEditing && activityManager.isNursingActive ? 0.0 : 1.0)
                .overlay {
                    if !isEditing && activityManager.isNursingActive {
                        Text("—")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Color.btTextSecondary.opacity(0.4))
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
                .simultaneousGesture(TapGesture().onEnded {
                    guard isEditing || !activityManager.isNursingActive else { return }
                    pickerInteractionDate = Date()
                })
            }
            .padding(.vertical, 14)
        }
        .padding(.horizontal, BTSpacing.cardPaddingHorizontal)
        .background(Color.btBackground)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.card, style: .continuous))
        .cardShadow()
        .padding(.vertical, 4)
    }

    // MARK: - Time Bindings

    private var startTimeBinding: Binding<Date> {
        Binding(
            get: { effectiveStartTime ?? Date() },
            set: { newValue in
                if isEditing {
                    draftStartTime = newValue
                } else if activityManager.hasNursingSession {
                    activityManager.nursingStartTime = newValue
                } else {
                    draftStartTime = newValue
                }
            }
        )
    }

    private var endTimeBinding: Binding<Date> {
        Binding(
            get: { effectiveEndTime ?? Date() },
            set: { newValue in
                if isEditing {
                    draftEndTime = newValue
                } else if activityManager.hasNursingSession {
                    activityManager.nursingEndTime = newValue
                } else {
                    draftEndTime = newValue
                }
            }
        )
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: 14) {
            Button {
                if isEditing {
                    dismiss()
                } else {
                    activityManager.resetNursing()
                    draftStartTime = nil
                    draftEndTime = nil
                }
            } label: {
                Text(isEditing ? "Cancel" : "Reset")
                    .font(BTTypography.label)
                    .tracking(BTTracking.label)
                    .foregroundStyle(Color.btTextSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.btBackground)
                    .clipShape(Capsule())
                    .cardShadow()
            }
            .disabled(!isEditing && !canReset)

            Button {
                if let event = editingEvent, let start = draftStartTime, let end = draftEndTime {
                    activityManager.updateNursingEvent(event, startTime: start, endTime: end, side: event.side)
                } else if activityManager.hasNursingSession {
                    activityManager.saveNursing()
                } else if let start = draftStartTime, let end = draftEndTime {
                    activityManager.saveNursingManual(startTime: start, endTime: end)
                }
                dismiss()
            } label: {
                Text("Save")
                    .font(BTTypography.label)
                    .tracking(BTTracking.label)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.btFeedAccent)
                    .clipShape(Capsule())
                    .cardShadow()
            }
            .disabled(!canSave)
        }
    }
}

#Preview {
    let container = try! ModelContainer(
        for: Baby.self, FeedEvent.self, SleepEvent.self, WakeEvent.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    NursingSheetView()
        .environment(ActivityManager(modelContext: container.mainContext))
}
