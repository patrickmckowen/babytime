//
//  FeedCard.swift
//  BabyTime
//
//  Feed card: shows next-feed recommendation or active nursing timer.
//

import SwiftUI
import SwiftData

struct FeedCard: View {
    let mode: Mode
    var onTap: (() -> Void)?
    var onBottleTap: (() -> Void)?
    var onNurseTap: (() -> Void)?

    enum Mode {
        case nextFeed(offerAmountOz: Int, nextFeedTime: String, lastFeedAmount: String, lastFeedAgo: String)
        case nursingActive
        case logFirstFeed
    }

    var body: some View {
        Group {
            switch mode {
            case .nextFeed(let offerAmountOz, let nextFeedTime, let lastFeedAmount, let lastFeedAgo):
                nextFeedContent(
                    offerAmountOz: offerAmountOz,
                    nextFeedTime: nextFeedTime,
                    lastFeedAmount: lastFeedAmount,
                    lastFeedAgo: lastFeedAgo
                )
            case .nursingActive:
                nursingActiveContent
            case .logFirstFeed:
                logFirstFeedContent
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

    // MARK: - Next Feed Content

    private func nextFeedContent(
        offerAmountOz: Int,
        nextFeedTime: String,
        lastFeedAmount: String,
        lastFeedAgo: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Offer \(offerAmountOz) oz by")
                .font(BTTypography.label)
                .tracking(BTTracking.label)
                .foregroundStyle(Color.btTextSecondary)

            Text(nextFeedTime)
                .font(BTTypography.headline)
                .tracking(BTTracking.headline)
                .foregroundStyle(Color.btTextPrimary)
                .padding(.top, BTSpacing.labelToHeadline)

            Text("Last fed \(lastFeedAgo) ago · \(lastFeedAmount)")
                .font(BTTypography.label)
                .tracking(BTTracking.label)
                .foregroundStyle(Color.btTextSecondary)
                .padding(.top, BTSpacing.headlineToDetail)
        }
    }

    // MARK: - Log First Feed (Empty State)

    private var timeOfDayGreeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 {
            return "Good morning"
        } else if hour < 17 {
            return "Good afternoon"
        } else {
            return "Good evening"
        }
    }

    private var logFirstFeedContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(timeOfDayGreeting)
                .font(BTTypography.headlineSmall)
                .tracking(BTTracking.headlineSmall)
                .foregroundStyle(Color.btTextPrimary)

            Text("Log the first feed")
                .font(BTTypography.label)
                .tracking(BTTracking.label)
                .foregroundStyle(Color.btTextSecondary)
                .padding(.top, BTSpacing.labelToHeadline)

            HStack(spacing: 12) {
                Button {
                    onNurseTap?()
                } label: {
                    Label("Nurse", systemImage: "drop.fill")
                        .font(BTTypography.label)
                        .tracking(BTTracking.label)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.btFeedAccent)
                        .clipShape(Capsule())
                }

                Button {
                    onBottleTap?()
                } label: {
                    Label("Bottle", systemImage: "waterbottle.fill")
                        .font(BTTypography.label)
                        .tracking(BTTracking.label)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.btFeedAccent)
                        .clipShape(Capsule())
                }
            }
            .padding(.top, 18)
        }
    }

    // MARK: - Nursing Active Content

    @Environment(ActivityManager.self) private var activityManager

    private var nursingActiveContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Nursing")
                .font(BTTypography.label)
                .tracking(BTTracking.label)
                .foregroundStyle(Color.btFeedAccent)

            SwiftUI.TimelineView(.periodic(from: .now, by: 1)) { context in
                Text(activityManager.nursingTimerString(at: context.date))
                    .font(BTTypography.headline)
                    .tracking(BTTracking.headline)
                    .foregroundStyle(Color.btTextPrimary)
                    .padding(.top, BTSpacing.labelToHeadline)
            }

            if let start = activityManager.nursingStartTime {
                Text("Started at \(start.shortTime)")
                    .font(BTTypography.label)
                    .tracking(BTTracking.label)
                    .foregroundStyle(Color.btTextSecondary)
                    .padding(.top, BTSpacing.headlineToDetail)
            }
        }
    }
}

#Preview("Next Feed") {
    ZStack {
        Color.btBackground.ignoresSafeArea()
        FeedCard(
            mode: .nextFeed(
                offerAmountOz: 5,
                nextFeedTime: "3:30 PM",
                lastFeedAmount: "4 oz",
                lastFeedAgo: "1h 25m"
            )
        )
        .padding(.horizontal, BTSpacing.pageMargin)
    }
}

#Preview("Log First Feed") {
    ZStack {
        Color.btBackground.ignoresSafeArea()
        FeedCard(
            mode: .logFirstFeed,
            onBottleTap: {},
            onNurseTap: {}
        )
        .padding(.horizontal, BTSpacing.pageMargin)
    }
}

#Preview("Nursing Active") {
    let container = try! ModelContainer(
        for: Baby.self, FeedEvent.self, SleepEvent.self, WakeEvent.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    ZStack {
        Color.btBackground.ignoresSafeArea()
        FeedCard(mode: .nursingActive)
            .padding(.horizontal, BTSpacing.pageMargin)
    }
    .environment(ActivityManager(modelContext: container.mainContext))
}
