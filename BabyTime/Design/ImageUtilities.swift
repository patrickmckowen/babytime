//
//  ImageUtilities.swift
//  BabyTime
//
//  Resize and compress images for CloudKit-friendly storage.
//

import UIKit

enum ImageUtilities {

    /// Resize and compress image data for profile storage.
    /// - Parameters:
    ///   - data: Raw image data from PhotosPicker
    ///   - maxDimension: Longest edge limit in points (default 1024)
    ///   - quality: JPEG compression quality 0…1 (default 0.7)
    /// - Returns: Compressed JPEG data, or nil if input is invalid
    static func resizeForProfile(
        data: Data,
        maxDimension: CGFloat = 1024,
        quality: CGFloat = 0.7
    ) -> Data? {
        guard let image = UIImage(data: data) else { return nil }

        let size = image.size
        let scale: CGFloat

        if max(size.width, size.height) <= maxDimension {
            scale = 1
        } else {
            scale = maxDimension / max(size.width, size.height)
        }

        let newSize = CGSize(
            width: (size.width * scale).rounded(),
            height: (size.height * scale).rounded()
        )

        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }

        return resized.jpegData(compressionQuality: quality)
    }
}
