//
//  FullScreenImageView.swift
//  Immich Gallery
//
//  Created by mensadi-labs on 2025-06-29.
//

import SwiftUI

struct FullScreenImageView: View {
    let assets: [ImmichAsset]
    @ObservedObject var assetService: AssetService
    @ObservedObject var authenticationService: AuthenticationService
    @Binding var currentAssetIndex: Int // Add binding to track current index
    @Environment(\.dismiss) private var dismiss
    @State private var image: UIImage?
    @State private var isLoading = true
    @State private var imageLoadTask: Task<Void, Never>?
    @State private var isLoadingPreviewImage = false

    @State private var currentAsset: ImmichAsset
    @State private var showingSwipeHint = false
    @FocusState private var isFocused: Bool
    @State private var showingVideoPlayer = false
    @State private var showingExifInfo = false
    @State private var hydratedAssets: [String: ImmichAsset] = [:]
    @State private var failedHydrationAssetIds: Set<String> = []
    @State private var stackAssets: [ImmichAsset] = []
    @State private var loadedStackId: String?
    @State private var showingStackPicker = false
    
    init(asset: ImmichAsset, assets: [ImmichAsset], assetService: AssetService, authenticationService: AuthenticationService, currentAssetIndex: Binding<Int>) {
        self.assets = assets
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

                            if isLoadingPreviewImage {
                                VStack {
                                    HStack {
                                        Spacer()
                                        Text("Loading...")
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 8)
                                            .background(
                                                Capsule()
                                                    .fill(Color.black.opacity(0.65))
                                            )
                                            .padding(.top, 40)
                                            .padding(.trailing, 60)
                                    }
                                    Spacer()
                                }
                                .transition(.opacity)
                            }
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


