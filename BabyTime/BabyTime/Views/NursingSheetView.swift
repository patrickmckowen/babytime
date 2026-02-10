//
//  NursingSheetView.swift
//  BabyTime
//
//  Nursing session sheet: start/stop timer, editable times, save/reset.
//

import SwiftUI

struct NursingSheetView: View {
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
            .navigationTitle("Nursing")
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
        if activityManager.isNursingActive {
            activityManager.stopNursing()
        } else {
            // Start or restart
            if activityManager.hasNursingSession && !activityManager.isNursingActive {
                // Reset and start new session
                activityManager.resetNursing()
            }
            activityManager.startNursing()
        }
    }

    // MARK: - Timer Display

    private var timerDisplay: some View {
        VStack(spacing: 8) {
            SwiftUI.TimelineView(.periodic(from: .now, by: 1)) { context in
                Text(activityManager.nursingTimerString(at: context.date))
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
        if activityManager.isNursingActive {
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
            // Start time row - always visible
            HStack {
                Text("Start")
                    .font(BTTypography.label)
                    .tracking(BTTracking.label)
                    .foregroundStyle(Color.btTextSecondary)

                Spacer()

                HStack(spacing: 12) {
                    // Day select menu — Today / Yesterday
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

                    // Time picker — fully native
                    DatePicker(
                        "",
                        selection: Binding(
                            get: { manager.nursingStartTime ?? Date() },
                            set: { manager.nursingStartTime = $0 }
                        ),
                        displayedComponents: [.hourAndMinute]
                    )
                    .labelsHidden()
                }
            }
            .padding(.vertical, 14)

            Divider()
                .foregroundStyle(Color.btDivider)

            // End time row - always visible, disabled until stopped
            HStack {
                Text("End")
                    .font(BTTypography.label)
                    .tracking(BTTracking.label)
                    .foregroundStyle(Color.btTextSecondary)

                Spacer()

                let hasEnd = manager.nursingEndTime != nil

                DatePicker(
                    "",
                    selection: Binding(
                        get: { manager.nursingEndTime ?? Date() },
                        set: { manager.nursingEndTime = $0 }
                    ),
                    displayedComponents: [.hourAndMinute]
                )
                .labelsHidden()
                .disabled(!hasEnd || activityManager.isNursingActive)
                .opacity(hasEnd ? (activityManager.isNursingActive ? 0.5 : 1.0) : 0.0)
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

    // MARK: - Date Label

    private var startDateLabel: String {
        guard let date = activityManager.nursingStartTime else { return "Today" }
        if Calendar.current.isDateInYesterday(date) { return "Yesterday" }
        return "Today"
    }

    // MARK: - Day Selection

    private func updateStartDay(to day: String) {
        guard let current = activityManager.nursingStartTime else { return }
        let calendar = Calendar.current
        let time = calendar.dateComponents([.hour, .minute, .second], from: current)

        let targetDay: Date = if day == "Yesterday" {
            calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: Date()))!
        } else {
            calendar.startOfDay(for: Date())
        }

        var merged = calendar.dateComponents([.year, .month, .day], from: targetDay)
        merged.hour = time.hour
        merged.minute = time.minute
        merged.second = time.second
        activityManager.nursingStartTime = calendar.date(from: merged)
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: 14) {
            // Reset
            Button {
                activityManager.resetNursing()
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
            .disabled(!activityManager.hasNursingSession)

            // Save
            Button {
                activityManager.saveNursing()
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
            .disabled(!activityManager.hasNursingSession)
        }
    }
}

#Preview {
    NursingSheetView()
        .environment(ActivityManager())
}
