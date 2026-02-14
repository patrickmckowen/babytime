//
//  SleepCard.swift
//  BabyTime
//
//  Sleep status card driven by DayState: awake, sleeping, bridging, bedtime.
//

import SwiftUI

struct SleepCard: View {
    let mode: Mode
    var onTap: (() -> Void)?
    var onWakeTimeSubmit: ((Date) -> Void)?

    enum Mode {
        /// Awake states — configurable label, duration, and detail
        case awake(label: String, duration: String, detail: String)
        /// Sleeping states (not active timer) — engine says baby is sleeping
        case sleeping(label: String, duration: String, detail: String)
        /// Active sleep timer (user started timer from sheet)
        case sleepActive
        /// Empty state — prompt user for wake time
        case wakeTimePrompt(babyName: String)
    }

    @State private var selectedWakeTime = Date()

    var body: some View {
        Group {
            switch mode {
            case .awake(let label, let duration, let detail):
                awakeContent(label: label, duration: duration, detail: detail)
            case .sleeping(let label, let duration, let detail):
                sleepingContent(label: label, duration: duration, detail: detail)
            case .sleepActive:
                sleepActiveContent
            case .wakeTimePrompt(let babyName):
                wakeTimePromptContent(babyName: babyName)
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
        label: String,
        duration: String,
        detail: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label)
                .font(BTTypography.label)
                .tracking(BTTracking.label)
                .foregroundStyle(Color.btTextSecondary)

            Text(duration)
                .font(BTTypography.headline)
                .tracking(BTTracking.headline)
                .foregroundStyle(Color.btTextPrimary)
                .padding(.top, BTSpacing.labelToHeadline)

            if !detail.isEmpty {
                Text(detail)
                    .font(BTTypography.label)
                    .tracking(BTTracking.label)
                    .foregroundStyle(Color.btTextSecondary)
                    .padding(.top, BTSpacing.headlineToDetail)
            }
        }
    }

    // MARK: - Sleeping Content (engine-reported)

    private func sleepingContent(
        label: String,
        duration: String,
        detail: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label)
                .font(BTTypography.label)
                .tracking(BTTracking.label)
                .foregroundStyle(Color.btSleepAccent)

            Text(duration)
                .font(BTTypography.headline)
                .tracking(BTTracking.headline)
                .foregroundStyle(Color.btTextPrimary)
                .padding(.top, BTSpacing.labelToHeadline)

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

    // MARK: - Sleep Active Content (live timer)

    @Environment(ActivityManager.self) private var activityManager

    private var sleepActiveContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Sleeping")
                .font(BTTypography.label)
                .tracking(BTTracking.label)
                .foregroundStyle(Color.btSleepAccent)

            SwiftUI.TimelineView(.periodic(from: .now, by: 1)) { context in
                Text(activityManager.sleepTimerString(at: context.date))
                    .font(BTTypography.headline)
                    .tracking(BTTracking.headline)
                    .foregroundStyle(Color.btTextPrimary)
                    .padding(.top, BTSpacing.labelToHeadline)
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
    ZStack {
        Color.btBackground.ignoresSafeArea()
        SleepCard(
            mode: .awake(
                label: "Awake for",
                duration: "1h 25m",
                detail: "Last slept at 11:15 AM \u{00B7} 45m"
            )
        )
        .padding(.horizontal, BTSpacing.pageMargin)
    }
}

#Preview("Nap Window Open") {
    ZStack {
        Color.btBackground.ignoresSafeArea()
        SleepCard(
            mode: .awake(
                label: "Nap window open",
                duration: "1h 25m",
                detail: "Window 1h 15m\u{2013}1h 30m"
            )
        )
        .padding(.horizontal, BTSpacing.pageMargin)
    }
}

#Preview("Wake Time Prompt") {
    ZStack {
        Color.btBackground.ignoresSafeArea()
        SleepCard(
            mode: .wakeTimePrompt(babyName: "Kaia"),
            onWakeTimeSubmit: { _ in }
        )
        .padding(.horizontal, BTSpacing.pageMargin)
    }
}

#Preview("Sleeping") {
    ZStack {
        Color.btBackground.ignoresSafeArea()
        SleepCard(
            mode: .sleeping(
                label: "Sleeping",
                duration: "35m",
                detail: "Started at 1:30 PM"
            )
        )
        .padding(.horizontal, BTSpacing.pageMargin)
    }
}
