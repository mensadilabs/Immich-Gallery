//
//  ImageDownsamplerTests.swift
//  Immich GalleryTests
//
//  Large originals must be decoded at the size they are drawn aspect-fit on
//  screen (issue #157), and small images must never be upscaled.
//

import Testing
import UIKit
import ImageIO
import UniformTypeIdentifiers
@testable import Immich_Gallery

struct ImageDownsamplerTests {

    private let screen4K = CGSize(width: 3840, height: 2160)

    /// JPEG with `width`×`height` stored pixels and the given EXIF orientation.
    private func jpegData(width: Int, height: Int, orientation: Int = 1) throws -> Data {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format)
        let image = renderer.image { context in
            UIColor.systemTeal.setFill()
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
        let cgImage = try #require(image.cgImage)

        let data = NSMutableData()
        let destination = try #require(CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil))
        let properties = [
            kCGImagePropertyOrientation: orientation,
            kCGImageDestinationLossyCompressionQuality: 0.8
        ] as CFDictionary
        CGImageDestinationAddImage(destination, cgImage, properties)
        #expect(CGImageDestinationFinalize(destination))
        return data as Data
    }

    private func pixelSize(of image: UIImage) throws -> CGSize {
        let cgImage = try #require(image.cgImage)
        return CGSize(width: cgImage.width, height: cgImage.height)
    }

    @Test func landscapeImageFitsWithinScreenPreservingAspectRatio() throws {
        let data = try jpegData(width: 8000, height: 5000)

        let image = try #require(ImageDownsampler.downsampledImage(from: data, screenPixelSize: screen4K))
        let size = try pixelSize(of: image)

        #expect(size.width <= 3840)
        #expect(size.height <= 2160)
        #expect(size.height >= 2159) // fills the screen height, not just "smaller"
        #expect(abs(size.width / size.height - 8000.0 / 5000.0) < 0.01)
    }

    @Test func portraitImageIsDecodedAtScreenHeight() throws {
        let data = try jpegData(width: 3000, height: 4000)

        let image = try #require(ImageDownsampler.downsampledImage(from: data, screenPixelSize: screen4K))
        let size = try pixelSize(of: image)

        #expect(size.height <= 2160)
        #expect(size.height >= 2159)
        #expect(abs(size.width / size.height - 3000.0 / 4000.0) < 0.01)
    }

    @Test func exifRotatedImageIsFittedInDisplayOrientation() throws {
        // Stored landscape, but orientation 6 (rotated 90°) displays it as 3000×4000 portrait
        let data = try jpegData(width: 4000, height: 3000, orientation: 6)

        let image = try #require(ImageDownsampler.downsampledImage(from: data, screenPixelSize: screen4K))
        let size = try pixelSize(of: image)

        #expect(size.width < size.height)
        #expect(size.height <= 2160)
        #expect(size.height >= 2159)
    }

    @Test func smallImageIsNotUpscaled() throws {
        let data = try jpegData(width: 1200, height: 800)

        let image = try #require(ImageDownsampler.downsampledImage(from: data, screenPixelSize: screen4K))
        let size = try pixelSize(of: image)

        #expect(size == CGSize(width: 1200, height: 800))
    }

    @Test func undecodableDataReturnsNil() {
        #expect(ImageDownsampler.downsampledImage(from: Data("not an image".utf8), screenPixelSize: screen4K) == nil)
    }
}
