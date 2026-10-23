//
//  ImageDownsampler.swift
//  Immich Gallery
//
//  Decodes full-size images at (at most) the size they are drawn on screen,
//  so large originals are filtered properly by ImageIO instead of being shrunk
//  by the GPU at draw time (which aliases and costs a lot of memory).
//

import UIKit
import ImageIO

enum ImageDownsampler {
    /// Screen size in physical pixels, landscape (3840×2160 on a 4K Apple TV).
    static var screenPixelSize: CGSize {
        let bounds = UIScreen.main.nativeBounds
        let longestSide = max(bounds.width, bounds.height)
        let shortestSide = min(bounds.width, bounds.height)
        guard shortestSide > 0 else { return CGSize(width: 3840, height: 2160) }
        return CGSize(width: longestSide, height: shortestSide)
    }

    /// Decodes `data` at the size it takes when shown aspect-fit on a screen of
    /// `screenPixelSize`. Images that already fit keep their native size (never upscaled).
    /// Falls back to `UIImage(data:)` if ImageIO cannot decode the data.
    static func downsampledImage(from data: Data, screenPixelSize: CGSize = screenPixelSize) -> UIImage? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let pixelWidth = (properties[kCGImagePropertyPixelWidth] as? NSNumber)?.doubleValue,
              let pixelHeight = (properties[kCGImagePropertyPixelHeight] as? NSNumber)?.doubleValue,
              pixelWidth > 0, pixelHeight > 0 else {
            return UIImage(data: data)
        }

        // EXIF orientations 5–8 rotate the image by 90°, swapping its displayed width and height
        let orientation = (properties[kCGImagePropertyOrientation] as? NSNumber)?.intValue ?? 1
        let isRotated = (5...8).contains(orientation)
        let width = isRotated ? pixelHeight : pixelWidth
        let height = isRotated ? pixelWidth : pixelHeight

        let scale = min(Double(screenPixelSize.width) / width, Double(screenPixelSize.height) / height, 1)
        // Small epsilon so floating-point noise (e.g. 2160.0000000001) doesn't round up a whole pixel
        let targetPixelSize = (max(width, height) * scale - 1e-6).rounded(.up)

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
