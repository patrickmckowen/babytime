//
//  TimePickerSheet.swift
//  BabyTime
//
//  Medium-detent sheet with a time picker. Used for "Went to bed" and "Woke up" actions.
//

import SwiftUI

struct TimePickerSheet: View {
    let title: String
    let onSave: (Date) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedTime = Date()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Spacer()

                DatePicker(
                    title,
                    selection: $selectedTime,
                    displayedComponents: .hourAndMinute
                )
                .datePickerStyle(.wheel)
                .labelsHidden()

                Spacer()
            }
            .frame(maxWidth: .infinity)
            .background(Color.btBackground)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .cancel) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(role: .confirm) {
                        onSave(selectedTime)
                        dismiss()
                    }
                    .tint(Color.btSleepAccent)
                }
            }
        }
    }
}

#Preview("Went to bed") {
    Text("Home")
        .sheet(isPresented: .constant(true)) {
            TimePickerSheet(title: "Went to bed") { time in
                print("Bedtime: \(time)")
            }
            .presentationDetents([.medium])
        }
}

#Preview("Woke up") {
    Text("Home")
        .sheet(isPresented: .constant(true)) {
            TimePickerSheet(title: "Woke up") { time in
                print("Wake: \(time)")
            }
            .presentationDetents([.medium])
        }
}
