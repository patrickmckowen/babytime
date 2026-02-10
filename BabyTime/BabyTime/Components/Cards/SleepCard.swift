//
//  SleepCard.swift
//  BabyTime
//
//  Sleep status card: "Awake for [duration]"
//

import SwiftUI

struct SleepCard: View {
    let awakeDuration: String
    let lastSleepDuration: String
    let lastSleepTime: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Label: "Awake for"
            Text("Awake for")
                .font(BTTypography.label)
                .tracking(BTTracking.label)
                .foregroundStyle(Color.btTextSecondary)

            // Headline: "1h 25m"
            Text(awakeDuration)
                .font(BTTypography.headline)
                .tracking(BTTracking.headline)
                .foregroundStyle(Color.btTextPrimary)
                .padding(.top, BTSpacing.labelToHeadline)

            // Detail: "Last slept 45m at 11:15 AM"
            Text("Last slept \(lastSleepDuration) at \(lastSleepTime)")
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
        SleepCard(
            awakeDuration: "1h 25m",
            lastSleepDuration: "45m",
            lastSleepTime: "11:15 AM"
        )
        .padding(.horizontal, BTSpacing.pageMargin)
    }
}
