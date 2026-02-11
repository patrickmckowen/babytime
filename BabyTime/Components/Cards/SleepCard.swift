//
//  SleepCard.swift
//  BabyTime
//
//  Sleep status card: "Awake for [duration]" or active sleep timer.
//

import SwiftUI

struct SleepCard: View {
    let mode: Mode
    var onTap: (() -> Void)?

    enum Mode {
        case awake(duration: String, lastSleepDuration: String, lastSleepTime: String)
        case sleepActive
    }

    var body: some View {
        Group {
            switch mode {
            case .awake(let duration, let lastSleepDuration, let lastSleepTime):
                awakeContent(
                    duration: duration,
                    lastSleepDuration: lastSleepDuration,
                    lastSleepTime: lastSleepTime
                )
            case .sleepActive:
                sleepActiveContent
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
        lastSleepDuration: String,
        lastSleepTime: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Awake for")
                .font(BTTypography.label)
                .tracking(BTTracking.label)
                .foregroundStyle(Color.btTextSecondary)

            Text(duration)
                .font(BTTypography.headline)
                .tracking(BTTracking.headline)
                .foregroundStyle(Color.btTextPrimary)
                .padding(.top, BTSpacing.labelToHeadline)

            Text("Last slept at \(lastSleepTime) · \(lastSleepDuration)")
                .font(BTTypography.label)
                .tracking(BTTracking.label)
                .foregroundStyle(Color.btTextSecondary)
                .padding(.top, BTSpacing.headlineToDetail)
        }
    }

    // MARK: - Sleep Active Content

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
                duration: "1h 25m",
                lastSleepDuration: "45m",
                lastSleepTime: "11:15 AM"
            )
        )
        .padding(.horizontal, BTSpacing.pageMargin)
    }
}

#Preview("Sleep Active") {
    ZStack {
        Color.btBackground.ignoresSafeArea()
        SleepCard(mode: .sleepActive)
            .padding(.horizontal, BTSpacing.pageMargin)
    }
    .environment(ActivityManager())
}
