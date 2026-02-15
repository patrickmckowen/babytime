//
//  ActivityLogView.swift
//  BabyTime
//
//  Grouped-by-day list of all feed and sleep events.
//  Tap to edit, swipe to delete.
//

import SwiftUI
import SwiftData

struct ActivityLogView: View {
    @Environment(ActivityManager.self) private var activityManager

    @State private var editingBottleEvent: FeedEvent?
    @State private var editingNursingEvent: FeedEvent?
    @State private var editingSleepEvent: SleepEvent?
    @State private var entryToDelete: LogEntry?
    @State private var showDeleteConfirmation = false

    var body: some View {
        listContent
            .background(Color.btBackground)
            .navigationTitle("Log")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Delete this event?", isPresented: $showDeleteConfirmation) {
                deleteAlert
            }
            .sheet(item: $editingBottleEvent) { event in
                BottleSheetView(editingEvent: event)
            }
            .sheet(item: $editingNursingEvent) { event in
                NursingSheetView(editingEvent: event)
            }
            .sheet(item: $editingSleepEvent) { event in
                SleepSheetView(editingEvent: event)
            }
    }

    // MARK: - List Content

    private var listContent: some View {
        List {
            ForEach(groupedDays, id: \.date) { day in
                Section {
                    dayRows(day)
                } header: {
                    DaySectionHeader(date: day.date)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    @ViewBuilder
    private func dayRows(_ day: DayGroup) -> some View {
        ForEach(day.events) { entry in
            LogRow(entry: entry, babyName: activityManager.babyName)
                .listRowBackground(Color.btBackground)
                .listRowInsets(EdgeInsets())
                .contentShape(Rectangle())
                .onTapGesture { tapEvent(entry) }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        entryToDelete = entry
                        showDeleteConfirmation = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
        }
    }

    // MARK: - Delete Alert

    @ViewBuilder
    private var deleteAlert: some View {
        Button("Delete", role: .destructive) {
            deleteCurrentEntry()
        }
        Button("Cancel", role: .cancel) {
            entryToDelete = nil
        }
    }

    // MARK: - Grouped Data

    private var groupedDays: [DayGroup] {
        let feeds = activityManager.allFeedEvents()
        let sleeps = activityManager.allSleepEvents()

        let feedEntries: [LogEntry] = feeds.map { .feed($0) }
        let sleepEntries: [LogEntry] = sleeps.filter { $0.endTime != nil }.map { .sleep($0) }
        let all = feedEntries + sleepEntries

        let calendar = Calendar.current
        let grouped = Dictionary(grouping: all) { entry in
            calendar.startOfDay(for: entry.startTime)
        }

        return grouped
            .map { DayGroup(date: $0.key, events: $0.value.sorted { $0.startTime > $1.startTime }) }
            .sorted { $0.date > $1.date }
    }

    // MARK: - Actions

    private func tapEvent(_ entry: LogEntry) {
        switch entry {
        case .feed(let event):
            if event.kind == .nursing {
                editingNursingEvent = event
            } else {
                editingBottleEvent = event
            }
        case .sleep(let event):
            editingSleepEvent = event
        }
    }

    private func deleteCurrentEntry() {
        guard let entry = entryToDelete else { return }
        switch entry {
        case .feed(let event):
            activityManager.deleteFeedEvent(event)
        case .sleep(let event):
            activityManager.deleteSleepEvent(event)
        }
        entryToDelete = nil
    }
}

// MARK: - Supporting Types

enum LogEntry: Identifiable {
    case feed(FeedEvent)
    case sleep(SleepEvent)

    var id: PersistentIdentifier {
        switch self {
        case .feed(let e): return e.persistentModelID
        case .sleep(let e): return e.persistentModelID
        }
    }

    var startTime: Date {
        switch self {
        case .feed(let e): return e.startTime
        case .sleep(let e): return e.startTime
        }
    }
}

private struct DayGroup {
    let date: Date
    let events: [LogEntry]
}

// MARK: - Day Section Header

private struct DaySectionHeader: View {
    let date: Date

    var body: some View {
        Text(formatted)
            .font(BTTypography.label)
            .tracking(BTTracking.label)
            .foregroundStyle(Color.btTextPrimary)
            .textCase(nil)
            .listRowInsets(EdgeInsets(top: 12, leading: BTSpacing.pageMargin, bottom: 12, trailing: BTSpacing.pageMargin))
    }

    private var formatted: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEE MMMM d, yyyy"
            return formatter.string(from: date)
        }
    }
}

// MARK: - Log Row

private struct LogRow: View {
    let entry: LogEntry
    let babyName: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: iconName)
                .font(.system(size: 16))
                .foregroundStyle(iconColor)
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
        .padding(.horizontal, BTSpacing.pageMargin)
        .padding(.vertical, 14)
    }

    private var iconName: String {
        switch entry {
        case .feed(let e):
            return e.kind == .nursing ? "drop.fill" : "waterbottle.fill"
        case .sleep:
            return "moon.zzz.fill"
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

// MARK: - Preview

#Preview("Activity Log") {
    let container = try! ModelContainer(
        for: Baby.self, FeedEvent.self, SleepEvent.self, WakeEvent.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let manager = ActivityManager(modelContext: container.mainContext)
    let baby = manager.addBaby(
        name: "Kaia",
        birthdate: Calendar.current.date(byAdding: .day, value: -100, to: Date())!
    )
    manager.selectBaby(baby)

    manager.saveBottle(amountOz: 4, at: Date().addingTimeInterval(-3600))
    manager.saveBottle(amountOz: 5, at: Date().addingTimeInterval(-7200))
    manager.saveSleepManual(
        startTime: Date().addingTimeInterval(-10800),
        endTime: Date().addingTimeInterval(-7200)
    )
    let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
    manager.saveBottle(amountOz: 4, at: yesterday)
    manager.saveBottle(amountOz: 4, at: yesterday.addingTimeInterval(-3600))

    return NavigationStack {
        ActivityLogView()
    }
    .environment(manager)
}
