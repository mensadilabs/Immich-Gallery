//
//  ImageDownsampler.swift
//  Immich Gallery
//
//  Decodes full-size images at (at most) the screen's pixel size, so large
//  originals are filtered properly by ImageIO instead of being shrunk by the
//  GPU at draw time (which aliases and costs a lot of memory).
//

import UIKit
import ImageIO

enum ImageDownsampler {
    /// Longest side of the screen in physical pixels (3840 on a 4K Apple TV).
    static var screenMaxPixelSize: CGFloat {
        let bounds = UIScreen.main.nativeBounds
        let longestSide = max(bounds.width, bounds.height)
        return longestSide > 0 ? longestSide : 3840
    }

    /// Decodes `data` so its longest side is at most `maxPixelSize`.
    /// Images that are already smaller keep their native size (never upscaled).
    /// Falls back to `UIImage(data:)` if ImageIO cannot decode the data.
    static func downsampledImage(from data: Data, maxPixelSize: CGFloat = screenMaxPixelSize) -> UIImage? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions) else {
            return UIImage(data: data)
        }

        var targetPixelSize = maxPixelSize
        if let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
           let width = properties[kCGImagePropertyPixelWidth] as? CGFloat,
           let height = properties[kCGImagePropertyPixelHeight] as? CGFloat {
            targetPixelSize = min(maxPixelSize, max(width, height))
        }

        let thumbnailOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: targetPixelSize
        ] as CFDictionary

        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions) else {
            return UIImage(data: data)
        }
        return UIImage(cgImage: cgImage)
    }
}
