//
//  LogView.swift
//  BabyTime
//
//  Full activity log showing today's timeline.
//

import SwiftUI

struct LogView: View {
    let scenario: Scenario

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                TimelineView(activities: scenario.today.allActivities)
                    .padding(.horizontal, BTSpacing.pageMargin)
                    .padding(.top, 16)

                Spacer(minLength: 48)
            }
        }
        .background(Color.btBackground)
    }
}

// MARK: - Preview

#Preview("Log") {
    LogView(scenario: .preview)
}

#Preview("Log - Dark") {
    LogView(scenario: .preview)
        .preferredColorScheme(.dark)
}
