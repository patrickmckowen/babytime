//
//  DateFormatting.swift
//  BabyTime
//
//  Shared date formatting helpers.
//

import Foundation

extension Date {
    var shortTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: self)
    }
}
