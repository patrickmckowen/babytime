//
//  FeedCard.swift
//  BabyTime
//
//  Feed recommendation card: "Offer X oz by [time]"
//

import SwiftUI

struct FeedCard: View {
    let offerAmountOz: Int
    let nextFeedTime: String
    let lastFeedAmount: String
    let lastFeedAgo: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Label: "Offer 5 oz by"
            Text("Offer \(offerAmountOz) oz by")
                .font(BTTypography.label)
                .tracking(BTTracking.label)
                .foregroundStyle(Color.btTextSecondary)

            // Headline: "3:30 PM"
            Text(nextFeedTime)
                .font(BTTypography.headline)
                .tracking(BTTracking.headline)
                .foregroundStyle(Color.btTextPrimary)
                .padding(.top, BTSpacing.labelToHeadline)

            // Detail: "Last fed 1h 25m ago · 4 oz"
            Text("Last fed \(lastFeedAgo) ago · \(lastFeedAmount)")
                .font(BTTypography.label)
                .tracking(BTTracking.label)
                .foregroundStyle(Color.btTextSecondary)
                .padding(.top, BTSpacing.headlineToDetail)
        }
        .padding(.top, BTSpacing.cardPaddingTop)
        .padding(.horizontal, BTSpacing.cardPaddingHorizontal)
        .padding(.bottom, BTSpacing.cardPaddingBottom)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.btBackground)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.card, style: .continuous))
        .cardShadow()
    }
}

#Preview {
    ZStack {
        Color.btBackground.ignoresSafeArea()
        FeedCard(
            offerAmountOz: 5,
            nextFeedTime: "3:30 PM",
            lastFeedAmount: "4 oz",
            lastFeedAgo: "1h 25m"
        )
        .padding(.horizontal, BTSpacing.pageMargin)
    }
}
