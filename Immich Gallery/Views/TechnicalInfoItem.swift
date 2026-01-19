//
//  TechnicalInfoItem.swift
//  Immich Gallery
//
//  Created by mensadi-labs on 2025-07-25.
//

import SwiftUI

struct TechnicalInfoItem: View {
    let icon: String
    let label: String
    let value: String
    
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 20) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                
                
                Text(label)
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.6))
            }.frame(width: 180, alignment: .leading)
            
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.white)
        }
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
        Color.white.ignoresSafeArea()
        
        VStack {
            Spacer()
            ExifInfoOverlay(asset: sampleAsset) {
                print("Dismiss overlay")
            }
        }
    }
}
