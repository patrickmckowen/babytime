//
//  WhatsNextCardView.swift
//  BabyTime
//
//  Status-based card with contextual action buttons.
//  Shows current situation; button presence signals readiness.
//

import SwiftUI

struct WhatsNextCardView: View {
    // Status display
    let awakeTime: String
    let lastSleepTime: String
    let lastSleepDuration: String
    let lastFeedTime: String
    let lastFeedAmount: String

    // Contextual actions
    let showSleepAction: Bool
    let showFeedAction: Bool
    let onStartNap: () -> Void
    let onLogFeed: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: BTSpacing.lg) {
            // Hero headline: "Awake 2h 0m" as one flowing unit
            HStack(alignment: .firstTextBaseline, spacing: BTSpacing.xs) {
                Text("Awake")
                    .foregroundStyle(BTColors.textTertiary)
                Text(awakeTime)
                    .foregroundStyle(BTColors.textPrimary)
            }
            .font(.system(size: 48, weight: .semibold, design: .rounded))

            // Status rows with SF Symbols
            VStack(alignment: .leading, spacing: BTSpacing.sm) {
                StatusRow(
                    symbol: "zzz",
                    time: lastSleepTime,
                    detail: lastSleepDuration
                )
                StatusRow(
                    symbol: "drop.fill",
                    time: lastFeedTime,
                    detail: lastFeedAmount
                )
            }

            // Contextual action buttons
            if showSleepAction || showFeedAction {
                HStack(spacing: BTSpacing.sm) {
                    if showSleepAction {
                        ActionButton(label: "Start Nap", action: onStartNap)
                    }
                    if showFeedAction {
                        ActionButton(label: "Log Feed", action: onLogFeed)
                    }
                }
            }
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
        .accessibilityLabel(accessibilityDescription)
    }

    private var accessibilityDescription: String {
        var description = "Awake for \(spokenTime(awakeTime)). "
        description += "Last slept at \(lastSleepTime) for \(spokenTime(lastSleepDuration)). "
        description += "Last fed at \(lastFeedTime), \(lastFeedAmount)."

        if showSleepAction && showFeedAction {
            description += " Ready for nap or feed."
        } else if showSleepAction {
            description += " Ready for nap."
        } else if showFeedAction {
            description += " Ready for feed."
        }

        return description
    }

    private func spokenTime(_ time: String) -> String {
        time
            .replacingOccurrences(of: "h ", with: " hour ")
            .replacingOccurrences(of: "h", with: " hour")
            .replacingOccurrences(of: "m", with: " minutes")
    }
}

// MARK: - Subcomponents

private struct StatusRow: View {
    let symbol: String
    let time: String
    let detail: String

    var body: some View {
        HStack(spacing: BTSpacing.sm) {
            Image(systemName: symbol)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(BTColors.textTertiary)
                .frame(width: 24)

            Text(time)
                .foregroundStyle(BTColors.textSecondary)

            Text("·")
                .foregroundStyle(BTColors.textTertiary)

            Text(detail)
                .foregroundStyle(BTColors.textSecondary)
        }
        .font(.system(size: 20, weight: .medium, design: .rounded))
    }
}

private struct ActionButton: View {
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundStyle(BTColors.actionPrimary)
                .padding(.horizontal, BTSpacing.md)
                .padding(.vertical, BTSpacing.sm)
                .background(BTColors.actionPrimarySubtle)
                .clipShape(Capsule())
        }
    }
}

// MARK: - Previews: Kaia on February 6, 2026

#Preview("7:15 AM - Early morning, no actions") {
    PreviewWrapper {
        WhatsNextCardView(
            awakeTime: "30m",
            lastSleepTime: "6:45 AM",
            lastSleepDuration: "8h",
            lastFeedTime: "6:50 AM",
            lastFeedAmount: "4oz",
            showSleepAction: false,
            showFeedAction: false,
            onStartNap: {},
            onLogFeed: {}
        )
    }
}

#Preview("8:20 AM - Nap ready") {
    PreviewWrapper {
        WhatsNextCardView(
            awakeTime: "1h 25m",
            lastSleepTime: "6:45 AM",
            lastSleepDuration: "8h",
            lastFeedTime: "7:15 AM",
            lastFeedAmount: "4oz",
            showSleepAction: true,
            showFeedAction: false,
            onStartNap: {},
            onLogFeed: {}
        )
    }
}

#Preview("10:45 AM - Feed ready") {
    PreviewWrapper {
        WhatsNextCardView(
            awakeTime: "45m",
            lastSleepTime: "10:00 AM",
            lastSleepDuration: "35m",
            lastFeedTime: "7:15 AM",
            lastFeedAmount: "4oz",
            showSleepAction: false,
            showFeedAction: true,
            onStartNap: {},
            onLogFeed: {}
        )
    }
}

#Preview("2:30 PM - Both ready") {
    PreviewWrapper {
        WhatsNextCardView(
            awakeTime: "1h 30m",
            lastSleepTime: "1:00 PM",
            lastSleepDuration: "40m",
            lastFeedTime: "11:30 AM",
            lastFeedAmount: "5oz",
            showSleepAction: true,
            showFeedAction: true,
            onStartNap: {},
            onLogFeed: {}
        )
    }
}

#Preview("Dark Mode - Both ready") {
    PreviewWrapper {
        WhatsNextCardView(
            awakeTime: "1h 30m",
            lastSleepTime: "1:00 PM",
            lastSleepDuration: "40m",
            lastFeedTime: "11:30 AM",
            lastFeedAmount: "5oz",
            showSleepAction: true,
            showFeedAction: true,
            onStartNap: {},
            onLogFeed: {}
        )
    }
    .preferredColorScheme(.dark)
}

// MARK: - Preview Helper

private struct PreviewWrapper<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        ZStack {
            BTColors.surfacePage
                .ignoresSafeArea()

            VStack {
                Spacer()
                    .frame(height: 120)

                content()
                    .padding(.horizontal, BTSpacing.md)

                Spacer()
            }
        }
    }
}
