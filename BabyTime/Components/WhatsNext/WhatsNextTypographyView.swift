//
//  WhatsNextTypographyView.swift
//  BabyTime
//
//  Variation A: Typography-only hierarchy, no containers or backgrounds.
//

import SwiftUI

struct WhatsNextTypographyView: View {
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
                    .underline(true, color: BTColors.actionPrimary.opacity(0.4))
            }
            .padding(.top, BTSpacing.md)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label), \(spokenTime(timeRemaining)). \(context)")
        .accessibilityHint("Double tap to \(actionLabel.lowercased())")
    }

    /// Converts compact time format to spoken format for VoiceOver
    private func spokenTime(_ time: String) -> String {
        // "1h 23m" -> "1 hour 23 minutes"
        time
            .replacingOccurrences(of: "h", with: " hour")
            .replacingOccurrences(of: "m", with: " minutes")
    }
}

// MARK: - Preview

#Preview("Typography Only") {
    ZStack {
        BTColors.surfacePage
            .ignoresSafeArea()

        VStack {
            Spacer()
                .frame(height: 120)

            WhatsNextTypographyView(
                label: "Next nap",
                timeRemaining: "1h 23m",
                context: "Wake window",
                actionLabel: "Start Nap",
                onAction: {}
            )
            .padding(.horizontal, BTSpacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer()
        }
    }
}

#Preview("Typography Only - Dark") {
    ZStack {
        BTColors.surfacePage
            .ignoresSafeArea()

        VStack {
            Spacer()
                .frame(height: 120)

            WhatsNextTypographyView(
                label: "Next nap",
                timeRemaining: "1h 23m",
                context: "Wake window",
                actionLabel: "Start Nap",
                onAction: {}
            )
            .padding(.horizontal, BTSpacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer()
        }
    }
    .preferredColorScheme(.dark)
}
