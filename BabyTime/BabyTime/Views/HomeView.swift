//
//  HomeView.swift
//  BabyTime
//
//  Main home screen with What's Next and Timeline.
//

import SwiftUI

struct HomeView: View {
    let scenario: Scenario

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                HomeHeader(babyName: scenario.baby.name)
                    .padding(.horizontal, BTSpacing.md)
                    .padding(.top, BTSpacing.md)

                // Eating Card
                EatingCardView(
                    timeSinceLastFeed: scenario.timeSinceLastFeedFormatted,
                    feedCount: scenario.feedCount,
                    totalOz: scenario.totalIntakeOz,
                    dailyGoal: scenario.baby.ageBracket.dailyIntakeOz,
                    hasEstimates: scenario.hasNursingEstimates,
                    onAddFeed: { }
                )
                .padding(.horizontal, BTSpacing.md)
                .padding(.top, BTSpacing.xl)

                // Sleeping Card
                SleepingCardView(
                    awakeTime: scenario.awakeTimeFormatted,
                    sleepingTime: nil, // TODO: Add support for active sleep timer
                    napCount: scenario.napCount,
                    totalSleepFormatted: scenario.totalSleepFormatted,
                    dailyGoal: scenario.baby.ageBracket.dailySleepHours,
                    totalSleepMinutes: scenario.totalSleepMinutes,
                    onStartNap: { }
                )
                .padding(.horizontal, BTSpacing.md)
                .padding(.top, BTSpacing.md)

                Spacer(minLength: BTSpacing.xxl)
            }
        }
        .background(BTColors.surfacePage)
    }

}

// MARK: - Home Header

private struct HomeHeader: View {
    let babyName: String

    var body: some View {
        HStack(spacing: BTSpacing.sm) {
            // Profile placeholder
            Circle()
                .fill(BTColors.actionPrimarySubtle)
                .frame(width: 36, height: 36)
                .overlay(
                    Text(String(babyName.prefix(1)))
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(BTColors.actionPrimary)
                )

            Text(babyName)
                .font(BTTypography.label)
                .foregroundStyle(BTColors.textPrimary)

            Spacer()
        }
    }
}

// MARK: - Preview

#Preview("Home") {
    HomeView(scenario: .preview)
}

#Preview("Home - Dark") {
    HomeView(scenario: .preview)
        .preferredColorScheme(.dark)
}
