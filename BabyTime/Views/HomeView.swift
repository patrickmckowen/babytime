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
    var sheetTransition: Namespace.ID
    var onNursingTap: (() -> Void)?
    var onBottleTap: (() -> Void)?
    var onSleepTap: (() -> Void)?
    var onPhotoTap: (() -> Void)?
    var onLogTap: (() -> Void)?
    var onSettingsTap: (() -> Void)?

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // 1. Baby photo header (fullbleed)
                BabyPhotoHeader(
                    babyName: activityManager.babyName,
                    photoData: activityManager.babyPhotoData,
                    onPhotoTap: onPhotoTap
                )

                // Cards section
                VStack(spacing: BTSpacing.cardGap) {
                    // 2. Feed card
                    feedCard

                    // 3. Sleep card
                    sleepCard

                    // 4. Today summary — tap navigates to Log
                    TodaySummaryCard(
                        dateString: activityManager.dayOfWeekString,
                        totalSleep: activityManager.totalSleepFormatted,
                        longestSleep: activityManager.longestSleepFormatted,
                        napCount: activityManager.napCount,
                        totalOz: activityManager.totalOzFormatted,
                        feedCount: activityManager.feedCount,
                        averageOz: activityManager.averageOzFormatted,
                        wakeTime: activityManager.hasWakeTime ? activityManager.wakeTimeFormatted : nil,
                        bedtimeTime: activityManager.bedtimeFormatted,
                        actualBedtime: activityManager.actualBedtimeFormatted,
                        onWakeTimeChanged: { time in
                            activityManager.setWakeTime(time)
                        },
                        onBedtimeChanged: { time in
                            activityManager.updateBedtime(time)
                        }
                    )
                    .onTapGesture {
                        onLogTap?()
                    }

                    // 5. Settings button
                    Button {
                        onSettingsTap?()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "gearshape")
                                .font(.system(size: 13))
                            Text("Settings")
                                .font(.footnote)
                        }
                        .foregroundStyle(Color.btTextMuted)
                    }
                    .padding(.top, 24)
                }
                .padding(.top, BTSpacing.photoToCard)
                .padding(.horizontal, BTSpacing.pageMargin)
                .padding(.bottom, BTSpacing.pageMargin)
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
                sheetTransition: sheetTransition,
                onTap: onNursingTap
            )
        } else if activityManager.snapshot?.feedState == .noFeedsYet {
            FeedCard(
                mode: .logFirstFeed,
                sheetTransition: sheetTransition,
                onBottleTap: onBottleTap,
                onNurseTap: onNursingTap
            )
        } else if let snapshot = activityManager.snapshot,
                  let feedRef = snapshot.lastFeedReference {
            // Live-update "last fed X ago" every 60 seconds
            SwiftUI.TimelineView(.periodic(from: .now, by: 60)) { context in
                FeedCard(
                    mode: .nextFeed(
                        lastFedAgo: formatMinutes(Int(context.date.timeIntervalSince(feedRef) / 60)),
                        offerDetail: feedOfferDetail(feedRef: feedRef, now: context.date)
                    ),
                    sheetTransition: sheetTransition,
                    onBottleTap: onBottleTap,
                    onNurseTap: onNursingTap
                )
            }
        } else {
            FeedCard(
                mode: .nextFeed(
                    lastFedAgo: activityManager.timeSinceLastFeedDuration,
                    offerDetail: feedOfferDetail(feedRef: nil, now: Date())
                ),
                sheetTransition: sheetTransition,
                onBottleTap: onBottleTap,
                onNurseTap: onNursingTap
            )
        }
    }

    // MARK: - Sleep Card (DayState-driven)

    @ViewBuilder
    private var sleepCard: some View {
        if activityManager.isSleepActive || activityManager.hasSleepSession {
            SleepCard(
                mode: .sleepActive,
                sheetTransition: sheetTransition,
                onTap: onSleepTap
            )
        } else if let snapshot = activityManager.snapshot {
            if snapshot.dayState.isAwakeState, snapshot.wakeReference != nil {
                // Live-update awake duration every 60 seconds
                SwiftUI.TimelineView(.periodic(from: .now, by: 60)) { context in
                    SleepCard(
                        mode: sleepCardMode(from: snapshot, now: context.date),
                        sheetTransition: sheetTransition,
                        onSleepTap: onSleepTap,
                        onWakeTimeSubmit: { time in
                            activityManager.setWakeTime(time)
                        }
                    )
                }
            } else if case .asleepForNight = snapshot.dayState {
                // Live-update nighttime sleep duration every 60 seconds
                SwiftUI.TimelineView(.periodic(from: .now, by: 60)) { context in
                    SleepCard(
                        mode: sleepCardMode(from: snapshot, now: context.date),
                        sheetTransition: sheetTransition
                    )
                }
            } else {
                SleepCard(
                    mode: sleepCardMode(from: snapshot),
                    sheetTransition: sheetTransition,
                    onSleepTap: onSleepTap,
                    onWakeTimeSubmit: { time in
                        activityManager.setWakeTime(time)
                    },
                    onBedtimeSubmit: { time in
                        activityManager.logBedtime(time)
                    }
                )
            }
        } else {
            SleepCard(
                mode: .wakeTimePrompt(babyName: activityManager.babyName),
                sheetTransition: sheetTransition,
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

        case .awakeEarly(let mins, let range):
            return .awake(
                duration: formatMinutes(liveWakeMinutes ?? mins),
                detail: "Nap by \(napByTimeString(snapshot: snapshot, range: range))"
            )

        case .awakeApproaching(let mins, let range):
            return .awake(
                duration: formatMinutes(liveWakeMinutes ?? mins),
                detail: "Nap by \(napByTimeString(snapshot: snapshot, range: range))"
            )

        case .awakeBeyond(let mins, let range):
            return .awake(
                duration: formatMinutes(liveWakeMinutes ?? mins),
                detail: "Wake window ended at \(napByTimeString(snapshot: snapshot, range: range))"
            )

        case .sleepingNoPressure(let mins, _):
            return .sleeping(
                duration: formatMinutes(mins),
                detail: "Started at \(activityManager.todaySleeps.last?.startTime.shortTime ?? "--")"
            )

        case .sleepingApproachingCutoff(let mins, let untilCutoff):
            return .sleeping(
                duration: formatMinutes(mins),
                detail: "Wake in \(formatMinutes(untilCutoff)) for bedtime"
            )

        case .sleepingMustEnd(let mins, _):
            return .sleeping(
                duration: formatMinutes(mins),
                detail: "Past cutoff for bedtime"
            )

        case .napWindowClosed(let mins, _):
            return .awake(
                duration: formatMinutes(liveWakeMinutes ?? mins),
                detail: "No more naps today"
            )

        case .bedtimeWindow:
            return .bedtimePrompt(babyName: activityManager.babyName)

        case .asleepForNight(let mins):
            let liveMins: Int = {
                guard let now, let nightSleep = activityManager.todayNightSleep else { return mins }
                return max(0, Int(now.timeIntervalSince(nightSleep.startTime) / 60))
            }()
            return .sleeping(
                duration: formatMinutes(liveMins),
                detail: "Fell asleep at \(activityManager.todayNightSleep?.startTime.shortTime ?? "--")"
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

    private func feedOfferDetail(feedRef: Date?, now: Date) -> String {
        // When asleep for the night with dream feed enabled, show dream feed time
        if activityManager.isAsleepForNight,
           let dreamFeedTime = activityManager.dreamFeedTimeFormatted {
            return "Dream feed at \(dreamFeedTime)"
        }
        // Standard offer detail
        if let feedRef {
            return "Offer \(activityManager.offerAmountOz)oz by \(nextFeedTimeString(feedRef: feedRef, now: now))"
        }
        return "Offer \(activityManager.offerAmountOz)oz by \(activityManager.nextFeedTimeFormatted)"
    }

    private func nextFeedTimeString(feedRef: Date, now: Date) -> String {
        guard let baby = activityManager.baby else { return "--" }
        let intervalMinutes = Double(baby.effectiveFeedIntervalMinutes)
        let nextTime = feedRef.addingTimeInterval(intervalMinutes * 60)
        if nextTime <= now {
            return "Now"
        }
        return nextTime.shortTime
    }

    private func napByTimeString(snapshot: DaySnapshot, range: ClosedRange<Int>) -> String {
        guard let ref = snapshot.wakeReference else {
            return "\(formatMinutes(range.lowerBound))\u{2013}\(formatMinutes(range.upperBound))"
        }
        let napBy = ref.addingTimeInterval(Double(range.upperBound) * 60)
        return napBy.shortTime
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
    @Previewable @Namespace var ns
    let container = try! ModelContainer(
        for: Baby.self, FeedEvent.self, SleepEvent.self, WakeEvent.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let manager = ActivityManager(modelContext: container.mainContext)
    let baby = manager.addBaby(name: "Kaia", birthdate: Calendar.current.date(byAdding: .day, value: -100, to: Date())!)
    manager.selectBaby(baby)

    return HomeView(sheetTransition: ns)
        .environment(manager)
}
