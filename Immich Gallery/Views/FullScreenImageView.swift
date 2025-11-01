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
    @ObservedObject var assetService: AssetService
    @ObservedObject var authenticationService: AuthenticationService
    @Binding var currentAssetIndex: Int // Add binding to track current index
    @Environment(\.dismiss) private var dismiss
    @State private var image: UIImage?
    @State private var isLoading = true

    @State private var currentAsset: ImmichAsset
    @State private var showingSwipeHint = false
    @FocusState private var isFocused: Bool
    @State private var refreshToggle = false
    @State private var showingVideoPlayer = false
    @State private var showingExifInfo = false
    
    init(asset: ImmichAsset, assets: [ImmichAsset], currentIndex: Int, assetService: AssetService, authenticationService: AuthenticationService, currentAssetIndex: Binding<Int>) {
        print("FullScreenImageView: Initializing with currentIndex: \(currentIndex)")
        self.asset = asset
        self.assets = assets
        self.currentIndex = currentIndex
        self.assetService = assetService
        self.authenticationService = authenticationService
        self._currentAssetIndex = currentAssetIndex
        self._currentAsset = State(initialValue: asset)
    }
    
    var body: some View {
        ZStack {
            SharedOpaqueBackground()
            
            if currentAsset.type == .video {
                if showingVideoPlayer {
                    // Use simplified video player when user clicks play
                    SimpleVideoPlayerView(asset: currentAsset, assetService: assetService, authenticationService: authenticationService)
                        .id(currentAsset.id)
                } else {
                    // Show video thumbnail with play button overlay
                    VideoThumbnailView(
                        asset: currentAsset,
                        assetService: assetService,
                        onPlayButtonTapped: {
                            showingVideoPlayer = true
                        }
                    )
                }
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
                                    Group {
                                        if !UserDefaults.standard.hideImageOverlay {
                                            VStack {
                                                Spacer()
                                                HStack {
                                                    Spacer()
                                                    LockScreenStyleOverlay(asset: currentAsset)
                                                }
                                            }
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
            
            // EXIF info overlay
            if showingExifInfo {
                VStack {
                    Spacer()
                    ExifInfoOverlay(asset: currentAsset) {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showingExifInfo = false
                        }
                    }
                }
                .transition(.opacity)
            }
            
            // Swipe hint overlay
            if showingSwipeHint && assets.count > 1 {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            HStack(spacing: 50) {
                                HStack(spacing: 5){
                                    Image(systemName: "arrow.left")
                                        .font(.title2)
                                        .foregroundColor(.white.opacity(0.7))
                                    Image(systemName: "arrow.right")
                                        .font(.title2)
                                        .foregroundColor(.white.opacity(0.7))
                                    Text("Swipe to navigate")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.7))
                                }
                                HStack(spacing: 5){
                                    Image(systemName: "arrow.up")
                                        .font(.title2)
                                        .foregroundColor(.white.opacity(0.7))
                                    Image(systemName: "arrow.down")
                                        .font(.title2)
                                        .foregroundColor(.white.opacity(0.7))
                                    Text("Swipe up or down to show/hide details")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.7))
                                   
                                }
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
        .onExitCommand {
            print("FullScreenImageView: Exit command triggered")
            if showingVideoPlayer {
                showingVideoPlayer = false
            } else {
                print("FullScreenImageView: Dismissing fullscreen view")
                dismiss()
            }
        }
        .modifier(ContentAwareModifier(
            isVideo: currentAsset.type == .video,
            currentAssetIndex: currentAssetIndex,
            assets: assets,
            isFocused: $isFocused,
            showingSwipeHint: $showingSwipeHint,
            showingExifInfo: $showingExifInfo,
            onNavigate: navigateToImage,
            onDismiss: { dismiss() },
            onLoadImage: loadFullImage,
            showingVideoPlayer: showingVideoPlayer,
            onPlayButtonTapped: {
                showingVideoPlayer = true
            }
        ))
    }
    
    private func navigateToImage(at index: Int) {
        print("FullScreenImageView: Attempting to navigate to image at index \(index) (total assets: \(assets.count))")
        guard index >= 0 && index < assets.count else {
            print("FullScreenImageView: Navigation failed - index \(index) out of bounds")
            return
        }
        print("FullScreenImageView: Navigating to asset ID: \(assets[index].id)")
        currentAssetIndex = index // This now updates the binding
        print("FullScreenImageView: Updated currentAssetIndex binding to \(index)")
        currentAsset = assets[index]
        refreshToggle.toggle() // Force UI update
        
        // Reset overlay states when navigating
        showingExifInfo = false
        if currentAsset.type == .video {
            showingVideoPlayer = false
        } else {
            image = nil
            isLoading = true
            loadFullImage()
        }
    }
    
    private func loadFullImage() {
        Task {
            do {
                print("Loading full image for asset \(currentAsset.id)")
                let fullImage = try await assetService.loadFullImage(asset: currentAsset)
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
    @Binding var showingExifInfo: Bool
    let onNavigate: (Int) -> Void
    let onDismiss: () -> Void
    let onLoadImage: () -> Void
    let showingVideoPlayer: Bool
    let onPlayButtonTapped: () -> Void
    
    
    func body(content: Content) -> some View {
        if isVideo && showingVideoPlayer {
            // For video players: no focus, no gestures, no interference
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
                .onTapGesture {
                    // Only dismiss on tap for photos, not video thumbnails
                    print("FullScreenImageView: Tap gesture detected - isVideo: \(isVideo)")
                    if isVideo {
                        onPlayButtonTapped()
                    }
                }
                .onChange(of: isFocused) { oldValue, newValue in
                    print("FullScreenImageView focus: \(newValue)")
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
                    case .up:
                        print("FullScreenImageView: Up navigation triggered - toggling EXIF info")
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showingExifInfo.toggle()
                        }
                    case .down:
                        print("FullScreenImageView: Down navigation triggered")
                        if showingExifInfo {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showingExifInfo = false
                            }
                        }
                    @unknown default:
                        print("FullScreenImageView: Unknown direction")
                    }
                }
                .onPlayPauseCommand(perform: {
                    print("Play pause tapped")
                })
                .contentShape(Rectangle())
        }
    }
}

