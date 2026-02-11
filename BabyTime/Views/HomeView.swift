//
//  HomeView.swift
//  BabyTime
//
//  Scrollable home screen with photo header, feed/sleep cards, and today summary.
//

import SwiftUI

struct HomeView: View {
    @Environment(ActivityManager.self) private var activityManager
    var onNursingTap: (() -> Void)?
    var onSleepTap: (() -> Void)?

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // 1. Baby photo header (fullbleed)
                BabyPhotoHeader(
                    babyName: activityManager.baby.name,
                    dateString: activityManager.dateDisplayString,
                    ageString: activityManager.ageDisplayString
                )

                // Cards section
                VStack(spacing: BTSpacing.cardGap) {
                    // 2. Feed card
                    if activityManager.isNursingActive || activityManager.hasNursingSession {
                        FeedCard(
                            mode: .nursingActive,
                            onTap: onNursingTap
                        )
                    } else {
                        FeedCard(
                            mode: .nextFeed(
                                offerAmountOz: activityManager.offerAmountOz,
                                nextFeedTime: activityManager.nextFeedTimeFormatted,
                                lastFeedAmount: activityManager.lastFeedOzFormatted,
                                lastFeedAgo: activityManager.timeSinceLastFeedDuration
                            ),
                            onTap: nil
                        )
                    }

                    // 3. Sleep card
                    if activityManager.isSleepActive || activityManager.hasSleepSession {
                        SleepCard(
                            mode: .sleepActive,
                            onTap: onSleepTap
                        )
                    } else {
                        SleepCard(
                            mode: .awake(
                                duration: activityManager.wakeWindowFormatted,
                                lastSleepDuration: activityManager.lastSleepDurationFormatted,
                                lastSleepTime: activityManager.lastSleepTimeFormatted
                            ),
                            onTap: nil
                        )
                    }

                    // 4. Today summary
                    TodaySummaryCard(
                        totalSleep: activityManager.totalSleepFormatted,
                        longestSleep: activityManager.longestSleepFormatted,
                        napCount: activityManager.napCount,
                        totalOz: activityManager.totalOzFormatted,
                        feedCount: activityManager.feedCount,
                        averageOz: activityManager.averageOzFormatted
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
    HomeView()
        .environment(ActivityManager())
}
