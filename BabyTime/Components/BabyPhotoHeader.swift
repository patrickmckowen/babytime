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

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Photo area / placeholder
            Color.btPhotoPlaceholder
                .aspectRatio(4 / 3, contentMode: .fit)
                .overlay {
                    // Empty state: initial circle + "Add photo"
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

            // Date + age overlay
            VStack(alignment: .leading, spacing: 2) {
                Text(dateString)
                    .font(BTTypography.photoDate)
                    .tracking(BTTracking.photoDate)
                    .foregroundStyle(Color.btTextPrimary)

                Text(ageString)
                    .font(BTTypography.photoAge)
                    .tracking(BTTracking.photoAge)
                    .foregroundStyle(Color.btTextSecondary)
            }
            .padding(.horizontal, BTSpacing.pageMargin)
            .padding(.bottom, 20)
        }
    }
}

#Preview {
    BabyPhotoHeader(
        babyName: "Kaia",
        dateString: "Monday, February 9",
        ageString: "3 months old"
    )
}
