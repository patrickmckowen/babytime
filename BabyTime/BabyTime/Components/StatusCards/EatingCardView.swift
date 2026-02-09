//
//  EatingCardView.swift
//  BabyTime
//
//  Status card showing feeding overview with daily progress.
//

import SwiftUI

struct EatingCardView: View {
    // Status display
    let timeSinceLastFeed: String
    let feedCount: Int
    let totalOz: Double
    let dailyGoal: ClosedRange<Int>
    let hasEstimates: Bool

    // Action
    let onAddFeed: () -> Void

    private var progress: Double {
        let midpoint = Double(dailyGoal.lowerBound + dailyGoal.upperBound) / 2
        return min(totalOz / midpoint, 1.0)
    }

    private var progressPercent: Int {
        Int(progress * 100)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: BTSpacing.lg) {
            // Header with hero headline and action button
            HStack(alignment: .firstTextBaseline) {
                // "Ate 1h 30m ago"
                HStack(alignment: .firstTextBaseline, spacing: BTSpacing.xs) {
                    Text("Ate")
                        .foregroundStyle(BTColors.textTertiary)
                    Text(timeSinceLastFeed)
                        .foregroundStyle(BTColors.textPrimary)
                }
                .font(.system(size: 36, weight: .semibold, design: .rounded))

                Spacer()

                // Add button
                Button(action: onAddFeed) {
                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(BTColors.actionPrimary)
                        .frame(width: 36, height: 36)
                        .background(BTColors.actionPrimarySubtle)
                        .clipShape(Circle())
                }
            }

            // Stats row
            VStack(alignment: .leading, spacing: BTSpacing.xxs) {
                HStack(spacing: BTSpacing.sm) {
                    // Feed count
                    Text("\(feedCount) feed\(feedCount == 1 ? "" : "s")")
                        .foregroundStyle(BTColors.textSecondary)

                    Text("·")
                        .foregroundStyle(BTColors.textTertiary)

                    // Total oz (with ~ if estimates)
                    Text(hasEstimates ? "~\(Int(totalOz)) oz" : "\(Int(totalOz)) oz")
                        .foregroundStyle(BTColors.textSecondary)

                    Spacer()

                    // Progress percent
                    Text("\(progressPercent)%")
                        .foregroundStyle(BTColors.textTertiary)
                }
                .font(.system(size: 17, weight: .medium, design: .rounded))

                // Progress bar
                ProgressBar(value: progress)
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
        var description = "Ate \(timeSinceLastFeed). "
        description += "\(feedCount) feed\(feedCount == 1 ? "" : "s") today, "
        description += hasEstimates ? "approximately \(Int(totalOz)) ounces" : "\(Int(totalOz)) ounces"
        description += ", \(progressPercent) percent of daily goal."
        return description
    }
}

// MARK: - Progress Bar

private struct ProgressBar: View {
    let value: Double

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background track
                RoundedRectangle(cornerRadius: 4)
                    .fill(BTColors.actionPrimarySubtle)
                    .frame(height: 8)

                // Fill
                RoundedRectangle(cornerRadius: 4)
                    .fill(BTColors.actionPrimary)
                    .frame(width: geometry.size.width * CGFloat(value), height: 8)
            }
        }
        .frame(height: 8)
    }
}

// MARK: - Previews

#Preview("Morning - Low progress") {
    PreviewWrapper {
        EatingCardView(
            timeSinceLastFeed: "45m ago",
            feedCount: 2,
            totalOz: 8,
            dailyGoal: 24...32,
            hasEstimates: false,
            onAddFeed: {}
        )
    }
}

#Preview("Afternoon - Good progress") {
    PreviewWrapper {
        EatingCardView(
            timeSinceLastFeed: "1h 30m ago",
            feedCount: 4,
            totalOz: 17,
            dailyGoal: 24...32,
            hasEstimates: false,
            onAddFeed: {}
        )
    }
}

#Preview("Evening - Goal met") {
    PreviewWrapper {
        EatingCardView(
            timeSinceLastFeed: "2h ago",
            feedCount: 6,
            totalOz: 28,
            dailyGoal: 24...32,
            hasEstimates: false,
            onAddFeed: {}
        )
    }
}

#Preview("With nursing estimates") {
    PreviewWrapper {
        EatingCardView(
            timeSinceLastFeed: "1h ago",
            feedCount: 4,
            totalOz: 14,
            dailyGoal: 24...32,
            hasEstimates: true,
            onAddFeed: {}
        )
    }
}

#Preview("Dark mode") {
    PreviewWrapper {
        EatingCardView(
            timeSinceLastFeed: "1h 30m ago",
            feedCount: 4,
            totalOz: 17,
            dailyGoal: 24...32,
            hasEstimates: false,
            onAddFeed: {}
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
