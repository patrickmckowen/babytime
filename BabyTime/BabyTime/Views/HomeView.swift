//
//  HomeView.swift
//  BabyTime
//
//  Scrollable home screen with photo header, feed/sleep cards, and today summary.
//

import SwiftUI

struct HomeView: View {
    let scenario: Scenario

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // 1. Baby photo header (fullbleed)
                BabyPhotoHeader(
                    babyName: scenario.baby.name,
                    dateString: scenario.dateDisplayString,
                    ageString: scenario.ageDisplayString
                )

                // Cards section
                VStack(spacing: BTSpacing.cardGap) {
                    // 2. Feed card
                    FeedCard(
                        offerAmountOz: scenario.offerAmountOz,
                        nextFeedTime: scenario.nextFeedTimeFormatted,
                        lastFeedAmount: scenario.lastFeedOzFormatted,
                        lastFeedAgo: scenario.timeSinceLastFeedDuration
                    )

                    // 3. Sleep card
                    SleepCard(
                        awakeDuration: scenario.wakeWindowFormatted,
                        lastSleepDuration: scenario.lastSleepDurationFormatted,
                        lastSleepTime: scenario.lastSleepTimeFormatted
                    )

                    // 4. Today summary
                    TodaySummaryCard(
                        totalSleep: scenario.totalSleepFormatted,
                        longestSleep: scenario.longestSleepFormatted,
                        napCount: scenario.napCount,
                        totalOz: scenario.totalOzFormatted,
                        feedCount: scenario.feedCount,
                        averageOz: scenario.averageOzFormatted
                    )
                }
                .padding(.top, BTSpacing.photoToCard)
                .padding(.horizontal, BTSpacing.pageMargin)
                .padding(.bottom, 40)
            }
        }
        .background(Color.btBackground)
        .ignoresSafeArea(.container, edges: .top)
    }
}

// MARK: - Preview

#Preview("Home") {
    HomeView(scenario: .preview)
}
