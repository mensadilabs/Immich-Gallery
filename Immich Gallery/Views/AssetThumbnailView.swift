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
    @State private var image: UIImage?
    @State private var placeholder: UIImage?   // instant blur from thumbhash
    @State private var loadingTask: Task<Void, Never>?
    let isFocused: Bool
    var shouldLoadThumbnail = true
    var allowsThumbhashPlaceholder = true
    var showsDateOverlay = true
    var showsStackIndicator = true
    var thumbnailSize: CGFloat = 320
    var thumbnailLoadDelayNanoseconds: UInt64 = 150_000_000
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
        
             RoundedRectangle(cornerRadius: 12)
                 .fill(Color.gray.opacity(0.3))
                 .frame(width: thumbnailSize, height: thumbnailSize)

             // Instant placeholder decoded from the asset's thumbhash. Shows
             // immediately (no network) and sits behind the real thumbnail,
             // which crossfades in on top once loaded.
             if let placeholder = placeholder {
                 Image(uiImage: placeholder)
                     .resizable()
                     .aspectRatio(contentMode: .fill)
                     .frame(width: thumbnailSize, height: thumbnailSize)
                     .clipped()
                     .cornerRadius(12)
             }

             if let image = image {
                 Image(uiImage: image)
                     .resizable()
                     .aspectRatio(contentMode: .fill)
                     .frame(width: thumbnailSize, height: thumbnailSize)
                     .clipped()
                     .cornerRadius(12)
                     .transition(.opacity)
             } else if placeholder == nil {
                 Image(systemName: "icloud")
                     .font(.system(size: 32))
                     .foregroundColor(.white.opacity(0.35))
                     .frame(width: thumbnailSize, height: thumbnailSize, alignment: .center)
             }
            
            // Video indicator
            if asset.type == .video {
                // Play button at top right
                VStack {
                    HStack(spacing: 8) {
                        Spacer()
                        if let duration = asset.displayDuration {
                            Text(duration)
                                .font(.caption.bold().monospacedDigit())
                                .foregroundColor(.white)
                                .padding(.horizontal, 9)
                                .padding(.vertical, 6)
                                .background(Color.black.opacity(0.65), in: Capsule())
                        }
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


            // Stack indicator. The primary asset represents the hidden members
            // in grids, so keep the count visible without obscuring the photo.
            if showsStackIndicator, let stack = asset.stack, stack.assetCount > 1 {
                VStack {
                    HStack {
                        Label("\(stack.assetCount)", systemImage: "square.stack.3d.up.fill")
                            .font(.caption.bold())
                            .foregroundColor(.white)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 6)
                            .background(Color.black.opacity(0.65), in: Capsule())
                            .padding(10)
                        Spacer()
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
            if showsDateOverlay {
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
            
        }
        .frame(width: thumbnailSize, height: thumbnailSize)
        .shadow(color: .black.opacity(isFocused ? 0.5 : 0), radius: 15, y: 10)
        .onAppear {
            if allowsThumbhashPlaceholder && placeholder == nil {
                placeholder = ThumbHash.image(fromBase64: asset.thumbhash)
            }
            if shouldLoadThumbnail {
                loadThumbnail()
            }
        }
        .onDisappear {
            // Re-enabled: cancelling loads for tiles scrolled off-screen is what
            // keeps fast scroll from piling up hundreds of in-flight loads.
            cancelLoading()
        }
        .onChange(of: shouldLoadThumbnail) { _, canLoad in
            if canLoad {
                if image == nil {
                    loadThumbnail()
                }
            } else {
                cancelLoading()
            }
        }
    }

    private func loadThumbnail() {
        // Cancel any existing loading task
        loadingTask?.cancel()

        loadingTask = Task {
            // Debounce: a tile that scroll/focus blows past is cancelled in
            // onDisappear before this fires, so we never load tiles the user
            // is racing past.
            if thumbnailLoadDelayNanoseconds > 0 {
                try? await Task.sleep(nanoseconds: thumbnailLoadDelayNanoseconds)
            }
            if Task.isCancelled { return }

            // Hard concurrency cap: even if SwiftUI's nested lazy grids
            // instantiate far more tiles than are visible, at most a handful
            // of loads/decodes run at once, so memory can't spike into a crash.
            await ThumbnailLoadGate.shared.acquire()
            do {
                try Task.checkCancellation()

                let thumbnail = try await ThumbnailCache.shared.getThumbnail(for: asset.id, size: "thumbnail") {
                    // Check cancellation before network request
                    try Task.checkCancellation()
                    // Load from server if not in cache
                    return try await assetService.loadImage(assetId: asset.id, size: "thumbnail")
                }

                // Check cancellation before UI update
                try Task.checkCancellation()

                await MainActor.run {
                    withAnimation(.easeOut(duration: 0.2)) {
                        self.image = thumbnail
                    }
                }
            } catch is CancellationError {
                // Task was cancelled - don't update UI or log error
            } catch {
                print("Failed to load thumbnail for asset \(asset.id): \(error)")
            }
            // Always release the slot, including on cancellation/error paths.
            await ThumbnailLoadGate.shared.release()
        }
    }
    
    private func cancelLoading() {
        loadingTask?.cancel()
        loadingTask = nil
    }
    
    
}

#Preview {
    let userManager = UserManager()
    let networkService = NetworkService(userManager: userManager)
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
