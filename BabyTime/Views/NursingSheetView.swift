//
//  NursingSheetView.swift
//  BabyTime
//
//  Nursing session sheet: start/stop timer, editable times, save/reset.
//  Supports both live timer and manual past-nursing logging.
//  Timer persists immediately to SQLiteData for multi-device sync.
//

import Dependencies
import SwiftUI

struct NursingSheetView: View {
    @Environment(ActivityManager.self) private var activityManager
    @Environment(\.dismiss) private var dismiss

    var editingEvent: FeedEvent?

    // Draft times for manual entry (before any SwiftData event exists)
    @State private var draftStartTime: Date?
    @State private var draftEndTime: Date?

    // Cooldown: suppresses timer toggle briefly after a DatePicker tap
    @State private var pickerInteractionDate: Date?
    @State private var showDeleteConfirmation = false

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

    private var showReset: Bool {
        !isEditing && activityManager.hasNursingSession && !activityManager.isNursingActive
    }

    private var canSave: Bool {
        if isEditing { return draftStartTime != nil && draftEndTime != nil }
        return activityManager.hasNursingSession || (draftStartTime != nil && draftEndTime != nil)
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
                if let event = editingEvent {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showDeleteConfirmation = true
                        } label: {
                            Image(systemName: "trash")
                        }
                        .tint(.red)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(role: .confirm) {
                        if let event = editingEvent, let start = draftStartTime, let end = draftEndTime {
                            activityManager.updateNursingEvent(event, startTime: start, endTime: end, side: event.side)
                        } else if activityManager.hasNursingSession {
                            activityManager.saveNursing()
                        } else if let start = draftStartTime, let end = draftEndTime {
                            activityManager.saveNursingManual(startTime: start, endTime: end)
                        }
                        dismiss()
                    }
                    .tint(Color.btFeedAccent)
                    .disabled(!canSave)
                }
            }
            .alert("Delete this event?", isPresented: $showDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    if let event = editingEvent {
                        activityManager.deleteFeedEvent(event)
                    }
                    dismiss()
                }
                Button("Cancel", role: .cancel) { }
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
        guard let start = effectiveStartTime else { return "00 : 00 : 00" }

        let reference: Date
        if activityManager.isNursingActive {
            reference = date                      // live ticking
        } else if let end = effectiveEndTime {
            reference = end                       // static stopped/draft duration
        } else {
            return "00 : 00 : 00"                 // draft start only → no duration yet
        }

        let elapsed = max(0, reference.timeIntervalSince(start))
        let hours = Int(elapsed) / 3600
        let minutes = (Int(elapsed) % 3600) / 60
        let seconds = Int(elapsed) % 60
        return String(format: "%02d : %02d : %02d", hours, minutes, seconds)
    }

    private var timerDisplay: some View {
        VStack(spacing: 8) {
            SwiftUI.TimelineView(.periodic(from: .now, by: 1)) { context in
                Text(durationString(at: context.date))
                    .font(.system(size: 56, weight: .bold))
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

                Button {
                    activityManager.resetNursing()
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
                } else if activityManager.hasNursingSession {
                    activityManager.nursingStartTime = newValue
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
                } else if activityManager.hasNursingSession {
                    activityManager.nursingEndTime = newValue
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
    let manager = withDependencies {
        try! $0.bootstrapTestDatabase()
    } operation: {
        @Dependency(\.defaultDatabase) var database
        return ActivityManager(database: database)
    }
    NursingSheetView()
        .environment(manager)
}
