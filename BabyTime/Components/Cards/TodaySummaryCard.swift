//
//  TodaySummaryCard.swift
//  BabyTime
//
//  Today summary with sleep and feed stat rows.
//

import SwiftUI

struct TodaySummaryCard: View {
    let dateString: String
    let ageString: String
    let totalSleep: String
    let longestSleep: String
    let napCount: Int
    let totalOz: String
    let feedCount: Int
    let averageOz: String
    var wakeTime: String? = nil
    var onWakeTimeChanged: ((Date) -> Void)? = nil

    @State private var isEditingWakeTime = false
    @State private var editWakeTime = Date()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header: Date and age
            VStack(alignment: .leading, spacing: 2) {
                Text(dateString)
                    .font(BTTypography.photoDate)
                    .tracking(BTTracking.photoDate)
                    .foregroundStyle(Color.btTextPrimary)

                Text(ageString)
                    .font(BTTypography.photoAge)
                    .tracking(BTTracking.photoAge)
                    .foregroundStyle(Color.btTextSecondary)
            }

            // Wake time row (if set)
            if let wakeTime {
                WakeTimeRow(
                    wakeTime: wakeTime,
                    isEditing: $isEditingWakeTime,
                    editTime: $editWakeTime,
                    onConfirm: {
                        onWakeTimeChanged?(editWakeTime)
                        isEditingWakeTime = false
                    }
                )
                .padding(.top, BTSpacing.todayHeaderToRow)

                // Divider
                Rectangle()
                    .fill(Color.btDivider)
                    .frame(height: 1)
                    .padding(.vertical, BTSpacing.rowDividerPadding)
            }

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
            .padding(.top, wakeTime == nil ? BTSpacing.todayHeaderToRow : 0)

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

// MARK: - Wake Time Row

private struct WakeTimeRow: View {
    let wakeTime: String
    @Binding var isEditing: Bool
    @Binding var editTime: Date
    var onConfirm: () -> Void

    var body: some View {
        HStack(spacing: BTSpacing.iconToStat) {
            // Icon container
            RoundedRectangle(cornerRadius: BTRadius.iconContainer, style: .continuous)
                .fill(Color.btSleepAccent.opacity(0.10))
                .frame(width: BTIconSize.container, height: BTIconSize.container)
                .overlay {
                    Image(systemName: "sunrise.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color.btSleepAccent)
                }

            if isEditing {
                DatePicker(
                    "",
                    selection: $editTime,
                    displayedComponents: .hourAndMinute
                )
                .labelsHidden()

                Spacer()

                Button {
                    onConfirm()
                } label: {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(Color.btSleepAccent)
                        .clipShape(Circle())
                }
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Wake")
                        .font(BTTypography.statLabel)
                        .tracking(BTTracking.statLabel)
                        .foregroundStyle(Color.btTextMuted)

                    Text(wakeTime)
                        .font(BTTypography.statValue)
                        .tracking(BTTracking.statValue)
                        .foregroundStyle(Color.btTextPrimary)
                }

                Spacer()
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if !isEditing {
                isEditing = true
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.btBackground.ignoresSafeArea()
        TodaySummaryCard(
            dateString: "Friday, Feb 13",
            ageString: "3 months old",
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
