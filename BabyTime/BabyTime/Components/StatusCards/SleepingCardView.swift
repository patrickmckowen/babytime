//
//  SleepingCardView.swift
//  BabyTime
//
//  Status card showing sleep overview with daily progress.
//

import SwiftUI

struct SleepingCardView: View {
    // Status display
    let awakeTime: String           // "2h 0m" if awake
    let sleepingTime: String?       // "37m" if currently sleeping
    let napCount: Int
    let totalSleepFormatted: String // "3h 20m"
    let dailyGoal: ClosedRange<Int> // in hours
    let totalSleepMinutes: Int

    // Action
    let onStartNap: () -> Void

    private var isCurrentlySleeping: Bool {
        sleepingTime != nil
    }

    private var progress: Double {
        let midpointHours = Double(dailyGoal.lowerBound + dailyGoal.upperBound) / 2
        let hoursSlept = Double(totalSleepMinutes) / 60.0
        return min(hoursSlept / midpointHours, 1.0)
    }

    private var progressPercent: Int {
        Int(progress * 100)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: BTSpacing.lg) {
            // Header with hero headline and action button
            HStack(alignment: .firstTextBaseline) {
                if let sleepTime = sleepingTime {
                    // Currently sleeping: "Sleeping 37m"
                    HStack(alignment: .firstTextBaseline, spacing: BTSpacing.xs) {
                        Text("Sleeping")
                            .foregroundStyle(BTColors.textTertiary)
                        Text(sleepTime)
                            .foregroundStyle(BTColors.textPrimary)
                    }
                    .font(.system(size: 36, weight: .semibold, design: .rounded))
                } else {
                    // Awake: "Awake 2h 0m"
                    HStack(alignment: .firstTextBaseline, spacing: BTSpacing.xs) {
                        Text("Awake")
                            .foregroundStyle(BTColors.textTertiary)
                        Text(awakeTime)
                            .foregroundStyle(BTColors.textPrimary)
                    }
                    .font(.system(size: 36, weight: .semibold, design: .rounded))
                }

                Spacer()

                // Add button (changes label based on state)
                Button(action: onStartNap) {
                    Image(systemName: isCurrentlySleeping ? "stop.fill" : "plus")
                        .font(.system(size: isCurrentlySleeping ? 16 : 20, weight: .semibold))
                        .foregroundStyle(BTColors.actionPrimary)
                        .frame(width: 36, height: 36)
                        .background(BTColors.actionPrimarySubtle)
                        .clipShape(Circle())
                }
            }

            // Stats row
            VStack(alignment: .leading, spacing: BTSpacing.xxs) {
                HStack(spacing: BTSpacing.sm) {
                    // Nap count
                    Text("\(napCount) nap\(napCount == 1 ? "" : "s")")
                        .foregroundStyle(BTColors.textSecondary)

                    Text("·")
                        .foregroundStyle(BTColors.textTertiary)

                    // Total sleep
                    Text(totalSleepFormatted)
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
        var description: String
        if let sleepTime = sleepingTime {
            description = "Sleeping for \(sleepTime). "
        } else {
            description = "Awake for \(awakeTime). "
        }
        description += "\(napCount) nap\(napCount == 1 ? "" : "s") today, "
        description += "\(totalSleepFormatted) total sleep, "
        description += "\(progressPercent) percent of daily goal."
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
        SleepingCardView(
            awakeTime: "45m",
            sleepingTime: nil,
            napCount: 1,
            totalSleepFormatted: "42m",
            dailyGoal: 14...17,
            totalSleepMinutes: 42,
            onStartNap: {}
        )
    }
}

#Preview("Afternoon - Good progress") {
    PreviewWrapper {
        SleepingCardView(
            awakeTime: "1h 30m",
            sleepingTime: nil,
            napCount: 3,
            totalSleepFormatted: "3h 20m",
            dailyGoal: 14...17,
            totalSleepMinutes: 200,
            onStartNap: {}
        )
    }
}

#Preview("Currently sleeping") {
    PreviewWrapper {
        SleepingCardView(
            awakeTime: "0m",
            sleepingTime: "37m",
            napCount: 2,
            totalSleepFormatted: "2h 45m",
            dailyGoal: 14...17,
            totalSleepMinutes: 165,
            onStartNap: {}
        )
    }
}

#Preview("Evening - Goal progress") {
    PreviewWrapper {
        SleepingCardView(
            awakeTime: "2h 0m",
            sleepingTime: nil,
            napCount: 4,
            totalSleepFormatted: "5h 30m",
            dailyGoal: 14...17,
            totalSleepMinutes: 330,
            onStartNap: {}
        )
    }
}

#Preview("Dark mode") {
    PreviewWrapper {
        SleepingCardView(
            awakeTime: "1h 30m",
            sleepingTime: nil,
            napCount: 3,
            totalSleepFormatted: "3h 20m",
            dailyGoal: 14...17,
            totalSleepMinutes: 200,
            onStartNap: {}
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
