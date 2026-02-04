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

                // What's Next Card
                WhatsNextCardView(
                    label: whatsNextLabel,
                    timeRemaining: scenario.wakeWindowFormatted,
                    context: whatsNextContext,
                    actionLabel: whatsNextAction,
                    onAction: { }
                )
                .padding(.horizontal, BTSpacing.md)
                .padding(.top, BTSpacing.xl)

                // Timeline
                TimelineView(activities: scenario.today.allActivities)
                    .padding(.horizontal, BTSpacing.md)
                    .padding(.top, BTSpacing.xxl)

                Spacer(minLength: BTSpacing.xxl)
            }
        }
        .background(BTColors.surfacePage)
    }

    // MARK: - What's Next State

    private var whatsNextLabel: String {
        scenario.isWakeWindowExceeded ? "Overdue" : "Next nap"
    }

    private var whatsNextContext: String {
        "Wake window"
    }

    private var whatsNextAction: String {
        "Start Nap"
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