// MARK: - Video Thumbnail View
struct VideoThumbnailView: View {
    let asset: ImmichAsset
    let assetService: AssetService
    let onPlayButtonTapped: () -> Void
    @ObservedObject private var thumbnailCache = ThumbnailCache.shared
    
    @State private var thumbnail: UIImage?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @FocusState private var isFocused: Bool
    
    var body: some View {
        ZStack {
            SharedOpaqueBackground()
            
            if isLoading {
                ProgressView("Loading thumbnail...")
                    .foregroundColor(.white)
                    .scaleEffect(1.5)
            } else if let errorMessage = errorMessage {
                VStack {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 60))
                        .foregroundColor(.orange)
                    Text("Error Loading Video")
                        .font(.title)
                        .foregroundColor(.white)
                    Text(errorMessage)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding()
                    Button("Retry") {
                        loadThumbnailForVideo()
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else if let thumbnail = thumbnail {
                GeometryReader { geometry in
                    ZStack {
                        SharedOpaqueBackground()
                        
                        Image(uiImage: thumbnail)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .overlay(
                                // Play button overlay
                                ZStack {
                                    Circle()
                                        .fill(Color.black.opacity(0.7))
                                        .frame(width: 120, height: 120)
                                    
                                    Image(systemName: "play.fill")
                                        .font(.system(size: 50))
                                        .foregroundColor(.white)
                                        .offset(x: 5) // Slight offset to center the play icon
                                }
                                    .scaleEffect(isFocused ? 1.1 : 1.0)
                                    .animation(.easeInOut(duration: 0.2), value: isFocused)
                            )
                            .overlay(
                                // Lock screen style overlay in bottom right
                                Group {
                                    if !UserDefaults.standard.hideImageOverlay {
                                        VStack {
                                            Spacer()
                                            HStack {
                                                Spacer()
                                                LockScreenStyleOverlay(asset: asset)
                                            }
                                        }
                                    }
                                }
                            )
                    }
                }
                .ignoresSafeArea()
            } else {
                VStack {
                    Image(systemName: "video")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    Text("Failed to load video thumbnail")
                        .foregroundColor(.gray)
                }
            }
        }
        .focusable(true)
        .focused($isFocused)
        .onAppear {
            loadThumbnailForVideo()
        }
        .onTapGesture {
            onPlayButtonTapped()
        }
    }
    
    private func loadThumbnailForVideo() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                print("Loading thumbnail for video asset \(asset.id)")
                let thumbnailImage = try await thumbnailCache.getThumbnail(for: asset.id, size: "preview") {
                    // Load from server if not in cache
                    try await assetService.loadImage(assetId: asset.id, size: "preview")
                }
                await MainActor.run {
                    print("Loaded thumbnail for video asset \(asset.id)")
                    self.thumbnail = thumbnailImage
                    self.isLoading = false
                }
            } catch {
                print("Failed to load thumbnail for video asset \(asset.id): \(error)")
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
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
    let userManager = UserManager()
    let networkService = NetworkService(userManager: userManager)
    let authenticationService = AuthenticationService(networkService: networkService, userManager: userManager)
    let assetService = AssetService(networkService: networkService)
    
    FullScreenImageView(
        asset: sampleAsset,
        assets: sampleAssets,
        currentIndex: 0,
        assetService: assetService,
        authenticationService: authenticationService,
        currentAssetIndex: .constant(0)
    )
}
