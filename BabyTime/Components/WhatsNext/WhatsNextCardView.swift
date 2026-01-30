//
//  WhatsNextCardView.swift
//  BabyTime
//
//  Variation B: Floating card with subtle shadow and border.
//

import SwiftUI

struct WhatsNextCardView: View {
    let label: String
    let timeRemaining: String
    let context: String
    let actionLabel: String
    let onAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label)
                .font(BTTypography.label)
                .foregroundStyle(BTColors.textSecondary)

            Text(timeRemaining)
                .font(BTTypography.displayLarge)
                .foregroundStyle(BTColors.textPrimary)
                .padding(.top, BTSpacing.xxxs)

            Text(context)
                .font(BTTypography.caption)
                .foregroundStyle(BTColors.textTertiary)
                .padding(.top, BTSpacing.xxs)

            Button(action: onAction) {
                Text(actionLabel)
                    .font(BTTypography.button)
                    .foregroundStyle(BTColors.actionPrimary)
                    .padding(.horizontal, BTSpacing.md)
                    .padding(.vertical, BTSpacing.xs)
                    .background(BTColors.actionPrimarySubtle)
                    .clipShape(Capsule())
            }
            .padding(.top, BTSpacing.md)
        }
        .padding(BTSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(BTColors.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.card, style: .continuous))
        .shadow(
            color: BTShadow.card.color,
            radius: BTShadow.card.radius,
            x: BTShadow.card.x,
            y: BTShadow.card.y
        )
        .overlay(
            RoundedRectangle(cornerRadius: BTRadius.card, style: .continuous)
                .stroke(BTColors.cardBorder, lineWidth: 0.5)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label), \(spokenTime(timeRemaining)). \(context)")
        .accessibilityHint("Double tap to \(actionLabel.lowercased())")
    }

    /// Converts compact time format to spoken format for VoiceOver
    private func spokenTime(_ time: String) -> String {
        time
            .replacingOccurrences(of: "h", with: " hour")
            .replacingOccurrences(of: "m", with: " minutes")
    }
}

// MARK: - Preview

#Preview("Floating Card") {
    ZStack {
        BTColors.surfacePage
            .ignoresSafeArea()

        VStack {
            Spacer()
                .frame(height: 120)

            WhatsNextCardView(
                label: "Next nap",
                timeRemaining: "1h 23m",
                context: "Wake window",
                actionLabel: "Start Nap",
                onAction: {}
            )
            .padding(.horizontal, BTSpacing.md)

            Spacer()
        }
    }
}

#Preview("Floating Card - Dark") {
    ZStack {
        BTColors.surfacePage
            .ignoresSafeArea()

        VStack {
            Spacer()
                .frame(height: 120)

            WhatsNextCardView(
                label: "Next nap",
                timeRemaining: "1h 23m",
                context: "Wake window",
                actionLabel: "Start Nap",
                onAction: {}
            )
            .padding(.horizontal, BTSpacing.md)

            Spacer()
        }
    }
    .preferredColorScheme(.dark)
}
