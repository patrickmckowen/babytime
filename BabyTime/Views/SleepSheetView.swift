//
//  SleepSheetView.swift
//  BabyTime
//
//  Sleep session sheet: start/stop timer, editable times, save/reset.
//

import SwiftUI

struct SleepSheetView: View {
    @Environment(ActivityManager.self) private var activityManager
    @Environment(\.dismiss) private var dismiss

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
            .navigationTitle("Sleep")
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
    }

    // MARK: - Timer Actions

    private func toggleTimer() {
        if activityManager.isSleepActive {
            activityManager.stopSleep()
        } else {
            if activityManager.hasSleepSession && !activityManager.isSleepActive {
                activityManager.resetSleep()
            }
            activityManager.startSleep()
        }
    }

    // MARK: - Timer Display

    private var timerDisplay: some View {
        VStack(spacing: 8) {
            SwiftUI.TimelineView(.periodic(from: .now, by: 1)) { context in
                Text(activityManager.sleepTimerString(at: context.date))
                    .font(.system(size: 64, weight: .regular, design: .default))
                    .monospacedDigit()
                    .tracking(-2)
                    .foregroundStyle(Color.btTextPrimary)
            }

            Text(timerHintText)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(Color.btTextSecondary.opacity(0.6))
        }
    }

    private var timerHintText: String {
        if activityManager.isSleepActive {
            return "Tap to stop"
        } else {
            return "Tap to start"
        }
    }

    // MARK: - Times List

    @ViewBuilder
    private var timesList: some View {
        @Bindable var manager = activityManager

        VStack(spacing: 0) {
            // Start time row
            HStack {
                Text("Start")
                    .font(BTTypography.label)
                    .tracking(BTTracking.label)
                    .foregroundStyle(Color.btTextSecondary)

                Spacer()

                HStack(spacing: 12) {
                    Menu {
                        Button("Today") { updateStartDay(to: "Today") }
                        Button("Yesterday") { updateStartDay(to: "Yesterday") }
                    } label: {
                        Text(startDateLabel)
                            .font(.body)
                            .foregroundStyle(Color(.label))
                            .padding(.horizontal, 12)
                            .frame(height: 32)
                            .background(Color(.tertiarySystemFill))
                            .clipShape(Capsule())
                    }

                    DatePicker(
                        "",
                        selection: Binding(
                            get: { manager.sleepStartTime ?? Date() },
                            set: { manager.sleepStartTime = $0 }
                        ),
                        displayedComponents: [.hourAndMinute]
                    )
                    .labelsHidden()
                }
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

                let hasEnd = manager.sleepEndTime != nil

                DatePicker(
                    "",
                    selection: Binding(
                        get: { manager.sleepEndTime ?? Date() },
                        set: { manager.sleepEndTime = $0 }
                    ),
                    displayedComponents: [.hourAndMinute]
                )
                .labelsHidden()
                .disabled(!hasEnd || activityManager.isSleepActive)
                .opacity(hasEnd ? (activityManager.isSleepActive ? 0.5 : 1.0) : 0.0)
                .overlay {
                    if !hasEnd {
                        Text("—")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Color.btTextSecondary.opacity(0.4))
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
            }
            .padding(.vertical, 14)
        }
        .padding(.horizontal, BTSpacing.cardPaddingHorizontal)
        .background(Color.btBackground)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.card, style: .continuous))
        .cardShadow()
        .padding(.vertical, 4)
    }

    // MARK: - Date Labels

    private var startDateLabel: String {
        guard let date = activityManager.sleepStartTime else { return "Today" }
        if Calendar.current.isDateInYesterday(date) { return "Yesterday" }
        return "Today"
    }

    // MARK: - Day Selection

    private func updateStartDay(to day: String) {
        guard let current = activityManager.sleepStartTime else { return }
        activityManager.sleepStartTime = shiftDate(current, toDay: day)
    }

    private func shiftDate(_ date: Date, toDay day: String) -> Date {
        let calendar = Calendar.current
        let time = calendar.dateComponents([.hour, .minute, .second], from: date)

        let targetDay: Date = if day == "Yesterday" {
            calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: Date()))!
        } else {
            calendar.startOfDay(for: Date())
        }

        var merged = calendar.dateComponents([.year, .month, .day], from: targetDay)
        merged.hour = time.hour
        merged.minute = time.minute
        merged.second = time.second
        return calendar.date(from: merged) ?? date
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: 14) {
            Button {
                activityManager.resetSleep()
            } label: {
                Text("Reset")
                    .font(BTTypography.label)
                    .tracking(BTTracking.label)
                    .foregroundStyle(Color.btTextSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.btBackground)
                    .clipShape(Capsule())
                    .cardShadow()
            }
            .disabled(!activityManager.hasSleepSession)

            Button {
                activityManager.saveSleep()
                dismiss()
            } label: {
                Text("Save")
                    .font(BTTypography.label)
                    .tracking(BTTracking.label)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.btSleepAccent)
                    .clipShape(Capsule())
                    .cardShadow()
            }
            .disabled(!activityManager.hasSleepSession)
        }
    }
}

#Preview {
    SleepSheetView()
        .environment(ActivityManager())
}
