//
//  JoinShareView.swift
//  BabyTime
//
//  In-app CloudKit share acceptance. Bypasses iOS App Store URL routing
//  by fetching share metadata directly from a pasted URL.
//  See SYNC.md Phase 6.
//

import CloudKit
import Dependencies
import SQLiteData
import SwiftUI

struct JoinShareView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var shareURLText = ""
    @State private var isAccepting = false
    @State private var error: String?
    @State private var didAccept = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("Paste the iCloud share link you received to join a shared baby.")
                    .font(BTTypography.label)
                    .tracking(BTTracking.label)
                    .foregroundStyle(Color.btTextSecondary)
                    .multilineTextAlignment(.center)

                TextField("https://www.icloud.com/share/...", text: $shareURLText)
                    .textContentType(.URL)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textFieldStyle(.roundedBorder)

                if let error {
                    Text(error)
                        .font(BTTypography.label)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }

                if didAccept {
                    Label("Joined successfully!", systemImage: "checkmark.circle.fill")
                        .font(BTTypography.label)
                        .foregroundStyle(.green)
                } else {
                    Button {
                        acceptShare()
                    } label: {
                        if isAccepting {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        } else {
                            Text("Join")
                                .font(BTTypography.label)
                                .tracking(BTTracking.label)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.btFeedAccent)
                                .clipShape(Capsule())
                        }
                    }
                    .disabled(shareURLText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isAccepting)
                }

                Spacer()
            }
            .padding(.horizontal, BTSpacing.pageMargin)
            .padding(.top, 20)
            .navigationTitle("Join Shared Baby")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(didAccept ? "Done" : "Cancel") { dismiss() }
                }
            }
        }
    }

    private func acceptShare() {
        let trimmed = shareURLText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed),
              trimmed.contains("icloud.com/share") else {
            error = "Please paste a valid iCloud share link"
            return
        }

        error = nil
        isAccepting = true

        Task {
            do {
                let metadata = try await fetchShareMetadata(url: url)
                @Dependency(\.defaultSyncEngine) var syncEngine
                try await syncEngine.acceptShare(metadata: metadata)
                await MainActor.run {
                    didAccept = true
                    isAccepting = false
                    NotificationCenter.default.post(name: .didAcceptCloudKitShare, object: nil)
                }
            } catch {
                await MainActor.run {
                    self.error = "Failed: \(error.localizedDescription)"
                    isAccepting = false
                }
            }
        }
    }

    private func fetchShareMetadata(url: URL) async throws -> CKShare.Metadata {
        try await withCheckedThrowingContinuation { continuation in
            let operation = CKFetchShareMetadataOperation(shareURLs: [url])
            operation.perShareMetadataResultBlock = { _, result in
                continuation.resume(with: result)
            }
            operation.qualityOfService = .userInitiated
            CKContainer(identifier: "iCloud.com.patrickmckowen.BabyTime").add(operation)
        }
    }
}
