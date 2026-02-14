//
//  BabyPhotoHeader.swift
//  BabyTime
//
//  Fullbleed baby photo area with date/age overlay.
//

import SwiftUI

struct BabyPhotoHeader: View {
    let babyName: String
    let dateString: String
    let ageString: String
    var photoData: Data? = nil
    var onPhotoTap: (() -> Void)? = nil

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Photo area / placeholder
            if let photoData, let uiImage = UIImage(data: photoData) {
                // Has photo — Color.clear establishes the 4:3 frame,
                // image fills via overlay, clipped to the frame bounds
                Color.clear
                    .aspectRatio(4 / 3, contentMode: .fit)
                    .overlay {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                    }
                    .overlay(alignment: .bottom) {
                        // Gradient scrim for text readability
                        LinearGradient(
                            colors: [.clear, .black.opacity(0.45)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 100)
                    }
                    .clipped()
            } else {
                // Empty state: placeholder with initial + "Add photo"
                Color.btPhotoPlaceholder
                    .aspectRatio(4 / 3, contentMode: .fit)
                    .overlay {
                        VStack(spacing: 8) {
                            Circle()
                                .fill(Color.btTextMuted.opacity(0.5))
                                .frame(width: 80, height: 80)
                                .overlay {
                                    Text(String(babyName.prefix(1)))
                                        .font(.system(size: 32, weight: .medium))
                                        .foregroundStyle(.white)
                                }

                            Text("Add photo")
                                .font(BTTypography.label)
                                .tracking(BTTracking.label)
                                .foregroundStyle(Color.btTextSecondary)
                        }
                    }
            }

            // Date + age overlay
            VStack(alignment: .leading, spacing: 2) {
                Text(dateString)
                    .font(BTTypography.photoDate)
                    .tracking(BTTracking.photoDate)

                Text(ageString)
                    .font(BTTypography.photoAge)
                    .tracking(BTTracking.photoAge)
            }
            .foregroundStyle(photoData != nil ? .white : Color.btTextPrimary)
            .padding(.horizontal, BTSpacing.pageMargin)
            .padding(.bottom, 20)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onPhotoTap?()
        }
        .animation(.easeInOut(duration: 0.3), value: photoData)
    }
}

#Preview("No photo") {
    BabyPhotoHeader(
        babyName: "Kaia",
        dateString: "Monday, February 9",
        ageString: "3 months old"
    )
}
