//
//  SleepCard.swift
//  BabyTime
//
//  Sleep status card driven by DayState: awake, sleeping, bridging, bedtime.
//

import SwiftUI

struct SleepCard: View {
    let mode: Mode
    var sheetTransition: Namespace.ID
    var onTap: (() -> Void)?
    var onSleepTap: (() -> Void)?
    var onWakeTimeSubmit: ((Date) -> Void)?
    var onBedtimeSubmit: ((Date) -> Void)?

    enum Mode {
        /// Awake states — duration and detail line
        case awake(duration: String, detail: String)
        /// Sleeping states (not active timer) — engine says baby is sleeping
        case sleeping(duration: String, detail: String)
        /// Active sleep timer (user started timer from sheet)
        case sleepActive
        /// Empty state — prompt user for wake time
        case wakeTimePrompt(babyName: String)
        /// Bedtime window — prompt user to log when baby fell asleep
        case bedtimePrompt(babyName: String)
    }

    @State private var selectedWakeTime = Date()
    @State private var selectedBedtime = Date()

    var body: some View {
        Group {
            switch mode {
            case .awake(let duration, let detail):
                awakeContent(duration: duration, detail: detail)
            case .sleeping(let duration, let detail):
                sleepingContent(duration: duration, detail: detail)
            case .sleepActive:
                sleepActiveContent
            case .wakeTimePrompt(let babyName):
                wakeTimePromptContent(babyName: babyName)
            case .bedtimePrompt(let babyName):
                bedtimePromptContent(babyName: babyName)
            }
        }
        .padding(.top, BTSpacing.cardPaddingTop)
        .padding(.horizontal, BTSpacing.cardPaddingHorizontal)
        .padding(.bottom, BTSpacing.cardPaddingBottom)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.btBackground)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.card, style: .continuous))
        .cardShadow()
        .onTapGesture {
            onTap?()
        }
    }

    // MARK: - Awake Content

    private func awakeContent(
        duration: String,
        detail: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            (Text("Awake ")
                .foregroundStyle(Color.btTextTertiary)
            + Text(duration)
                .foregroundStyle(Color.btTextPrimary))
                .font(BTTypography.headline)
                .tracking(BTTracking.headline)

            if !detail.isEmpty {
                Text(detail)
                    .font(BTTypography.label)
                    .tracking(BTTracking.label)
                    .foregroundStyle(Color.btTextSecondary)
                    .padding(.top, BTSpacing.headlineToDetail)
            }

            Button {
                onSleepTap?()
            } label: {
                HStack(spacing: 6) {
                        BTIcon(kind: .sleep)
                            .frame(width: 16, height: 16)
                        Text("Sleep")
                            .font(BTTypography.label)
                            .tracking(BTTracking.label)
                    }
                    .foregroundStyle(Color.btTextPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.btBackgroundSecondary)
                    .clipShape(Capsule())
            }
            .matchedTransitionSource(id: "sleepSheet", in: sheetTransition)
            .padding(.top, 18)
        }
    }

    // MARK: - Sleeping Content (engine-reported)

    private func sleepingContent(
        duration: String,
        detail: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            (Text("Asleep ")
                .foregroundStyle(Color.btSleepAccent)
            + Text(duration)
                .foregroundStyle(Color.btTextPrimary))
                .font(BTTypography.headline)
                .tracking(BTTracking.headline)

            if !detail.isEmpty {
                Text(detail)
                    .font(BTTypography.label)
                    .tracking(BTTracking.label)
                    .foregroundStyle(Color.btTextSecondary)
                    .padding(.top, BTSpacing.headlineToDetail)
            }
        }
    }

    // MARK: - Wake Time Prompt Content (empty state)

    private func wakeTimePromptContent(babyName: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("When did \(babyName) wake up?")
                .font(BTTypography.headlineSmall)
                .tracking(BTTracking.headlineSmall)
                .foregroundStyle(Color.btTextPrimary)

            HStack {
                DatePicker(
                    "",
                    selection: $selectedWakeTime,
                    displayedComponents: .hourAndMinute
                )
                .labelsHidden()

                Spacer()

                Button {
                    onWakeTimeSubmit?(selectedWakeTime)
                } label: {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Color.btSleepAccent)
                        .clipShape(Circle())
                }
            }
            .padding(.top, 18)
        }
    }

    // MARK: - Bedtime Prompt Content

    private func bedtimePromptContent(babyName: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("When did \(babyName) fall asleep?")
                .font(BTTypography.headlineSmall)
                .tracking(BTTracking.headlineSmall)
                .foregroundStyle(Color.btTextPrimary)

            HStack {
                DatePicker(
                    "",
                    selection: $selectedBedtime,
                    displayedComponents: .hourAndMinute
                )
                .labelsHidden()

                Spacer()

                Button {
                    onBedtimeSubmit?(selectedBedtime)
                } label: {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Color.btSleepAccent)
                        .clipShape(Circle())
                }
            }
            .padding(.top, 18)
        }
    }

    // MARK: - Sleep Active Content (live timer)

    @Environment(ActivityManager.self) private var activityManager

    private var sleepActiveContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            SwiftUI.TimelineView(.periodic(from: .now, by: 60)) { context in
                let mins = activityManager.sleepTimerMinutesString(at: context.date)
                (Text("Asleep")
                    .foregroundStyle(Color.btSleepAccent)
                + Text(mins.isEmpty ? "" : " \(mins)")
                    .foregroundStyle(Color.btTextPrimary))
                    .font(BTTypography.headline)
                    .tracking(BTTracking.headline)
            }

            if let start = activityManager.sleepStartTime {
                Text("Started at \(start.shortTime)")
                    .font(BTTypography.label)
                    .tracking(BTTracking.label)
                    .foregroundStyle(Color.btTextSecondary)
                    .padding(.top, BTSpacing.headlineToDetail)
            }
        }
    }
}

