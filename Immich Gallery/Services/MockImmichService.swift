//
//  MockImmichService.swift
//  Immich Gallery
//
//  Created by mensadi-labs on 2025-06-29.
//

import Foundation
import UIKit

// MARK: - Mock Service for Previews
class MockImmichService: ImmichService {
    override func loadFullImage(from asset: ImmichAsset) async throws -> UIImage? {
        // Generate a simple gradient image for preview (portrait)
        let size = CGSize(width: 1080, height: 1920)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        let image = renderer.image { context in
            let colors = [
                UIColor.systemBlue.cgColor,
                UIColor.systemPurple.cgColor,
                UIColor.systemPink.cgColor
            ]
            
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                    colors: colors as CFArray,
                                    locations: [0.0, 0.5, 1.0])!
            
            context.cgContext.drawLinearGradient(
                gradient,
                start: CGPoint(x: 0, y: 0),
                end: CGPoint(x: size.width, y: size.height),
                options: []
            )
            
            // Add a border to differentiate from background
            let borderWidth: CGFloat = 8.0
            let borderRect = CGRect(x: borderWidth/2, y: borderWidth/2, 
                                  width: size.width - borderWidth, 
                                  height: size.height - borderWidth)
            
            context.cgContext.setStrokeColor(UIColor.white.cgColor)
            context.cgContext.setLineWidth(borderWidth)
            context.cgContext.stroke(borderRect)
            
            // Add some text overlay
            let text = "Preview Image"
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 48, weight: .bold),
                .foregroundColor: UIColor.white
            ]
            
            let textSize = text.size(withAttributes: attributes)
            let textRect = CGRect(
                x: (size.width - textSize.width) / 2,
                y: (size.height - textSize.height) / 2,
                width: textSize.width,
                height: textSize.height
            )
            
            text.draw(in: textRect, withAttributes: attributes)
        }
        
        return image
    }
    
    override func loadImage(from asset: ImmichAsset, size: String = "thumbnail") async throws -> UIImage? {
        // Return the same generated image for thumbnails
        return try await loadFullImage(from: asset)
    }
    
    override func loadAlbumThumbnail(albumId: String, thumbnailAssetId: String, size: String = "thumbnail") async throws -> UIImage? {
        // Generate a smaller thumbnail version
        let thumbnailSize = CGSize(width: 300, height: 200)
        let renderer = UIGraphicsImageRenderer(size: thumbnailSize)
        
        let image = renderer.image { context in
            let colors = [
                UIColor.systemGreen.cgColor,
                UIColor.systemTeal.cgColor,
                UIColor.systemBlue.cgColor
            ]
            
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                    colors: colors as CFArray,
                                    locations: [0.0, 0.5, 1.0])!
            
            context.cgContext.drawLinearGradient(
                gradient,
                start: CGPoint(x: 0, y: 0),
                end: CGPoint(x: thumbnailSize.width, y: thumbnailSize.height),
                options: []
            )
            
            // Add a border
            let borderWidth: CGFloat = 4.0
            let borderRect = CGRect(x: borderWidth/2, y: borderWidth/2, 
                                  width: thumbnailSize.width - borderWidth, 
                                  height: thumbnailSize.height - borderWidth)
            
            context.cgContext.setStrokeColor(UIColor.white.cgColor)
            context.cgContext.setLineWidth(borderWidth)
            context.cgContext.stroke(borderRect)
            
            // Add text
            let text = "Album"
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 24, weight: .bold),
                .foregroundColor: UIColor.white
            ]
            
            let textSize = text.size(withAttributes: attributes)
            let textRect = CGRect(
                x: (thumbnailSize.width - textSize.width) / 2,
                y: (thumbnailSize.height - textSize.height) / 2,
                width: textSize.width,
                height: textSize.height
            )
            
            text.draw(in: textRect, withAttributes: attributes)
        }
        
        return image
    }
    
    override func loadPersonThumbnail(personId: String) async throws -> UIImage? {
        // Generate a circular person thumbnail
        let size = CGSize(width: 200, height: 200)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        let image = renderer.image { context in
            let colors = [
                UIColor.systemOrange.cgColor,
                UIColor.systemRed.cgColor
            ]
            
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                    colors: colors as CFArray,
                                    locations: [0.0, 1.0])!
            
            // Draw circular gradient
            let center = CGPoint(x: size.width/2, y: size.height/2)
            let radius = min(size.width, size.height)/2 - 4
            
            context.cgContext.drawRadialGradient(
                gradient,
                startCenter: center,
                startRadius: 0,
                endCenter: center,
                endRadius: radius,
                options: []
            )
            
            // Add border
            context.cgContext.setStrokeColor(UIColor.white.cgColor)
            context.cgContext.setLineWidth(4.0)
            context.cgContext.strokeEllipse(in: CGRect(x: 2, y: 2, width: size.width-4, height: size.height-4))
            
            // Add person icon
            let text = "👤"
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 60),
                .foregroundColor: UIColor.white
            ]
            
            let textSize = text.size(withAttributes: attributes)
            let textRect = CGRect(
                x: (size.width - textSize.width) / 2,
                y: (size.height - textSize.height) / 2,
                width: textSize.width,
                height: textSize.height
            )
            
            text.draw(in: textRect, withAttributes: attributes)
        }
        
        return image
    }
} 