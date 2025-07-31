//
//  ExifInfoOverlay.swift
//  Immich Gallery
//
//  Created by mensadi-labs on 2025-06-29.
//

import SwiftUI

struct ExifInfoOverlay: View {
    let asset: ImmichAsset
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.white)
                    .font(.title3)
                Text("Photo Information")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                Spacer()
            }
            .padding(.bottom, 8)
            
            HStack{
                // Date and time
                if let dateTimeOriginal = asset.exifInfo?.dateTimeOriginal {
                    TechnicalInfoItem(icon: "calendar", label: "Date", value: DateFormatter.formatSpecificISO8601(dateTimeOriginal, includeTime: true))
                } else {
                    TechnicalInfoItem(icon: "calendar.badge.exclamationmark", label: "Date (file created)", value: DateFormatter.formatSpecificISO8601(asset.fileCreatedAt, includeTime: true))
                }}
            .padding(.bottom, 8)
            
            HStack{
                // Location
                if let city = asset.exifInfo?.city, let state = asset.exifInfo?.state, let country = asset.exifInfo?.country {
                    TechnicalInfoItem(icon: "map", label: "Location", value: "\(city), \(state), \(country)")
                } else if let city = asset.exifInfo?.city, let country = asset.exifInfo?.country {
                    TechnicalInfoItem(icon: "map", label: "Location", value: "\(city), \(country)")
                } else if let country = asset.exifInfo?.country {
                    TechnicalInfoItem(icon: "map", label: "Location", value: country)
                }
            } .padding(.bottom, 8)
            
            
            if let make = asset.exifInfo?.make, let model = asset.exifInfo?.model {
                TechnicalInfoItem(icon: "camera", label: "Camera", value: "\(make) \(model)").padding(.bottom, 8)
            }
            
            // Lens info
            if let lensModel = asset.exifInfo?.lensModel {
                TechnicalInfoItem(icon: "camera.viewfinder", label: "Lens", value: lensModel).padding(.bottom, 8)
            }
            
            if let width = asset.exifInfo?.exifImageWidth, let height = asset.exifInfo?.exifImageHeight {
                TechnicalInfoItem(icon: "lines.measurement.horizontal", label: "Image Size", value: "\(round(Double(width * height) / 1_000_000 * 10) / 10)MP • \(width)px ×  \(height)px").padding(.bottom, 8)
            }
            
            HStack{
                // File info
                if let fileSize = asset.exifInfo?.fileSizeInByte {
                    TechnicalInfoItem(icon: "scalemass",  label: "File Size", value: formatFileSize(fileSize))
                }
                
                if let fNumber = asset.exifInfo?.fNumber {
                    TechnicalInfoItem(icon: "camera.aperture", label: "Aperture", value: "f/\(String(format: "%.1f", fNumber))")
                }
                
                if let focalLength = asset.exifInfo?.focalLength {
                    TechnicalInfoItem(icon: "camera.macro.circle", label: "Focal Length", value: "\(Int(focalLength))mm")
                }
                
                if let iso = asset.exifInfo?.iso {
                    TechnicalInfoItem(icon: "dial.high", label: "ISO", value: "\(iso)")
                }
                
                if let exposureTime = asset.exifInfo?.exposureTime {
                    TechnicalInfoItem(icon: "timer", label: "Shutter", value: exposureTime)
                }
            }
        }
        .padding(.horizontal, 150)
        .padding(.top, 30)
        .padding(.bottom, 30)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.6)))
        
    }
    
    
    
    private func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useKB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    private var hasExposureData: Bool {
        asset.exifInfo?.fNumber != nil || 
        asset.exifInfo?.focalLength != nil || 
        asset.exifInfo?.iso != nil || 
        asset.exifInfo?.exposureTime != nil
    }
}

// MARK: - Preview
#Preview {
    let sampleAsset = ImmichAsset(
        id: "sample-1",
        deviceAssetId: "device-1",
        deviceId: "device-1",
        ownerId: "owner-1",
        libraryId: "library-1",
        type: .image,
        originalPath: "/sample/path",
        originalFileName: "sample.jpg",
        originalMimeType: "image/jpeg",
        resized: false,
        thumbhash: nil,
        fileModifiedAt: "2024-01-01T00:00:00Z",
        fileCreatedAt: "2024-01-01T00:00:00Z",
        localDateTime: "2024-01-01T00:00:00Z",
        updatedAt: "2024-01-01T00:00:00Z",
        isFavorite: false,
        isArchived: false,
        isOffline: false,
        isTrashed: false,
        checksum: "sample-checksum",
        duration: nil,
        hasMetadata: true,
        livePhotoVideoId: nil,
        people: [],
        visibility: "VISIBLE",
        duplicateId: nil,
        exifInfo: ExifInfo(
            make: "Apple",
            model: "iPhone 15 Pro",
            imageName: "Golden Gate Bridge",
            exifImageWidth: 4032,
            exifImageHeight: 3024,
            dateTimeOriginal: "2024:07:15 14:30:25",
            modifyDate: "2024:07:15 14:30:25",
            lensModel: "iPhone 15 Pro back triple camera 6.765mm f/1.78",
            fNumber: 1.78,
            focalLength: 6.765,
            iso: 64,
            exposureTime: "1/2000",
            latitude: 37.8199,
            longitude: -122.4783,
            city: "San Francisco",
            state: "California",
            country: "United States",
            timeZone: "America/Los_Angeles",
            description: "Beautiful sunset view of the Golden Gate Bridge",
            fileSizeInByte: 3456000,
            orientation: "1",
            projectionType: nil,
            rating: 5
        )
    )
    
    ZStack {
        SharedGradientBackground()
        
        VStack {
            Spacer()
            ExifInfoOverlay(asset: sampleAsset) {
                print("Dismiss overlay")
            }
        }
    }
}