#Preview("Awake") {
    @Previewable @Namespace var ns
    ZStack {
        Color.btBackground.ignoresSafeArea()
        SleepCard(
            mode: .awake(
                duration: "1h 25m",
                detail: "Nap by 11:30 AM"
            ),
            sheetTransition: ns,
            onSleepTap: {}
        )
        .padding(.horizontal, BTSpacing.pageMargin)
    }
}

#Preview("No More Naps") {
    @Previewable @Namespace var ns
    ZStack {
        Color.btBackground.ignoresSafeArea()
        SleepCard(
            mode: .awake(
                duration: "3h 15m",
                detail: "No more naps today"
            ),
            sheetTransition: ns,
            onSleepTap: {}
        )
        .padding(.horizontal, BTSpacing.pageMargin)
    }
}

#Preview("Wake Time Prompt") {
    @Previewable @Namespace var ns
    ZStack {
        Color.btBackground.ignoresSafeArea()
        SleepCard(
            mode: .wakeTimePrompt(babyName: "Kaia"),
            sheetTransition: ns,
            onWakeTimeSubmit: { _ in }
        )
        .padding(.horizontal, BTSpacing.pageMargin)
    }
}

#Preview("Bedtime Prompt") {
    @Previewable @Namespace var ns
    ZStack {
        Color.btBackground.ignoresSafeArea()
        SleepCard(
            mode: .bedtimePrompt(babyName: "Kaia"),
            sheetTransition: ns,
            onBedtimeSubmit: { _ in }
        )
        .padding(.horizontal, BTSpacing.pageMargin)
    }
}

#Preview("Asleep") {
    @Previewable @Namespace var ns
    ZStack {
        Color.btBackground.ignoresSafeArea()
        SleepCard(
            mode: .sleeping(
                duration: "35m",
                detail: "Started at 1:30 PM"
            ),
            sheetTransition: ns
        )
        .padding(.horizontal, BTSpacing.pageMargin)
    }
}
