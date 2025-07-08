//
//  FullScreenImageView.swift
//  Immich Gallery
//
//  Created by mensadi-labs on 2025-06-29.
//

import SwiftUI

struct FullScreenImageView: View {
    let asset: ImmichAsset
    let assets: [ImmichAsset]
    let currentIndex: Int
    @ObservedObject var immichService: ImmichService
    @Environment(\.dismiss) private var dismiss
    @State private var image: UIImage?
    @State private var isLoading = true

    @State private var currentAssetIndex: Int
    @State private var currentAsset: ImmichAsset
    @State private var showingSwipeHint = false
    @FocusState private var isFocused: Bool
    @State private var refreshToggle = false
    
    init(asset: ImmichAsset, assets: [ImmichAsset], currentIndex: Int, immichService: ImmichService) {
        self.asset = asset
        self.assets = assets
        self.currentIndex = currentIndex
        self.immichService = immichService
        self._currentAssetIndex = State(initialValue: currentIndex)
        self._currentAsset = State(initialValue: asset)
    }
    
    var body: some View {
        ZStack {
            SharedOpaqueBackground()
            
            if currentAsset.type == .video {
                // Use VideoPlayerView for videos
                VideoPlayerView(asset: currentAsset, immichService: immichService)
            } else {
                // Use image view for photos
                if isLoading {
                    ProgressView("Loading...")
                        .foregroundColor(.white)
                        .scaleEffect(1.5)
                } else if let image = image {
                    GeometryReader { geometry in
                        ZStack {
                            SharedOpaqueBackground()
                            
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .overlay(
                                    // Lock screen style overlay in bottom right
                                    VStack {
                                        Spacer()
                                        HStack {
                                            Spacer()
                                            LockScreenStyleOverlay(asset: currentAsset)
                                        }
                                    }
                                )
                        }
                    }
                    .ignoresSafeArea()
                } else {
                    VStack {
                        Image(systemName: "photo")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        Text("Failed to load image")
                            .foregroundColor(.gray)
                    }
                }
            }
            
            // Swipe hint overlay
            if showingSwipeHint && assets.count > 1 {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            HStack(spacing: 20) {
                                Image(systemName: "arrow.left")
                                    .font(.title2)
                                    .foregroundColor(.white.opacity(0.7))
                                Text("Swipe to navigate")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.7))
                                Image(systemName: "arrow.right")
                                    .font(.title2)
                                    .foregroundColor(.white.opacity(0.7))
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(20)
                        }
                        Spacer()
                    }
                    .padding(.bottom, 100)
                }
                .transition(.opacity)
            }
        }
        .id(refreshToggle)
        .modifier(ContentAwareModifier(
            isVideo: currentAsset.type == .video,
            currentAssetIndex: currentAssetIndex,
            assets: assets,
            isFocused: $isFocused,
            showingSwipeHint: $showingSwipeHint,
            onNavigate: navigateToImage,
            onDismiss: { dismiss() },
            onLoadImage: loadFullImage
        ))
    }
    
    private func navigateToImage(at index: Int) {
        print("FullScreenImageView: Attempting to navigate to image at index \(index) (total assets: \(assets.count))")
        guard index >= 0 && index < assets.count else {
            print("FullScreenImageView: Navigation failed - index \(index) out of bounds")
            return
        }
        print("FullScreenImageView: Navigating to asset ID: \(assets[index].id)")
        currentAssetIndex = index
        currentAsset = assets[index]
        refreshToggle.toggle() // Force UI update
        if currentAsset.type != .video {
            image = nil
            isLoading = true
            loadFullImage()
        }
    }
    
    private func loadFullImage() {
        Task {
            do {
                print("Loading full image for asset \(currentAsset.id)")
                let fullImage = try await immichService.loadFullImage(from: currentAsset)
                await MainActor.run {
                    print("Loaded image for asset \(currentAsset.id)")
                    self.image = fullImage
                    self.isLoading = false
                }
            } catch {
                print("Failed to load full image for asset \(currentAsset.id): \(error)")
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }
}

// MARK: - Content Aware Modifier
struct ContentAwareModifier: ViewModifier {
    let isVideo: Bool
    let currentAssetIndex: Int
    let assets: [ImmichAsset]
    @FocusState.Binding var isFocused: Bool
    @Binding var showingSwipeHint: Bool
    let onNavigate: (Int) -> Void
    let onDismiss: () -> Void
    let onLoadImage: () -> Void
    
    func body(content: Content) -> some View {
        if isVideo {
            // For videos: no focus, no gestures, no interference
            content
        } else {
            // For images: full navigation support
            content
                .focusable(true)
                .focused($isFocused)
                .onAppear {
                    onLoadImage()
                    if assets.count > 1 {
                        showingSwipeHint = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            withAnimation(.easeOut(duration: 0.5)) {
                                showingSwipeHint = false
                            }
                        }
                    }
                    isFocused = true
                }
                .onChange(of: isFocused) { focused in
                    print("FullScreenImageView focus: \(focused)")
                }
                .onMoveCommand { direction in
                    switch direction {
                    case .left:
                        print("FullScreenImageView: Left navigation triggered (current: \(currentAssetIndex), total: \(assets.count))")
                        if currentAssetIndex > 0 {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                onNavigate(currentAssetIndex - 1)
                            }
                        } else {
                            print("FullScreenImageView: Already at first photo, cannot navigate further")
                        }
                    case .right:
                        print("FullScreenImageView: Right navigation triggered (current: \(currentAssetIndex), total: \(assets.count))")
                        if currentAssetIndex < assets.count - 1 {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                onNavigate(currentAssetIndex + 1)
                            }
                        } else {
                            print("FullScreenImageView: Already at last photo, cannot navigate further")
                        }
                    case .up, .down:
                        // Ignore up/down swipes
                        break
                    @unknown default:
                        print("FullScreenImageView: Unknown direction")
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    onDismiss()
                }
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
            model: "iPhone 15",
            imageName: "Sample Image",
            exifImageWidth: 1080,
            exifImageHeight: 1920,
            dateTimeOriginal: "2024-01-01T00:00:00Z",
            modifyDate: "2024-01-01T00:00:00Z",
            lensModel: "iPhone 15 back camera",
            fNumber: 1.8,
            focalLength: 26.0,
            iso: 100,
            exposureTime: "1/60",
            latitude: 37.7749,
            longitude: -122.4194,
            city: "San Francisco",
            state: "CA",
            country: "USA",
            timeZone: "America/Los_Angeles",
            description: "Sample image for preview",
            fileSizeInByte: 1024000,
            orientation: "1",
            projectionType: nil,
            rating: 5
        )
    )
    
    let sampleAssets = [
        sampleAsset,
        ImmichAsset(
            id: "sample-2",
            deviceAssetId: "device-2",
            deviceId: "device-2",
            ownerId: "owner-1",
            libraryId: "library-1",
            type: .image,
            originalPath: "/sample/path2",
            originalFileName: "sample2.jpg",
            originalMimeType: "image/jpeg",
            resized: false,
            thumbhash: nil,
            fileModifiedAt: "2024-01-02T00:00:00Z",
            fileCreatedAt: "2024-01-02T00:00:00Z",
            localDateTime: "2024-01-02T00:00:00Z",
            updatedAt: "2024-01-02T00:00:00Z",
            isFavorite: true,
            isArchived: false,
            isOffline: false,
            isTrashed: false,
            checksum: "sample-checksum-2",
            duration: nil,
            hasMetadata: true,
            livePhotoVideoId: nil,
            people: [],
            visibility: "VISIBLE",
            duplicateId: nil,
            exifInfo: nil
        )
    ]
    
    // Use the shared mock service
    let mockService = MockImmichService()
    
    return FullScreenImageView(
        asset: sampleAsset,
        assets: sampleAssets,
        currentIndex: 0,
        immichService: mockService
    )
}
