//
//  ImageDownsamplerTests.swift
//  Immich GalleryTests
//
//  Large originals must be decoded at screen size (issue #157), and small
//  images must never be upscaled.
//

import Testing
import UIKit
@testable import Immich_Gallery

struct ImageDownsamplerTests {

    private func jpegData(width: Int, height: Int) throws -> Data {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format)
        let image = renderer.image { context in
            UIColor.systemTeal.setFill()
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
        return try #require(image.jpegData(compressionQuality: 0.8))
    }

    private func pixelSize(of image: UIImage) throws -> CGSize {
        let cgImage = try #require(image.cgImage)
        return CGSize(width: cgImage.width, height: cgImage.height)
    }

    @Test func largeImageIsDownsampledToMaxPixelSizePreservingAspectRatio() throws {
        let data = try jpegData(width: 8000, height: 5000)

        let image = try #require(ImageDownsampler.downsampledImage(from: data, maxPixelSize: 3840))
        let size = try pixelSize(of: image)

        #expect(max(size.width, size.height) <= 3840)
        #expect(max(size.width, size.height) >= 3839)
        #expect(abs(size.width / size.height - 8000.0 / 5000.0) < 0.01)
    }

    @Test func smallImageIsNotUpscaled() throws {
        let data = try jpegData(width: 1200, height: 800)

        let image = try #require(ImageDownsampler.downsampledImage(from: data, maxPixelSize: 3840))
        let size = try pixelSize(of: image)

        #expect(size == CGSize(width: 1200, height: 800))
    }

    @Test func undecodableDataReturnsNil() {
        #expect(ImageDownsampler.downsampledImage(from: Data("not an image".utf8), maxPixelSize: 3840) == nil)
    }
}
