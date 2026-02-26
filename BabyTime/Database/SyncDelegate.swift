//
//  SyncDelegate.swift
//  BabyTime
//
//  SyncEngineDelegate that handles iCloud account changes.
//  Shows an alert when the user signs out or switches accounts.
//

import CloudKit
import SQLiteData

@MainActor @Observable
final class SyncDelegate: SyncEngineDelegate, @unchecked Sendable {
    var showResetDataAlert = false

    nonisolated func syncEngine(
        _ syncEngine: SyncEngine,
        accountChanged changeType: CKSyncEngine.Event.AccountChange.ChangeType
    ) async {
        switch changeType {
        case .signOut, .switchAccounts:
            await MainActor.run {
                showResetDataAlert = true
            }
        case .signIn:
            break
        @unknown default:
            break
        }
    }
}