            if stackAssets.count > 1, !showingStackPicker {
                VStack {
                    HStack {
                        Label(
                            "\(stackAssets.count) in stack  ↓",
                            systemImage: "square.stack.3d.up.fill"
                        )
                        .font(.caption.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(Color.black.opacity(0.65), in: Capsule())
                        Spacer()
                    }
                    Spacer()
                }
                .padding(.top, 40)
                .padding(.trailing, 60)
            }

        }
        .onExitCommand {
            print("FullScreenImageView: Exit command triggered")
            if showingStackPicker {
                showingStackPicker = false
            } else if showingVideoPlayer {
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
            showingStackPicker: $showingStackPicker,
            canShowStackPicker: stackAssets.count > 1,
            onNavigate: navigateToImage,
            onLoadImage: loadDisplayImage,
            showingVideoPlayer: showingVideoPlayer,
            onPlayButtonTapped: {
                showingVideoPlayer = true
            }
        ))
        .overlay {
            if showingStackPicker {
                StackPickerOverlay(
                    assets: stackAssets,
                    selectedAssetId: currentAsset.id,
                    assetService: assetService,
                    onSelect: selectStackAsset
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .task(id: currentAsset.id) {
            await hydrateCurrentAssetIfNeeded()
            await loadStackIfNeeded(for: currentAsset)
        }
        .onAppear {
            // The full-screen viewer is already a modal media experience. Keep the
            // root auto-slideshow from presenting another full-screen cover over it.
            NotificationCenter.default.post(
                name: NSNotification.Name(NotificationNames.pauseInactivityMonitoring),
                object: nil
            )
        }
        .onDisappear {
            NotificationCenter.default.post(
                name: NSNotification.Name(NotificationNames.resumeInactivityMonitoring),
                object: nil
            )
        }
    }
    
    private func navigateToImage(at index: Int) {
        print("FullScreenImageView: Attempting to navigate to image at index \(index) (total assets: \(assets.count))")
        guard assets.indices.contains(index) else {
            print("FullScreenImageView: Navigation failed - index \(index) out of bounds")
            return
        }
        print("FullScreenImageView: Navigating to asset ID: \(assets[index].id)")
        currentAssetIndex = index
        print("FullScreenImageView: Updated currentAssetIndex binding to \(index)")
        stackAssets = []
        loadedStackId = nil
        display(asset: hydratedAssets[assets[index].id] ?? assets[index])
    }

    private func loadStackIfNeeded(for asset: ImmichAsset) async {
        guard let stack = asset.stack, stack.assetCount > 1, loadedStackId != stack.id else { return }

        do {
            let response = try await assetService.fetchStack(stackId: stack.id)
            guard !response.assets.isEmpty else { return }
            await MainActor.run {
                loadedStackId = response.id
                stackAssets = response.assets
                for member in response.assets {
                    // Immich intentionally returns stack: null for assets nested
                    // in a stack response. Preserve the stack-aware primary so
                    // navigating away and back can open the picker again.
                    hydratedAssets[member.id] = member.id == response.primaryAssetId
                        ? asset
                        : member
                }
            }
        } catch {
            print("FullScreenImageView: Failed to load stack \(stack.id): \(error)")
        }
    }

    private func selectStackAsset(_ asset: ImmichAsset) {
        withAnimation(.easeInOut(duration: 0.2)) {
            showingStackPicker = false
        }
        display(asset: hydratedAssets[asset.id] ?? asset)
    }

    private func display(asset: ImmichAsset) {
        imageLoadTask?.cancel()
        currentAsset = asset
        showingExifInfo = false
        showingVideoPlayer = false
        // Retain the current image while the next asset loads. Only an initial
        // presentation should expose the loading indicator.
        isLoading = asset.type == .image && image == nil
        isLoadingPreviewImage = false
        if asset.type == .image {
            loadDisplayImage()
        }
    }

    private func hydrateCurrentAssetIfNeeded() async {
        let assetId = currentAsset.id
        if let hydratedAsset = hydratedAssets[assetId] {
            await MainActor.run {
                if currentAsset.id == assetId {
                    currentAsset = hydratedAsset
                }
            }
            return
        }

        // Search-backed grids (including albums) can include EXIF while omitting
        // the stack relation. Fetch the full asset whenever either relation is
        // missing; GET /assets/{id} includes both and is cached after this call.
        let needsFullAsset = currentAsset.exifInfo == nil || currentAsset.stack == nil
        guard needsFullAsset, !failedHydrationAssetIds.contains(assetId) else { return }

        do {
            let fullAsset = try await assetService.fetchAssetDetails(assetId: assetId)
            await MainActor.run {
                hydratedAssets[assetId] = fullAsset
                if currentAsset.id == assetId {
                    currentAsset = fullAsset
                }
            }
        } catch {
            await MainActor.run {
                _ = failedHydrationAssetIds.insert(assetId)
            }
            print("FullScreenImageView: Failed to load asset details for \(assetId): \(error)")
        }
    }
    
    private func loadDisplayImage() {
        imageLoadTask?.cancel()
        let assetToLoad = currentAsset
        guard assetToLoad.type == .image else { return }

        imageLoadTask = Task {
            do {
                if let cachedThumbnail = await ThumbnailCache.shared.cachedThumbnail(for: assetToLoad.id, size: "thumbnail") {
                    try Task.checkCancellation()
                    await MainActor.run {
                        guard currentAsset.id == assetToLoad.id else { return }
                        print("FullScreenImageView: Showing cached thumbnail while loading preview image for asset \(assetToLoad.id)")
                        self.image = cachedThumbnail
                        self.isLoadingPreviewImage = true
                        self.isLoading = false
                    }
                }

                print("Loading preview image for asset \(assetToLoad.id)")
                let previewImage = try await assetService.loadImage(assetId: assetToLoad.id, size: "preview")
                try Task.checkCancellation()
                await MainActor.run {
                    guard currentAsset.id == assetToLoad.id else { return }
                    if let previewImage {
                        print("FullScreenImageView: Replacing thumbnail with preview image for asset \(assetToLoad.id)")
                        self.image = previewImage
                    } else {
                        print("FullScreenImageView: Preview image unavailable; keeping thumbnail for asset \(assetToLoad.id)")
                    }
                    self.isLoadingPreviewImage = false
                    self.isLoading = false
                }

                do {
                    guard currentAsset.id == assetToLoad.id else { return }
                    print("FullScreenImageView: Loading original image for asset \(assetToLoad.id)")
                    let originalImage = try await assetService.loadFullImage(asset: assetToLoad)
                    try Task.checkCancellation()
                    await MainActor.run {
                        guard currentAsset.id == assetToLoad.id else { return }
                        if let originalImage {
                            print("FullScreenImageView: Replacing preview with original image for asset \(assetToLoad.id)")
                            self.image = originalImage
                        } else {
                            print("FullScreenImageView: Original image unavailable; keeping preview for asset \(assetToLoad.id)")
                        }
                    }
                } catch is CancellationError {
                    throw CancellationError()
                } catch {
                    print("FullScreenImageView: Failed to load original image for asset \(assetToLoad.id); keeping preview: \(error)")
                }
            } catch is CancellationError {
                print("Image loading cancelled for asset \(assetToLoad.id)")
            } catch {
                print("Failed to load display image for asset \(assetToLoad.id): \(error)")
                await MainActor.run {
                    guard currentAsset.id == assetToLoad.id else { return }
                    self.isLoadingPreviewImage = false
                    self.isLoading = false
                }
            }
        }
    }
}

// MARK: - Content Aware Modifier
struct ContentAwareModifier: ViewModifier {
    private enum HorizontalNavigation {
        case previous
        case next
    }

    let isVideo: Bool
    let currentAssetIndex: Int
    let assets: [ImmichAsset]
    @FocusState.Binding var isFocused: Bool
    @Binding var showingSwipeHint: Bool
    @Binding var showingExifInfo: Bool
    @Binding var showingStackPicker: Bool
    let canShowStackPicker: Bool
    let onNavigate: (Int) -> Void
    let onLoadImage: () -> Void
    let showingVideoPlayer: Bool
    let onPlayButtonTapped: () -> Void

    private func horizontalNavigation(for direction: MoveCommandDirection) -> HorizontalNavigation? {
        let reverseHorizontal = UserDefaults.standard.reverseFullscreenHorizontalNavigation

        switch direction {
        case .left:
            return reverseHorizontal ? .next : .previous
        case .right:
            return reverseHorizontal ? .previous : .next
        default:
            return nil
        }
    }

    private func navigatedIndex(for direction: MoveCommandDirection) -> Int? {
        switch horizontalNavigation(for: direction) {
        case .previous:
            return currentAssetIndex - 1
        case .next:
            return currentAssetIndex + 1
        case nil:
            return nil
        }
    }
    
    
    func body(content: Content) -> some View {
        if isVideo && showingVideoPlayer {
            // For video players: no focus, no gestures, no interference
            content
        } else {
            // For images: full navigation support
            content
                .focusable(!showingStackPicker)
                .focused($isFocused)
                .onAppear {
                    if !isVideo {
                        onLoadImage()
                    }
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
                .onChange(of: showingStackPicker) { _, isShowing in
                    // Explicitly hand focus to the stack buttons. Merely making
                    // this view non-focusable does not always resign its existing
                    // focus, which leaves its move handler consuming the remote.
                    isFocused = !isShowing
                }
                .onMoveCommand { direction in
                    guard !showingStackPicker else { return }
                    switch direction {
                    case .left:
                        print("FullScreenImageView: Left navigation triggered (current: \(currentAssetIndex), total: \(assets.count))")
                        if let nextIndex = navigatedIndex(for: direction), assets.indices.contains(nextIndex) {
                            onNavigate(nextIndex)
                        } else {
                            print("FullScreenImageView: No navigable asset for left command")
                        }
                    case .right:
                        print("FullScreenImageView: Right navigation triggered (current: \(currentAssetIndex), total: \(assets.count))")
                        if let nextIndex = navigatedIndex(for: direction), assets.indices.contains(nextIndex) {
                            onNavigate(nextIndex)
                        } else {
                            print("FullScreenImageView: No navigable asset for right command")
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
                        } else if canShowStackPicker {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showingStackPicker = true
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
    // Plain reference, not @ObservedObject: this view only calls into the cache
    // and must not re-render every time the cache's stats publish.
    private let thumbnailCache = ThumbnailCache.shared
    
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
        assetService: assetService,
        authenticationService: authenticationService,
        currentAssetIndex: .constant(0)
    )
}
