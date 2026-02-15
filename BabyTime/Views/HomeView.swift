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
    var onPhotoTap: (() -> Void)?
    var onSettingsTap: (() -> Void)?
    var onLogTap: (() -> Void)?

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // 1. Baby photo header (fullbleed)
                BabyPhotoHeader(
                    babyName: activityManager.babyName,
                    photoData: activityManager.babyPhotoData,
                    onPhotoTap: onPhotoTap,
                    onSettingsTap: onSettingsTap,
                    onLogTap: onLogTap
                )

                // Cards section
                VStack(spacing: BTSpacing.cardGap) {
                    // 2. Feed card
                    feedCard

                    // 3. Sleep card
                    sleepCard

                    // 4. Today summary
                    TodaySummaryCard(
                        dateString: activityManager.shortDateDisplayString,
                        ageString: activityManager.ageDisplayString,
                        totalSleep: activityManager.totalSleepFormatted,
                        longestSleep: activityManager.longestSleepFormatted,
                        napCount: activityManager.napCount,
                        totalOz: activityManager.totalOzFormatted,
                        feedCount: activityManager.feedCount,
                        averageOz: activityManager.averageOzFormatted,
                        wakeTime: activityManager.hasWakeTime ? activityManager.wakeTimeFormatted : nil,
                        bedtimeTime: activityManager.bedtimeFormatted,
                        onWakeTimeChanged: { time in
                            activityManager.setWakeTime(time)
                        }
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
            if snapshot.dayState.isAwakeState, snapshot.wakeReference != nil {
                // Live-update awake duration every 60 seconds
                SwiftUI.TimelineView(.periodic(from: .now, by: 60)) { context in
                    SleepCard(
                        mode: sleepCardMode(from: snapshot, now: context.date),
                        onTap: nil,
                        onWakeTimeSubmit: { time in
                            activityManager.setWakeTime(time)
                        }
                    )
                }
            } else {
                SleepCard(
                    mode: sleepCardMode(from: snapshot),
                    onTap: nil,
                    onWakeTimeSubmit: { time in
                        activityManager.setWakeTime(time)
                    }
                )
            }
        } else {
            SleepCard(
                mode: .wakeTimePrompt(babyName: activityManager.babyName),
                onWakeTimeSubmit: { time in
                    activityManager.setWakeTime(time)
                }
            )
        }
    }

    private func sleepCardMode(from snapshot: DaySnapshot, now: Date? = nil) -> SleepCard.Mode {
        // For awake states, recompute minutes from wakeReference if a live `now` is provided
        let liveWakeMinutes: Int? = {
            guard let now, let ref = snapshot.wakeReference else { return nil }
            return max(0, Int(now.timeIntervalSince(ref) / 60))
        }()

        switch snapshot.dayState {
        case .notStarted:
            return .wakeTimePrompt(babyName: activityManager.babyName)

        case .awakeEarly(let mins, _):
            return .awake(
                label: "Awake for",
                duration: formatMinutes(liveWakeMinutes ?? mins),
                detail: wakeDetail(snapshot: snapshot)
            )

        case .awakeApproaching(let mins, let range):
            return .awake(
                label: "Nap window open",
                duration: formatMinutes(liveWakeMinutes ?? mins),
                detail: "Window \(formatMinutes(range.lowerBound))\u{2013}\(formatMinutes(range.upperBound))"
            )

        case .awakeBeyond(let mins, let range):
            return .awake(
                label: "Past wake window",
                duration: formatMinutes(liveWakeMinutes ?? mins),
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

        case .napWindowClosed(let mins, _):
            return .awake(
                label: "Bridging to bedtime",
                duration: formatMinutes(liveWakeMinutes ?? mins),
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

    private func wakeDetail(snapshot: DaySnapshot) -> String {
        if activityManager.lastSleep != nil {
            return "Last slept at \(activityManager.lastSleepTimeFormatted) \u{00B7} \(activityManager.lastSleepDurationFormatted)"
        } else if let wakeTime = snapshot.wakeTime {
            return "Woke at \(wakeTime.shortTime)"
        } else {
            return ""
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
        for: Baby.self, FeedEvent.self, SleepEvent.self, WakeEvent.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let manager = ActivityManager(modelContext: container.mainContext)
    let baby = manager.addBaby(name: "Kaia", birthdate: Calendar.current.date(byAdding: .day, value: -100, to: Date())!)
    manager.selectBaby(baby)

    return HomeView()
        .environment(manager)
}
