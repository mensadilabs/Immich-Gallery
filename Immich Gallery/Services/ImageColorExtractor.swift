//
//  ImageColorExtractor.swift
//  Immich Gallery
//
//  Created by mensadi-labs on 2025-09-02.
//

import SwiftUI
import UIKit
import CoreImage

/// Utility class for extracting dominant colors from images
class ImageColorExtractor {
    
    /// Extracts the dominant color from a UIImage asynchronously
    /// - Parameter image: The UIImage to extract color from
    /// - Returns: The dominant Color, or black as fallback
    static func extractDominantColorAsync(from image: UIImage) async -> Color {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                guard let cgImage = image.cgImage else {
                    continuation.resume(returning: .black)
                    return
                }

                // Resize image to 50x50 using Core Image
                let ciImage = CIImage(cgImage: cgImage)
                let scale = CGAffineTransform(scaleX: 50.0 / ciImage.extent.width, y: 50.0 / ciImage.extent.height)
                let resizedCIImage = ciImage.transformed(by: scale)

                let context = CIContext()
                guard let resizedCGImage = context.createCGImage(resizedCIImage, from: resizedCIImage.extent) else {
                    continuation.resume(returning: .black)
                    return
                }

                let width = resizedCGImage.width
                let height = resizedCGImage.height
                let bytesPerPixel = 4
                let bytesPerRow = bytesPerPixel * width
                let pixelCount = width * height

                let pixelData = UnsafeMutablePointer<UInt8>.allocate(capacity: pixelCount * bytesPerPixel)
                defer { pixelData.deallocate() }

                guard let bitmapContext = CGContext(
                    data: pixelData,
                    width: width,
                    height: height,
                    bitsPerComponent: 8,
                    bytesPerRow: bytesPerRow,
                    space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                ) else {
                    continuation.resume(returning: .black)
                    return
                }

                bitmapContext.draw(resizedCGImage, in: CGRect(x: 0, y: 0, width: width, height: height))

                // Count quantized color frequency
                var colorCounts: [UInt32: Int] = [:]

                for i in 0..<pixelCount {
                    let offset = i * bytesPerPixel
                    let r = pixelData[offset]
                    let g = pixelData[offset + 1]
                    let b = pixelData[offset + 2]

                    // Skip very dark or very bright pixels
                    if r < 30 && g < 30 && b < 30 { continue }
                    if r > 230 && g > 230 && b > 230 { continue }

                    let reducedR = (r / 32) * 32
                    let reducedG = (g / 32) * 32
                    let reducedB = (b / 32) * 32

                    let key = (UInt32(reducedR) << 16) | (UInt32(reducedG) << 8) | UInt32(reducedB)
                    colorCounts[key, default: 0] += 1
                }

                guard let dominantColorKey = colorCounts.max(by: { $0.value < $1.value })?.key else {
                    continuation.resume(returning: .black)
                    return
                }

                let r = Double((dominantColorKey >> 16) & 0xFF) / 255.0
                let g = Double((dominantColorKey >> 8) & 0xFF) / 255.0
                let b = Double(dominantColorKey & 0xFF) / 255.0

                // Adjust brightness for contrast (optional)
                let brightness = 0.299 * r + 0.587 * g + 0.114 * b
                let darkenFactor = brightness > 0.6 ? 0.6 : 1.0 // Darken only if it's too bright

                let color = Color(
                    red: r * darkenFactor,
                    green: g * darkenFactor,
                    blue: b * darkenFactor
                )

                continuation.resume(returning: color)
            }
        }
    }
    
    /// Extracts dominant color synchronously (for compatibility)
    /// - Parameter image: The UIImage to extract color from
    /// - Returns: The dominant Color, or black as fallback
    static func extractDominantColor(from image: UIImage) -> Color {
        guard let cgImage = image.cgImage else {
            return .black
        }

        // Resize image to 50x50 using Core Image
        let ciImage = CIImage(cgImage: cgImage)
        let scale = CGAffineTransform(scaleX: 50.0 / ciImage.extent.width, y: 50.0 / ciImage.extent.height)
        let resizedCIImage = ciImage.transformed(by: scale)

        let context = CIContext()
        guard let resizedCGImage = context.createCGImage(resizedCIImage, from: resizedCIImage.extent) else {
            return .black
        }

        let width = resizedCGImage.width
        let height = resizedCGImage.height
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let pixelCount = width * height

        let pixelData = UnsafeMutablePointer<UInt8>.allocate(capacity: pixelCount * bytesPerPixel)
        defer { pixelData.deallocate() }

        guard let bitmapContext = CGContext(
            data: pixelData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return .black
        }

        bitmapContext.draw(resizedCGImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        // Count quantized color frequency
        var colorCounts: [UInt32: Int] = [:]

        for i in 0..<pixelCount {
            let offset = i * bytesPerPixel
            let r = pixelData[offset]
            let g = pixelData[offset + 1]
            let b = pixelData[offset + 2]

            // Skip very dark or very bright pixels
            if r < 30 && g < 30 && b < 30 { continue }
            if r > 230 && g > 230 && b > 230 { continue }

            let reducedR = (r / 32) * 32
            let reducedG = (g / 32) * 32
            let reducedB = (b / 32) * 32

            let key = (UInt32(reducedR) << 16) | (UInt32(reducedG) << 8) | UInt32(reducedB)
            colorCounts[key, default: 0] += 1
        }

        guard let dominantColorKey = colorCounts.max(by: { $0.value < $1.value })?.key else {
            return .black
        }

        let r = Double((dominantColorKey >> 16) & 0xFF) / 255.0
        let g = Double((dominantColorKey >> 8) & 0xFF) / 255.0
        let b = Double(dominantColorKey & 0xFF) / 255.0

        // Adjust brightness for contrast (optional)
        let brightness = 0.299 * r + 0.587 * g + 0.114 * b
        let darkenFactor = brightness > 0.6 ? 0.6 : 1.0 // Darken only if it's too bright

        let color = Color(
            red: r * darkenFactor,
            green: g * darkenFactor,
            blue: b * darkenFactor
        )

        return color
    }
}