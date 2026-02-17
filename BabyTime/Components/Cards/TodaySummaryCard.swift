//
//  TodaySummaryCard.swift
//  BabyTime
//
//  Today summary with sleep and feed stat rows.
//

import SwiftUI

struct TodaySummaryCard: View {
    let dateString: String
    let totalSleep: String
    let longestSleep: String
    let napCount: Int
    let totalOz: String
    let feedCount: Int
    let averageOz: String
    var wakeTime: String? = nil
    var bedtimeTime: String? = nil
    var actualBedtime: String? = nil
    var onWakeTimeChanged: ((Date) -> Void)? = nil
    var onBedtimeChanged: ((Date) -> Void)? = nil

    @State private var isEditingWakeTime = false
    @State private var editWakeTime = Date()
    @State private var isEditingBedtime = false
    @State private var editBedtime = Date()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header: Day of the week
            Text(dateString)
                .font(BTTypography.headline)
                .tracking(BTTracking.headline)
                .foregroundStyle(Color.btTextPrimary)

            // Wake time row (always visible)
            WakeTimeRow(
                wakeTime: wakeTime ?? "--",
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

            // Feed row
            SummaryRow(
                iconKind: .bottle,
                iconColor: .btFeedAccent,
                columns: [
                    StatColumn(label: "Feeds", value: "\(feedCount)"),
                    StatColumn(label: "Avg", value: averageOz),
                    StatColumn(label: "Total", value: totalOz)
                ]
            )

            // Divider
            Rectangle()
                .fill(Color.btDivider)
                .frame(height: 1)
                .padding(.vertical, BTSpacing.rowDividerPadding)

            // Naps row
            SummaryRow(
                iconKind: .sleep,
                iconColor: .btSleepAccent,
                columns: [
                    StatColumn(label: "Naps", value: "\(napCount)"),
                    StatColumn(label: "Longest", value: longestSleep),
                    StatColumn(label: "Total", value: totalSleep)
                ]
            )

            // Bedtime row
            if actualBedtime != nil || bedtimeTime != nil {
                Rectangle()
                    .fill(Color.btDivider)
                    .frame(height: 1)
                    .padding(.vertical, BTSpacing.rowDividerPadding)

                if actualBedtime != nil {
                    BedtimeRow(
                        bedtime: actualBedtime ?? "--",
                        isEditing: $isEditingBedtime,
                        editTime: $editBedtime,
                        onConfirm: {
                            onBedtimeChanged?(editBedtime)
                            isEditingBedtime = false
                        }
                    )
                } else {
                    BedtimeRow(bedtime: bedtimeTime ?? "--")
                }
            }
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
    let iconKind: BTIcon.Kind
    let iconColor: Color
    let columns: [StatColumn]

    var body: some View {
        HStack(spacing: BTSpacing.iconToStat) {
            // Icon container
            RoundedRectangle(cornerRadius: BTRadius.iconContainer, style: .continuous)
                .fill(iconColor.opacity(0.10))
                .frame(width: BTIconSize.container, height: BTIconSize.container)
                .overlay {
                    BTIcon(kind: iconKind)
                        .foregroundStyle(iconColor)
                        .frame(width: 16, height: 16)
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

// MARK: - Bedtime Row

private struct BedtimeRow: View {
    let bedtime: String
    var isEditing: Binding<Bool>? = nil
    var editTime: Binding<Date>? = nil
    var onConfirm: (() -> Void)? = nil

    private var isEditable: Bool { isEditing != nil }

    var body: some View {
        HStack(spacing: BTSpacing.iconToStat) {
            RoundedRectangle(cornerRadius: BTRadius.iconContainer, style: .continuous)
                .fill(Color.btSleepAccent.opacity(0.10))
                .frame(width: BTIconSize.container, height: BTIconSize.container)
                .overlay {
                    Image(systemName: "moon.stars.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color.btSleepAccent)
                }

            if let isEditing, isEditing.wrappedValue, let editTime {
                DatePicker(
                    "",
                    selection: editTime,
                    displayedComponents: .hourAndMinute
                )
                .labelsHidden()

                Spacer()

                Button {
                    onConfirm?()
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
                    Text("Bedtime")
                        .font(BTTypography.statLabel)
                        .tracking(BTTracking.statLabel)
                        .foregroundStyle(Color.btTextMuted)

                    Text(bedtime)
                        .font(BTTypography.statValue)
                        .tracking(BTTracking.statValue)
                        .foregroundStyle(Color.btTextPrimary)
                }

                Spacer()
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if isEditable, let isEditing, !isEditing.wrappedValue {
                isEditing.wrappedValue = true
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.btBackground.ignoresSafeArea()
        TodaySummaryCard(
            dateString: "Monday",
            totalSleep: "1h 30m",
            longestSleep: "45m",
            napCount: 3,
            totalOz: "17 oz",
            feedCount: 4,
            averageOz: "4.3 oz",
            bedtimeTime: "7:00 PM"
        )
        .padding(.horizontal, BTSpacing.pageMargin)
    }
}
