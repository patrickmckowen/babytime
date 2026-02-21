//
//  DeviceIdentity.swift
//  BabyTime
//
//  Local-only device and caregiver identity. Stamped on events at creation time
//  so other devices can see who created what. Values persist in UserDefaults
//  and never sync via CloudKit — each device has its own identity.
//

import Foundation

enum DeviceIdentity {

    private static let deviceIDKey = "bt_deviceID"
    private static let caregiverNameKey = "bt_caregiverName"

    /// Stable UUID for this device. Auto-generated on first access, never changes.
    static var deviceID: String {
        if let id = UserDefaults.standard.string(forKey: deviceIDKey), !id.isEmpty {
            return id
        }
        let id = UUID().uuidString
        UserDefaults.standard.set(id, forKey: deviceIDKey)
        return id
    }

    /// Display name for the person using this device (e.g. "Mom", "Dad").
    /// Set via Settings; empty string until configured.
    static var caregiverName: String {
        get { UserDefaults.standard.string(forKey: caregiverNameKey) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: caregiverNameKey) }
    }
}
