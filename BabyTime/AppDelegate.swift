//
//  AppDelegate.swift
//  BabyTime
//
//  AppDelegate + SceneDelegate for CloudKit share acceptance.
//  See SYNC.md Phase 6 for architecture.
//

import CloudKit
import Dependencies
import SQLiteData
import UIKit

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(
            name: "Default Configuration",
            sessionRole: connectingSceneSession.role
        )
        configuration.delegateClass = SceneDelegate.self
        return configuration
    }
}

class SceneDelegate: NSObject, UIWindowSceneDelegate {
    func windowScene(
        _ windowScene: UIWindowScene,
        userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata
    ) {
        acceptShare(metadata: cloudKitShareMetadata)
    }

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        if let metadata = connectionOptions.cloudKitShareMetadata {
            acceptShare(metadata: metadata)
        }
    }

    private func acceptShare(metadata: CKShare.Metadata) {
        Task {
            @Dependency(\.defaultSyncEngine) var syncEngine
            try await syncEngine.acceptShare(metadata: metadata)
            await MainActor.run {
                NotificationCenter.default.post(name: .didAcceptCloudKitShare, object: nil)
            }
        }
    }
}

extension Notification.Name {
    static let didAcceptCloudKitShare = Notification.Name("BabyTime.didAcceptCloudKitShare")
}
