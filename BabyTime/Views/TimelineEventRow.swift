//
//  TimelineEventRow.swift
//  BabyTime
//
//  Right-column event row for the timeline view.
//  Adapted from ActivityLogView's LogRow with same visual design.
//

import SwiftUI

struct TimelineEventRow: View {
    let entry: LogEntry
    let babyName: String

    var body: some View {
        HStack(spacing: 12) {
            BTIcon(kind: iconKind)
                .foregroundStyle(iconColor)
                .frame(width: 16, height: 16)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(BTTypography.label)
                    .tracking(BTTracking.label)
                    .foregroundStyle(Color.btTextPrimary)

                Text(subtitle)
                    .font(BTTypography.caption)
                    .foregroundStyle(Color.btTextSecondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.btTextMuted)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.btBackground)
        .contentShape(Rectangle())
    }

    private var iconKind: BTIcon.Kind {
        switch entry {
        case .feed(let e):
            return e.kind == .nursing ? .nursing : .bottle
        case .sleep:
            return .sleep
        }
    }

    private var iconColor: Color {
        switch entry {
        case .feed: return Color.btFeedAccent
        case .sleep: return Color.btSleepAccent
        }
    }

    private var title: String {
        switch entry {
        case .feed(let e):
            if e.kind == .nursing {
                let mins = e.durationMinutes ?? 0
                return "\(babyName) was breastfed for \(mins)m"
            } else {
                let oz = Int(e.amountOz)
                return "\(babyName) had a \(oz)oz bottle"
            }
        case .sleep(let e):
            return "\(babyName) slept for \(e.durationDescription)"
        }
    }

    private var subtitle: String {
        switch entry {
        case .feed(let e):
            if e.kind == .nursing {
                let end = e.endTime?.shortTime ?? "--"
                return "\(e.startTime.shortTime) \u{2013} \(end)"
            } else {
                return e.startTime.shortTime
            }
        case .sleep(let e):
            let end = e.endTime?.shortTime ?? "--"
            return "\(e.startTime.shortTime) \u{2013} \(end)"
        }
    }
}
