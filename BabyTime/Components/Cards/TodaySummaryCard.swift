//
//  TodaySummaryCard.swift
//  BabyTime
//
//  Today summary with sleep and feed stat rows.
//

import SwiftUI

struct TodaySummaryCard: View {
    let totalSleep: String
    let longestSleep: String
    let napCount: Int
    let totalOz: String
    let feedCount: Int
    let averageOz: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header: "Today"
            Text("Today")
                .font(BTTypography.photoDate)
                .tracking(BTTracking.photoDate)
                .foregroundStyle(Color.btTextPrimary)

            // Sleep row
            SummaryRow(
                iconName: "moon.fill",
                iconColor: .btSleepAccent,
                columns: [
                    StatColumn(label: "Naps", value: "\(napCount)"),
                    StatColumn(label: "Longest", value: longestSleep),
                    StatColumn(label: "Total", value: totalSleep)
                ]
            )
            .padding(.top, BTSpacing.todayHeaderToRow)

            // Divider
            Rectangle()
                .fill(Color.btDivider)
                .frame(height: 1)
                .padding(.vertical, BTSpacing.rowDividerPadding)

            // Feed row
            SummaryRow(
                iconName: "drop.fill",
                iconColor: .btFeedAccent,
                columns: [
                    StatColumn(label: "Feeds", value: "\(feedCount)"),
                    StatColumn(label: "Avg", value: averageOz),
                    StatColumn(label: "Total", value: totalOz)
                ]
            )
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

// MARK: - Stat Column Data

private struct StatColumn: Identifiable {
    let id = UUID()
    let label: String
    let value: String
}

// MARK: - Summary Row

private struct SummaryRow: View {
    let iconName: String
    let iconColor: Color
    let columns: [StatColumn]

    var body: some View {
        HStack(spacing: BTSpacing.iconToStat) {
            // Icon container
            RoundedRectangle(cornerRadius: BTRadius.iconContainer, style: .continuous)
                .fill(iconColor.opacity(0.10))
                .frame(width: BTIconSize.container, height: BTIconSize.container)
                .overlay {
                    Image(systemName: iconName)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(iconColor)
                }

            // Stat columns — equal flex space
            HStack(spacing: 0) {
                ForEach(columns) { column in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(column.label)
                            .font(BTTypography.statLabel)
                            .tracking(BTTracking.statLabel)
                            .foregroundStyle(Color.btTextMuted)

                        Text(column.value)
                            .font(BTTypography.statValue)
                            .tracking(BTTracking.statValue)
                            .foregroundStyle(Color.btTextPrimary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.btBackground.ignoresSafeArea()
        TodaySummaryCard(
            totalSleep: "1h 30m",
            longestSleep: "45m",
            napCount: 3,
            totalOz: "17 oz",
            feedCount: 4,
            averageOz: "4.3 oz"
        )
        .padding(.horizontal, BTSpacing.pageMargin)
    }
}
