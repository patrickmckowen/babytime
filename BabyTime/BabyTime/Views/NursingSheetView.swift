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
                Spacer()

                // Timer display
                timerDisplay

                Spacer()

                // Play / Stop button
                playStopButton
                    .padding(.bottom, 40)

                // Start / End time rows
                timesList

                // Reset / Save buttons
                actionButtons
                    .padding(.top, 24)
                    .padding(.bottom, 16)
            }
            .padding(.horizontal, BTSpacing.pageMargin)
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

    // MARK: - Timer Display

    private var timerDisplay: some View {
        SwiftUI.TimelineView(.periodic(from: .now, by: 1)) { context in
            Text(activityManager.nursingTimerString(at: context.date))
                .font(.system(size: 64, weight: .bold, design: .monospaced))
                .tracking(-2)
                .foregroundStyle(Color.btTextPrimary)
        }
    }

    // MARK: - Play / Stop Button

    private var playStopButton: some View {
        Button {
            if activityManager.isNursingActive {
                activityManager.stopNursing()
            } else if !activityManager.hasNursingSession {
                activityManager.startNursing()
            }
        } label: {
            Image(systemName: buttonIcon)
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 80, height: 80)
                .background(Color.btFeedAccent)
                .clipShape(Circle())
        }
        .disabled(activityManager.hasNursingSession && !activityManager.isNursingActive)
    }

    private var buttonIcon: String {
        if activityManager.isNursingActive {
            return "stop.fill"
        }
        return "play.fill"
    }

    // MARK: - Times List

    @ViewBuilder
    private var timesList: some View {
        @Bindable var manager = activityManager

        VStack(spacing: 0) {
            // Start time row
            if let startTime = activityManager.nursingStartTime {
                HStack {
                    Text("Start")
                        .font(BTTypography.label)
                        .tracking(BTTracking.label)
                        .foregroundStyle(Color.btTextSecondary)

                    Spacer()

                    DatePicker(
                        "",
                        selection: Binding(
                            get: { manager.nursingStartTime ?? Date() },
                            set: { manager.nursingStartTime = $0 }
                        ),
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .labelsHidden()
                }
                .padding(.vertical, 14)

                Divider()
                    .foregroundStyle(Color.btDivider)
            }

            // End time row
            if let endTime = activityManager.nursingEndTime {
                HStack {
                    Text("End")
                        .font(BTTypography.label)
                        .tracking(BTTracking.label)
                        .foregroundStyle(Color.btTextSecondary)

                    Spacer()

                    DatePicker(
                        "",
                        selection: Binding(
                            get: { manager.nursingEndTime ?? Date() },
                            set: { manager.nursingEndTime = $0 }
                        ),
                        displayedComponents: [.hourAndMinute]
                    )
                    .labelsHidden()
                }
                .padding(.vertical, 14)
            }
        }
        .padding(.horizontal, BTSpacing.cardPaddingHorizontal)
        .background(Color.btBackground)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.card, style: .continuous))
        .cardShadow()
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
                    .clipShape(RoundedRectangle(cornerRadius: BTRadius.card, style: .continuous))
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
                    .clipShape(RoundedRectangle(cornerRadius: BTRadius.card, style: .continuous))
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
