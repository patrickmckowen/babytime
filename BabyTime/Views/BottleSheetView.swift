//
//  BottleSheetView.swift
//  BabyTime
//
//  Bottle feed log sheet: slider for ounces, save/cancel.
//

import SwiftUI
import SwiftData

struct BottleSheetView: View {
    @Environment(ActivityManager.self) private var activityManager
    @Environment(\.dismiss) private var dismiss

    var editingEvent: FeedEvent?

    @State private var amountOz: Double = 4.0
    @State private var selectedTime: Date = Date()

    private var isEditing: Bool { editingEvent != nil }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Amount display — center area
                VStack {
                    Spacer()
                    amountDisplay
                    Spacer()
                }
                .frame(maxWidth: .infinity)

                // Controls card
                controlsCard

                // Cancel / Save buttons
                actionButtons
                    .padding(.top, 24)
            }
            .padding(.horizontal, BTSpacing.pageMargin)
            .padding(.bottom, BTSpacing.pageMargin)
            .background(Color.btBackground)
            .navigationTitle(isEditing ? "Edit Bottle" : "Bottle")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            if let event = editingEvent {
                amountOz = event.amountOz
                selectedTime = event.startTime
            }
        }
    }

    // MARK: - Amount Display

    private var amountDisplay: some View {
        VStack(spacing: 8) {
            Text(formattedAmount)
                .font(.system(size: 64, weight: .regular, design: .default))
                .monospacedDigit()
                .tracking(-2)
                .foregroundStyle(Color.btTextPrimary)
                .contentTransition(.numericText())
                .animation(.snappy(duration: 0.2), value: amountOz)

            Text("ounces")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.btTextSecondary)
        }
    }

    private var formattedAmount: String {
        if amountOz.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(amountOz))"
        }
        return String(format: "%.1f", amountOz)
    }

    // MARK: - Controls Card

    private var controlsCard: some View {
        VStack(spacing: 0) {
            // Amount slider
            VStack(spacing: 14) {
                Slider(value: $amountOz, in: 1...8, step: 0.5)
                    .tint(Color.btFeedAccent)

                // Tick marks
                HStack(spacing: 0) {
                    ForEach(0..<15) { index in
                        let isWhole = index % 2 == 0

                        if index > 0 {
                            Spacer(minLength: 0)
                        }

                        Circle()
                            .fill(Color.btTextSecondary.opacity(isWhole ? 0.4 : 0.2))
                            .frame(width: isWhole ? 5 : 3, height: isWhole ? 5 : 3)

                        if index < 14 {
                            Spacer(minLength: 0)
                        }
                    }
                }
                .padding(.horizontal, 4)

                // End labels
                HStack {
                    Text("1")
                        .font(BTTypography.caption)
                        .foregroundStyle(Color.btTextSecondary)
                    Spacer()
                    Text("8")
                        .font(BTTypography.caption)
                        .foregroundStyle(Color.btTextSecondary)
                }
            }
            .padding(.horizontal, BTSpacing.cardPaddingHorizontal)
            .padding(.vertical, 20)

            // Divider
            Rectangle()
                .fill(Color.btDivider)
                .frame(height: 1)
                .padding(.horizontal, BTSpacing.cardPaddingHorizontal)

            // Time row
            HStack {
                Text("Time")
                    .font(BTTypography.label)
                    .tracking(BTTracking.label)
                    .foregroundStyle(Color.btTextPrimary)

                Spacer()

                DatePicker("", selection: $selectedTime, in: ...Date(), displayedComponents: [.hourAndMinute])
                    .labelsHidden()
                    .tint(Color.btFeedAccent)
            }
            .padding(.horizontal, BTSpacing.cardPaddingHorizontal)
            .padding(.vertical, 16)
        }
        .background(Color.btBackground)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.card, style: .continuous))
        .cardShadow()
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: 14) {
            // Cancel
            Button {
                dismiss()
            } label: {
                Text("Cancel")
                    .font(BTTypography.label)
                    .tracking(BTTracking.label)
                    .foregroundStyle(Color.btTextSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.btBackground)
                    .clipShape(Capsule())
                    .cardShadow()
            }

            // Save
            Button {
                if let event = editingEvent {
                    activityManager.updateFeedEvent(event, amountOz: amountOz, at: selectedTime)
                } else {
                    activityManager.saveBottle(amountOz: amountOz, at: selectedTime)
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
        }
    }
}

#Preview {
    let container = try! ModelContainer(
        for: Baby.self, FeedEvent.self, SleepEvent.self, WakeEvent.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    BottleSheetView()
        .environment(ActivityManager(modelContext: container.mainContext))
}
