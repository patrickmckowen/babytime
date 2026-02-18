//
//  DayPagerView.swift
//  BabyTime
//
//  Swipeable horizontal pager wrapping TimelineDayView for each day.
//  Edit sheets and delete confirmation attached here.
//

import SwiftUI
import SwiftData

struct DayPagerView: View {
    @Environment(ActivityManager.self) private var activityManager

    @State private var selectedDayIndex: Int = 0
    @State private var editingBottleEvent: FeedEvent?
    @State private var editingNursingEvent: FeedEvent?
    @State private var editingSleepEvent: SleepEvent?
    @State private var entryToDelete: LogEntry?
    @State private var showDeleteConfirmation = false

    var body: some View {
        TabView(selection: $selectedDayIndex) {
            ForEach(Array(days.enumerated()), id: \.offset) { index, date in
                dayPage(for: date)
                    .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .background(Color.btBackground)
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { selectedDayIndex = todayIndex }
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

    // MARK: - Day Page

    @ViewBuilder
    private func dayPage(for date: Date) -> some View {
        let timeline = buildTimeline(for: date)
        TimelineDayView(
            day: timeline,
            babyName: activityManager.babyName,
            onTapEvent: { tapEvent($0) },
            onDeleteEvent: { entry in
                entryToDelete = entry
                showDeleteConfirmation = true
            }
        )
    }

    // MARK: - Data

    private var days: [Date] {
        var result = activityManager.daysWithEvents()
        let today = Calendar.current.startOfDay(for: Date())
        if !result.contains(today) {
            result.append(today)
        }
        // Sort oldest first so swiping right goes forward in time
        return result.sorted()
    }

    private var todayIndex: Int {
        let today = Calendar.current.startOfDay(for: Date())
        return days.firstIndex(of: today) ?? (days.count - 1)
    }

    private func buildTimeline(for date: Date) -> TimelineDay {
        let feeds = activityManager.feedEvents(for: date)
        let naps = activityManager.sleepEvents(for: date)
        let wake = activityManager.wakeEvent(for: date)
        let nightSleep = activityManager.nightSleep(for: date)
        let bedtime = activityManager.baby?.bedtimeToday(referenceDate: date)

        return TimelineDay.build(
            date: date,
            wakeTime: wake?.time,
            feeds: feeds,
            naps: naps,
            nightSleep: nightSleep,
            bedtime: bedtime,
            now: Date()
        )
    }

    // MARK: - Navigation Title

    private var navigationTitle: String {
        guard days.indices.contains(selectedDayIndex) else { return "Log" }
        let date = days[selectedDayIndex]
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEE, MMMM d"
            return formatter.string(from: date)
        }
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

// MARK: - Preview

#Preview("Day Pager") {
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

    let cal = Calendar.current
    let today = Date()

    // --- Today: realistic full day ---

    // Wake at 6:30 AM
    manager.setWakeTime(
        cal.date(bySettingHour: 6, minute: 30, second: 0, of: today)!
    )

    // 6:45 AM — 4oz bottle
    manager.saveBottle(
        amountOz: 4,
        at: cal.date(bySettingHour: 6, minute: 45, second: 0, of: today)!
    )

    // 8:00–9:15 AM — Nap 1 (1h 15m)
    manager.saveSleepManual(
        startTime: cal.date(bySettingHour: 8, minute: 0, second: 0, of: today)!,
        endTime: cal.date(bySettingHour: 9, minute: 15, second: 0, of: today)!
    )

    // 9:30 AM — Nursed 12 min
    manager.saveNursingManual(
        startTime: cal.date(bySettingHour: 9, minute: 30, second: 0, of: today)!,
        endTime: cal.date(bySettingHour: 9, minute: 42, second: 0, of: today)!
    )

    // 11:00 AM–12:30 PM — Nap 2 (1h 30m)
    manager.saveSleepManual(
        startTime: cal.date(bySettingHour: 11, minute: 0, second: 0, of: today)!,
        endTime: cal.date(bySettingHour: 12, minute: 30, second: 0, of: today)!
    )

    // 1:00 PM — 5oz bottle
    manager.saveBottle(
        amountOz: 5,
        at: cal.date(bySettingHour: 13, minute: 0, second: 0, of: today)!
    )

    // 2:30–3:15 PM — Nap 3 (45m)
    manager.saveSleepManual(
        startTime: cal.date(bySettingHour: 14, minute: 30, second: 0, of: today)!,
        endTime: cal.date(bySettingHour: 15, minute: 15, second: 0, of: today)!
    )

    // 3:30 PM — 4oz bottle
    manager.saveBottle(
        amountOz: 4,
        at: cal.date(bySettingHour: 15, minute: 30, second: 0, of: today)!
    )

    // --- Yesterday: events for swipe testing ---

    let yesterday = cal.date(byAdding: .day, value: -1, to: today)!

    manager.saveBottle(
        amountOz: 4,
        at: cal.date(bySettingHour: 7, minute: 0, second: 0, of: yesterday)!
    )
    manager.saveSleepManual(
        startTime: cal.date(bySettingHour: 8, minute: 30, second: 0, of: yesterday)!,
        endTime: cal.date(bySettingHour: 9, minute: 45, second: 0, of: yesterday)!
    )
    manager.saveNursingManual(
        startTime: cal.date(bySettingHour: 10, minute: 0, second: 0, of: yesterday)!,
        endTime: cal.date(bySettingHour: 10, minute: 15, second: 0, of: yesterday)!
    )
    manager.saveSleepManual(
        startTime: cal.date(bySettingHour: 12, minute: 0, second: 0, of: yesterday)!,
        endTime: cal.date(bySettingHour: 13, minute: 30, second: 0, of: yesterday)!
    )
    manager.saveBottle(
        amountOz: 5,
        at: cal.date(bySettingHour: 14, minute: 0, second: 0, of: yesterday)!
    )
    manager.saveSleepManual(
        startTime: cal.date(bySettingHour: 15, minute: 30, second: 0, of: yesterday)!,
        endTime: cal.date(bySettingHour: 16, minute: 15, second: 0, of: yesterday)!
    )
    manager.saveBottle(
        amountOz: 4,
        at: cal.date(bySettingHour: 16, minute: 30, second: 0, of: yesterday)!
    )

    return NavigationStack {
        DayPagerView()
    }
    .environment(manager)
}
