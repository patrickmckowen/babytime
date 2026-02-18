//
//  SleepSheetView.swift
//  BabyTime
//
//  Sleep session sheet: start/stop timer, editable times, save/reset.
//  Supports both live timer and manual past-sleep logging.
//  Timer persists immediately to SwiftData for multi-device sync.
//

import SwiftUI
import SwiftData

struct SleepSheetView: View {
    @Environment(ActivityManager.self) private var activityManager
    @Environment(\.dismiss) private var dismiss

    var editingEvent: SleepEvent?

    // Draft times for manual entry (before any SwiftData event exists)
    @State private var draftStartTime: Date?
    @State private var draftEndTime: Date?

    // Cooldown: suppresses timer toggle briefly after a DatePicker tap
    @State private var pickerInteractionDate: Date?

    private var isEditing: Bool { editingEvent != nil }

    // Effective times: editing event → active timer event → draft
    private var effectiveStartTime: Date? {
        if isEditing { return draftStartTime }
        return activityManager.sleepStartTime ?? draftStartTime
    }

    private var effectiveEndTime: Date? {
        if isEditing { return draftEndTime }
        return activityManager.sleepEndTime ?? draftEndTime
    }

    private var canSave: Bool {
        if isEditing { return draftStartTime != nil && draftEndTime != nil }
        return activityManager.hasSleepSession || (draftStartTime != nil && draftEndTime != nil)
    }

    private var showReset: Bool {
        !isEditing && activityManager.hasSleepSession && !activityManager.isSleepActive
    }

    private var isPickerRecentlyActive: Bool {
        guard let d = pickerInteractionDate else { return false }
        return Date().timeIntervalSince(d) < 0.5
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Timer tap target
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
            }
            .padding(.horizontal, BTSpacing.pageMargin)
            .background(Color.btBackground)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.down")
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(role: .confirm) {
                        if let event = editingEvent, let start = draftStartTime, let end = draftEndTime {
                            activityManager.updateSleepEvent(event, startTime: start, endTime: end)
                        } else if activityManager.hasSleepSession {
                            activityManager.saveSleep()
                        } else if let start = draftStartTime, let end = draftEndTime {
                            activityManager.saveSleepManual(startTime: start, endTime: end)
                        }
                        dismiss()
                    }
                    .tint(Color.btSleepAccent)
                    .disabled(!canSave)
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
        if activityManager.isSleepActive {
            // Running → Stop
            activityManager.stopSleep()
        } else if activityManager.hasSleepSession {
            // Stopped → Resume (clear endTime, timer resumes)
            activityManager.resumeSleep()
        } else {
            // Not started → Start (preserve manual start time if set)
            activityManager.startSleep(at: draftStartTime)
            draftStartTime = nil
            draftEndTime = nil
        }
    }

    // MARK: - Timer Display

    private func durationString(at date: Date) -> String {
        guard let start = effectiveStartTime else { return "00:00" }

        let reference: Date
        if activityManager.isSleepActive {
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
                    .font(.system(size: 72, weight: .regular, design: .default))
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
        } else if activityManager.isSleepActive {
            return "Tap to stop"
        } else if activityManager.hasSleepSession {
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

                Button {
                    activityManager.resetSleep()
                    draftStartTime = nil
                    draftEndTime = nil
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(Color.btTextPrimary)
                }
                .opacity(showReset ? 1 : 0)
                .allowsHitTesting(showReset)
                .padding(.trailing, 16)

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
                .simultaneousGesture(TapGesture().onEnded { pickerInteractionDate = Date() })
            }
            .padding(.vertical, 14)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Time Bindings

    private var startTimeBinding: Binding<Date> {
        Binding(
            get: { effectiveStartTime ?? Date() },
            set: { newValue in
                if isEditing {
                    draftStartTime = newValue
                } else if activityManager.hasSleepSession {
                    activityManager.sleepStartTime = newValue
                } else {
                    draftStartTime = newValue
                    // Auto-initialize end time so duration displays and save enables
                    if draftEndTime == nil { draftEndTime = Date() }
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
                } else if activityManager.hasSleepSession {
                    activityManager.sleepEndTime = newValue
                } else {
                    draftEndTime = newValue
                    // Auto-initialize start time so duration displays and save enables
                    if draftStartTime == nil { draftStartTime = Date() }
                }
            }
        )
    }

}

#Preview {
    let container = try! ModelContainer(
        for: Baby.self, FeedEvent.self, SleepEvent.self, WakeEvent.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    SleepSheetView()
        .environment(ActivityManager(modelContext: container.mainContext))
}
