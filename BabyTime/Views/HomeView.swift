//
//  HomeView.swift
//  BabyTime
//
//  Scrollable home screen with photo header, feed/sleep cards, and today summary.
//  Cards are driven by DaySnapshot from the DayEngine.
//

import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(ActivityManager.self) private var activityManager
    var onNursingTap: (() -> Void)?
    var onBottleTap: (() -> Void)?
    var onSleepTap: (() -> Void)?

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // 1. Baby photo header (fullbleed)
                BabyPhotoHeader(
                    babyName: activityManager.babyName,
                    dateString: activityManager.dateDisplayString,
                    ageString: activityManager.ageDisplayString
                )

                // Cards section
                VStack(spacing: BTSpacing.cardGap) {
                    // 2. Feed card
                    feedCard

                    // 3. Sleep card
                    sleepCard

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

    // MARK: - Feed Card

    @ViewBuilder
    private var feedCard: some View {
        if activityManager.isNursingActive || activityManager.hasNursingSession {
            FeedCard(
                mode: .nursingActive,
                onTap: onNursingTap
            )
        } else if activityManager.snapshot?.feedState == .noFeedsYet {
            FeedCard(
                mode: .logFirstFeed,
                onBottleTap: onBottleTap,
                onNurseTap: onNursingTap
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
    }

    // MARK: - Sleep Card (DayState-driven)

    @ViewBuilder
    private var sleepCard: some View {
        if activityManager.isSleepActive || activityManager.hasSleepSession {
            SleepCard(
                mode: .sleepActive,
                onTap: onSleepTap
            )
        } else if let snapshot = activityManager.snapshot {
            SleepCard(
                mode: sleepCardMode(from: snapshot.dayState),
                onTap: nil
            )
        } else {
            SleepCard(
                mode: .awake(
                    label: "Good morning",
                    duration: "--",
                    detail: "No events yet"
                ),
                onTap: nil
            )
        }
    }

    private func sleepCardMode(from dayState: DayState) -> SleepCard.Mode {
        switch dayState {
        case .notStarted:
            return .awake(
                label: "Good morning",
                duration: "--",
                detail: "No events yet"
            )

        case .awakeEarly(let mins, _):
            return .awake(
                label: "Awake for",
                duration: formatMinutes(mins),
                detail: "Last slept at \(activityManager.lastSleepTimeFormatted) \u{00B7} \(activityManager.lastSleepDurationFormatted)"
            )

        case .awakeApproaching(let mins, let range):
            return .awake(
                label: "Nap window open",
                duration: formatMinutes(mins),
                detail: "Window \(formatMinutes(range.lowerBound))\u{2013}\(formatMinutes(range.upperBound))"
            )

        case .awakeBeyond(let mins, let range):
            return .awake(
                label: "Past wake window",
                duration: formatMinutes(mins),
                detail: "Target was \(formatMinutes(range.upperBound))"
            )

        case .sleepingNoPressure(let mins, _):
            return .sleeping(
                label: "Sleeping",
                duration: formatMinutes(mins),
                detail: "Started at \(activityManager.todaySleeps.last?.startTime.shortTime ?? "--")"
            )

        case .sleepingApproachingCutoff(let mins, let untilCutoff):
            return .sleeping(
                label: "Sleeping",
                duration: formatMinutes(mins),
                detail: "Wake in \(formatMinutes(untilCutoff)) for bedtime"
            )

        case .sleepingMustEnd(let mins, _):
            return .sleeping(
                label: "Wake her up",
                duration: formatMinutes(mins),
                detail: "Past cutoff for bedtime"
            )

        case .napWindowClosed(_, let minsToBed):
            return .awake(
                label: "Bridging to bedtime",
                duration: formatMinutes(minsToBed),
                detail: "No more naps today"
            )

        case .bedtimeWindow(let mins):
            return .awake(
                label: "Bedtime in",
                duration: formatMinutes(mins),
                detail: ""
            )
        }
    }

    private func formatMinutes(_ mins: Int) -> String {
        let hours = mins / 60
        let minutes = mins % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}

// MARK: - Preview

#Preview("Home") {
    let container = try! ModelContainer(
        for: Baby.self, FeedEvent.self, SleepEvent.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let manager = ActivityManager(modelContext: container.mainContext)
    let baby = manager.addBaby(name: "Kaia", birthdate: Calendar.current.date(byAdding: .day, value: -100, to: Date())!)
    manager.selectBaby(baby)

    return HomeView()
        .environment(manager)
}
