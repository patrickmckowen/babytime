//
//  FeedCard.swift
//  BabyTime
//
//  Feed card: shows next-feed recommendation or active nursing timer.
//

import Dependencies
import SwiftUI

struct FeedCard: View {
    let mode: Mode
    var sheetTransition: Namespace.ID
    var onTap: (() -> Void)?
    var onBottleTap: (() -> Void)?
    var onNurseTap: (() -> Void)?

    enum Mode {
        case nextFeed(lastFedAgo: String, offerDetail: String)
        case nursingActive
        case logFirstFeed
    }

    var body: some View {
        Group {
            switch mode {
            case .nextFeed(let lastFedAgo, let offerDetail):
                nextFeedContent(lastFedAgo: lastFedAgo, offerDetail: offerDetail)
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
        .matchedTransitionSource(id: "feedSheet", in: sheetTransition) { source in
            source
                .background(Color.btBackground)
                .clipShape(RoundedRectangle(cornerRadius: BTRadius.card, style: .continuous))
        }
        .cardShadow()
        .onTapGesture {
            onTap?()
        }
    }

    // MARK: - Next Feed Content

    private func nextFeedContent(
        lastFedAgo: String,
        offerDetail: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            (Text("Last ate ")
                .foregroundStyle(Color.btTextTertiary)
            + Text(lastFedAgo)
                .foregroundStyle(Color.btTextPrimary))
                .font(BTTypography.headline)
                .tracking(BTTracking.headline)

            Text(offerDetail)
                .font(BTTypography.label)
                .tracking(BTTracking.label)
                .foregroundStyle(Color.btTextSecondary)
                .padding(.top, BTSpacing.headlineToDetail)

            HStack(spacing: 12) {
                Button {
                    onNurseTap?()
                } label: {
                    HStack(spacing: 6) {
                            BTIcon(kind: .nursing)
                                .frame(width: 16, height: 16)
                            Text("Nurse")
                                .font(BTTypography.label)
                                .tracking(BTTracking.label)
                        }
                        .foregroundStyle(Color.btTextPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.btBackgroundSecondary)
                        .clipShape(Capsule())
                }

                Button {
                    onBottleTap?()
                } label: {
                    HStack(spacing: 6) {
                            BTIcon(kind: .bottle)
                                .frame(width: 16, height: 16)
                            Text("Bottle")
                                .font(BTTypography.label)
                                .tracking(BTTracking.label)
                        }
                        .foregroundStyle(Color.btTextPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.btBackgroundSecondary)
                        .clipShape(Capsule())
                }
            }
            .padding(.top, 18)
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
                    HStack(spacing: 6) {
                            BTIcon(kind: .nursing)
                                .frame(width: 16, height: 16)
                            Text("Nurse")
                                .font(BTTypography.label)
                                .tracking(BTTracking.label)
                        }
                        .foregroundStyle(Color.btTextPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.btBackgroundSecondary)
                        .clipShape(Capsule())
                }

                Button {
                    onBottleTap?()
                } label: {
                    HStack(spacing: 6) {
                            BTIcon(kind: .bottle)
                                .frame(width: 16, height: 16)
                            Text("Bottle")
                                .font(BTTypography.label)
                                .tracking(BTTracking.label)
                        }
                        .foregroundStyle(Color.btTextPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.btBackgroundSecondary)
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
            SwiftUI.TimelineView(.periodic(from: .now, by: 60)) { context in
                let mins = activityManager.nursingTimerMinutesString(at: context.date)
                (Text("Nursing")
                    .foregroundStyle(Color.btFeedAccent)
                + Text(mins.isEmpty ? "" : " \(mins)")
                    .foregroundStyle(Color.btTextPrimary))
                    .font(BTTypography.headline)
                    .tracking(BTTracking.headline)
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
    @Previewable @Namespace var ns
    ZStack {
        Color.btBackground.ignoresSafeArea()
        FeedCard(
            mode: .nextFeed(
                lastFedAgo: "1h 50m",
                offerDetail: "Offer 4oz by 3:00 PM"
            ),
            sheetTransition: ns,
            onBottleTap: {},
            onNurseTap: {}
        )
        .padding(.horizontal, BTSpacing.pageMargin)
    }
}

#Preview("Log First Feed") {
    @Previewable @Namespace var ns
    ZStack {
        Color.btBackground.ignoresSafeArea()
        FeedCard(
            mode: .logFirstFeed,
            sheetTransition: ns,
            onBottleTap: {},
            onNurseTap: {}
        )
        .padding(.horizontal, BTSpacing.pageMargin)
    }
}

#Preview("Nursing Active") {
    @Previewable @Namespace var ns
    let manager = withDependencies {
        try! $0.bootstrapTestDatabase()
    } operation: {
        @Dependency(\.defaultDatabase) var database
        return ActivityManager(database: database)
    }
    ZStack {
        Color.btBackground.ignoresSafeArea()
        FeedCard(mode: .nursingActive, sheetTransition: ns)
            .padding(.horizontal, BTSpacing.pageMargin)
    }
    .environment(manager)
}
