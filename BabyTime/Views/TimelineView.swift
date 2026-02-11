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
                .tracking(BTTracking.label)
                .foregroundStyle(Color.btTextSecondary)
                .padding(.bottom, 16)

            if activities.isEmpty {
                Text("No activities yet")
                    .font(BTTypography.caption)
                    .foregroundStyle(Color.btTextMuted)
            } else {
                LazyVStack(alignment: .leading, spacing: 24) {
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
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            // Time
            Text(activity.timestamp.shortTime)
                .font(BTTypography.caption)
                .foregroundStyle(Color.btTextMuted)
                .frame(width: 70, alignment: .leading)

            // Icon
            Image(systemName: activity.icon)
                .font(.system(size: 14))
                .foregroundStyle(Color.btTextSecondary)

            // Activity info
            VStack(alignment: .leading, spacing: 2) {
                Text(activity.title)
                    .font(BTTypography.label)
                    .tracking(BTTracking.label)
                    .foregroundStyle(Color.btTextPrimary)

                Text(activity.detail)
                    .font(BTTypography.caption)
                    .foregroundStyle(Color.btTextMuted)
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
            .padding(16)
    }
    .background(Color.btBackground)
}

#Preview("Timeline - Empty") {
    ScrollView {
        TimelineView(activities: [])
            .padding(16)
    }
    .background(Color.btBackground)
}
