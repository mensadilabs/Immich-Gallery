//
//  AssetThumbnailView.swift
//  Immich Gallery
//
//  Created by mensadi-labs on 2025-06-29.
//

import SwiftUI

struct AssetThumbnailView: View {
    let asset: ImmichAsset
    @ObservedObject var assetService: AssetService
    @ObservedObject private var thumbnailCache = ThumbnailCache.shared
    @State private var image: UIImage?
    @State private var isLoading = true
    let isFocused: Bool
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.3))
                .frame(width: 320, height: 320)
            
            if isLoading {
                ProgressView()
                    .scaleEffect(1.2)
            } else if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 320, height: 320)
                    .clipped()
                    .cornerRadius(12)
            } else {
                Image(systemName: "photo")
                    .font(.system(size: 40))
                    .foregroundColor(.gray)
            }
            
            // Video indicator
            if asset.type == .video {
                // Play button at top right
                VStack {
                    HStack {
                        Spacer()
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.white)
                            .background(Color.black.opacity(0.6))
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.5), radius: 5, x: 0, y: 2)
                            .padding(8)
                    }
                    Spacer()
                }
            
            }
            
            // Favorite heart indicator at bottom left
            if asset.isFavorite {
                VStack {
                    Spacer()
                    HStack {
                        Image(systemName: "heart.fill")
                            .font(.caption2)
                            .foregroundColor(.red)
                            .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                            .padding(8)
                        Spacer()
                    }
                }
            }
            // Text overlay at bottom right
            VStack(alignment: .trailing, spacing: 2) {
                Text(DateFormatter.formatSpecificISO8601(asset.exifInfo?.dateTimeOriginal ?? asset.fileCreatedAt, includeTime: false))
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black.opacity(0.4))
            )
            
        }
        .frame(width: 320, height: 320)
        .shadow(color: .black.opacity(isFocused ? 0.5 : 0), radius: 15, y: 10)
        .onAppear {
            loadThumbnail()
        }
    }
    
    private func loadThumbnail() {
        Task {
            do {
                let thumbnail = try await thumbnailCache.getThumbnail(for: asset.id, size: "preview") {
                    // Load from server if not in cache
                    try await assetService.loadImage(asset: asset, size: "preview")
                }
                await MainActor.run {
                    self.image = thumbnail
                    self.isLoading = false
                }
            } catch {
                print("Failed to load thumbnail for asset \(asset.id): \(error)")
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }
    
    
}

#Preview {
    let networkService = NetworkService()
    let assetService = AssetService(networkService: networkService)
    
    // Create a mock asset for preview
    let mockAsset = ImmichAsset(
        id: "mock-id",
        deviceAssetId: "mock-device-id",
        deviceId: "mock-device",
        ownerId: "mock-owner",
        libraryId: nil,
        type: .video,
        originalPath: "/mock/path",
        originalFileName: "mock.jpg",
        originalMimeType: "image/jpeg",
        resized: false,
        thumbhash: nil,
        fileModifiedAt: "2023-01-01 00:00:00",
        fileCreatedAt: "2023-12-25T14:30:00Z",
        localDateTime: "2023-01-01",
        updatedAt: "2023-01-01",
        isFavorite: true,
        isArchived: false,
        isOffline: false,
        isTrashed: false,
        checksum: "mock-checksum",
        duration: nil,
        hasMetadata: false,
        livePhotoVideoId: nil,
        people: [],
        visibility: "public",
        duplicateId: nil,
        exifInfo: nil
    )
    
    AssetThumbnailView(asset: mockAsset, assetService: assetService, isFocused: false)
} 

