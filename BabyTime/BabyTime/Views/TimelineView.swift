//
//  TimelineView.swift
//  BabyTime
//
//  Today's activities in reverse chronological order.
//  Typography-forward, containerless design.
//

import SwiftUI

struct TimelineView: View {
    let activities: [Activity]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Today")
                .font(BTTypography.label)
                .foregroundStyle(BTColors.textSecondary)
                .padding(.bottom, BTSpacing.md)

            if activities.isEmpty {
                Text("No activities yet")
                    .font(BTTypography.caption)
                    .foregroundStyle(BTColors.textTertiary)
            } else {
                LazyVStack(alignment: .leading, spacing: BTSpacing.lg) {
                    ForEach(activities) { activity in
                        TimelineRow(activity: activity)
                    }
                }
            }
        }
    }
}

// MARK: - Timeline Row (inline)

private struct TimelineRow: View {
    let activity: Activity

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: BTSpacing.sm) {
            // Time
            Text(activity.timestamp.shortTime)
                .font(BTTypography.caption)
                .foregroundStyle(BTColors.textTertiary)
                .frame(width: 70, alignment: .leading)

            // Icon
            Image(systemName: activity.icon)
                .font(.system(size: 14))
                .foregroundStyle(BTColors.textSecondary)

            // Activity info
            VStack(alignment: .leading, spacing: BTSpacing.xxxs) {
                Text(activity.title)
                    .font(BTTypography.label)
                    .foregroundStyle(BTColors.textPrimary)

                Text(activity.detail)
                    .font(BTTypography.caption)
                    .foregroundStyle(BTColors.textTertiary)
            }

            Spacer()
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(activity.title) at \(activity.timestamp.shortTime), \(activity.detail)")
    }
}

// MARK: - Preview

#Preview("Timeline") {
    ScrollView {
        TimelineView(activities: Scenario.preview.today.allActivities)
            .padding(BTSpacing.md)
    }
    .background(BTColors.surfacePage)
}

#Preview("Timeline - Dark") {
    ScrollView {
        TimelineView(activities: Scenario.preview.today.allActivities)
            .padding(BTSpacing.md)
    }
    .background(BTColors.surfacePage)
    .preferredColorScheme(.dark)
}

#Preview("Timeline - Empty") {
    ScrollView {
        TimelineView(activities: [])
            .padding(BTSpacing.md)
    }
    .background(BTColors.surfacePage)
}
