//
//  SlideshowView.swift
//  Immich Gallery
//
//  Created by mensadi-labs on 2025-06-29.
//

import SwiftUI
import UIKit

struct SlideshowView: View {
    let albumId: String?
    let personId: String?
    let tagId: String?
    let startingIndex: Int
    @Environment(\.dismiss) private var dismiss

    // Services created internally
    private let assetService: AssetService
    private let albumService: AlbumService?
    
    // Asset provider created using factory
    private let assetProvider: AssetProvider

    init(albumId: String?, personId: String?, tagId: String?, startingIndex: Int) {
        self.albumId = albumId
        self.personId = personId
        self.tagId = tagId
        self.startingIndex = startingIndex

        // Create services internally
        let userManager = UserManager()
        let networkService = NetworkService(userManager: userManager)
        self.assetService = AssetService(networkService: networkService)
        self.albumService = albumId != nil ? AlbumService(networkService: networkService) : nil

        // Create appropriate asset provider using factory
        self.assetProvider = AssetProviderFactory.createProvider(
            albumId: albumId,
            personId: personId,
            tagId: tagId,
            isAllPhotos: false, // Slideshow doesn't use "All Photos" mode
            assetService: assetService,
            albumService: albumService
        )
    }

    // Image Queue System
    @State private var imageQueue: [(asset: ImmichAsset, image: UIImage, dominantColor: Color?)] = []
    @State private var assetQueue: [ImmichAsset] = []
    @State private var currentImageData: (asset: ImmichAsset, image: UIImage, dominantColor: Color?)?
    @State private var isLoading = true
    @State private var slideInterval: TimeInterval = UserDefaults.standard.slideshowInterval
    @State private var autoAdvanceTimer: Timer?
    @State private var isTransitioning = false
    @State private var slideDirection: SlideDirection = .right
    @State private var dominantColor: Color = getBackgroundColor(UserDefaults.standard.slideshowBackgroundColor)
    @State private var isLoadingAssets = false
    @State private var hasMoreAssets = true
    @State private var currentPage = 1
    @State private var loadAssetsTask: Task<Void, Never>?
    @State private var slideshowBackgroundColor: String = UserDefaults.standard.slideshowBackgroundColor
    @State private var hideImageOverlay: Bool = UserDefaults.standard.hideImageOverlay
    @State private var enableReflectionsInSlideshow: Bool = UserDefaults.standard.enableReflectionsInSlideshow
    @State private var enableKenBurnsEffect: Bool = UserDefaults.standard.enableKenBurnsEffect
    @State private var dimensionMultiplier:Double = UserDefaults.standard.enableReflectionsInSlideshow ?  0.9 : 1.0
    @State private var kenBurnsScale: CGFloat = 1.0
    @State private var kenBurnsOffset: CGSize = .zero
    @State private var enableShuffle: Bool = UserDefaults.standard.enableSlideshowShuffle
    @State private var isSharedAlbum: Bool = false
    @FocusState private var isFocused: Bool
    
    /// Computed property to get current Art Mode level from UserDefaults
    private var currentArtModeLevel: ArtModeLevel {
        let levelString = UserDefaults.standard.artModeLevel
        return ArtModeLevel(rawValue: levelString) ?? .off
    }

    enum SlideDirection {
        case left, right, up, down, diagonal_up_left, diagonal_up_right, diagonal_down_left, diagonal_down_right, zoom_out

        func offset(for size: CGSize) -> CGSize {
            let w = size.width * 1.2
            let h = size.height * 1.2
            switch self {
            case .left: return CGSize(width: -w, height: 0)
            case .right: return CGSize(width: w, height: 0)
            case .up: return CGSize(width: 0, height: -h)
            case .down: return CGSize(width: 0, height: h)
            case .diagonal_up_left: return CGSize(width: -w, height: -h)
            case .diagonal_up_right: return CGSize(width: w, height: -h)
            case .diagonal_down_left: return CGSize(width: -w, height: h)
            case .diagonal_down_right: return CGSize(width: w, height: h)
            case .zoom_out: return CGSize.zero
            }
        }

        var scale: CGFloat {
            switch self {
            case .zoom_out: return 0.1 // Scale down to nearly invisible
            default: return 1.0 // Normal scale
            }
        }

        var opacity: Double {
            switch self {
            case .zoom_out: return 0.0 // Fade out
            default: return 1.0 // Normal opacity
            }
        }
    }

    // Global slide animation duration for both slide-in and slide-out
    private let slideAnimationDuration: Double = 1.5

    // Computed property to get current asset
    private var currentAsset: ImmichAsset? {
        currentImageData?.asset
    }

    var body: some View {
        ZStack {
            // Use dominant color if available, otherwise fall back to user setting, and animate changes
            (slideshowBackgroundColor == "auto" ? dominantColor : getBackgroundColor(slideshowBackgroundColor))
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.6), value: dominantColor)

            if currentImageData == nil && !isLoading {
                VStack {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    Text("No images to display")
                        .font(.title)
                        .foregroundColor(.white)
                }
            } else {
                // Main image display
                if isLoading {
                    ProgressView("Loading...")
                        .foregroundColor(.white)
                        .scaleEffect(1.5)
                } else if let imageData = currentImageData {
                    GeometryReader { geometry in
                        let imageWidth = geometry.size.width * dimensionMultiplier
                        let imageHeight = geometry.size.height * dimensionMultiplier

                        VStack(spacing: 0) {
                            // Main image with performance optimizations
                            Image(uiImage: imageData.image)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: imageWidth, height: imageHeight)
                                .drawingGroup() // Enable hardware acceleration for smooth animations
                                .offset(isTransitioning ? slideDirection.offset(for: geometry.size) : kenBurnsOffset)
                                .scaleEffect(isTransitioning ? slideDirection.scale : kenBurnsScale)
                                .opacity(isTransitioning ? slideDirection.opacity : 1.0)
                                .animation(.easeInOut(duration: slideAnimationDuration), value: isTransitioning)
                                .animation(.linear(duration: slideInterval), value: kenBurnsScale)
                                .animation(.linear(duration: slideInterval), value: kenBurnsOffset)
                                .overlay(
                                    Group {
                                        if !hideImageOverlay {
                                            // Calculate actual image display size within the frame
                                            GeometryReader { imageGeometry in
                                                let actualImageSize = calculateActualImageSize(
                                                    imageSize: CGSize(width: imageData.image.size.width, height: imageData.image.size.height),
                                                    containerSize: CGSize(width: imageWidth, height: imageHeight)
                                                )
                                                let screenWidth = geometry.size.width
                                                let isSmallWidth = actualImageSize.width < (screenWidth / 2)

                                                if isSmallWidth {
                                                    // For small images, show overlay outside (original behavior)
                                                    VStack {
                                                        HStack {
                                                            Spacer()
                                                            LockScreenStyleOverlay(asset: imageData.asset, isSlideshowMode: true)
                                                                .opacity(isTransitioning ? 0.0 : 1.0)
                                                                .animation(.easeInOut(duration: slideAnimationDuration), value: isTransitioning)
                                                        }
                                                    }
                                                } else {
                                                    // For larger images, constrain overlay inside image
                                                    let xOffset = (imageWidth - actualImageSize.width) / 2
                                                    let yOffset = (imageHeight - actualImageSize.height) / 2

                                                    VStack {
                                                        Spacer()
                                                        HStack {
                                                            Spacer()
                                                            LockScreenStyleOverlay(asset: imageData.asset, isSlideshowMode: true)
                                                                .opacity(isTransitioning ? 0.0 : 1.0)
                                                                .animation(.easeInOut(duration: slideAnimationDuration), value: isTransitioning)
                                                                .padding(.trailing, 20)
                                                                .padding(.bottom, 20)
                                                        }
                                                    }
                                                    .frame(width: actualImageSize.width, height: actualImageSize.height)
                                                    .offset(x: xOffset, y: yOffset)
                                                }
                                            }
                                        }
                                    }
                                )
                                .overlay(
                                    // Art Mode overlay
                                    ArtModeOverlay(level: currentArtModeLevel)
                                )

                            // Reflection with performance optimizations
                            if enableReflectionsInSlideshow {
                                Image(uiImage: imageData.image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .scaleEffect(y: -1)
                                    .frame(width: imageWidth, height: imageHeight)
                                    .offset(y: -imageHeight * 0.0)
                                    .clipped()
                                    .mask(
                                        ZStack {
                                            // Base gradient mask for reflection fade
                                            LinearGradient(
                                                colors: [.black.opacity(0.9), .clear],
                                                startPoint: .top,
                                                endPoint: .center
                                            )

                                            // When Ken Burns is active, add mask to prevent overlap with main image
                                            if enableKenBurnsEffect {
                                                Rectangle()
                                                    .fill(.clear)
                                                    .background(
                                                        Rectangle()
                                                            .fill(.black)
                                                            .scaleEffect(isTransitioning ? slideDirection.scale : kenBurnsScale)
                                                            .offset(
                                                                x: -(isTransitioning ? slideDirection.offset(for: geometry.size).width : kenBurnsOffset.width),
                                                                y: -(isTransitioning ? slideDirection.offset(for: geometry.size).height : kenBurnsOffset.height) - imageHeight
                                                            )
                                                            .blendMode(.destinationOut)
                                                    )
                                            }
                                        }
                                        .compositingGroup()
                                    )
                                    .opacity(0.4)
                                    .drawingGroup() // Enable hardware acceleration for reflection
                                    .offset(isTransitioning ? slideDirection.offset(for: geometry.size) : kenBurnsOffset)
                                    .scaleEffect(isTransitioning ? slideDirection.scale : kenBurnsScale)
                                    .opacity(isTransitioning ? slideDirection.opacity * 0.4 : 0.4)
                                    .animation(.easeInOut(duration: slideAnimationDuration), value: isTransitioning)
                                    .animation(.linear(duration: slideInterval), value: kenBurnsScale)
                                    .animation(.linear(duration: slideInterval), value: kenBurnsOffset)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        }
        .focusable(true)
        .focused($isFocused)
        .onAppear {
            isFocused = true

            // Prevent display from sleeping during slideshow
            UIApplication.shared.isIdleTimerDisabled = true
            print("SlideshowView: Display sleep disabled")

            // Initialize slideshow (this will handle shared album detection)
            initializeSlideshow()
        }
        .onDisappear {
            cleanup()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            // Re-enable display sleep when app goes to background
            UIApplication.shared.isIdleTimerDisabled = false
            print("SlideshowView: Display sleep re-enabled (app backgrounded)")
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            // Re-disable display sleep when app becomes active again (if slideshow is still running)
            UIApplication.shared.isIdleTimerDisabled = true
            print("SlideshowView: Display sleep disabled (app foregrounded)")
        }
        .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)) { _ in
            // Update all settings if they changed
            slideInterval = UserDefaults.standard.slideshowInterval

            let newBackgroundColor = UserDefaults.standard.slideshowBackgroundColor
            let previousBackgroundColor = slideshowBackgroundColor
            slideshowBackgroundColor = newBackgroundColor

            hideImageOverlay = UserDefaults.standard.hideImageOverlay
            enableReflectionsInSlideshow = UserDefaults.standard.enableReflectionsInSlideshow
            enableKenBurnsEffect = UserDefaults.standard.enableKenBurnsEffect

            // Update dominant color if background color setting changed to/from auto
            if newBackgroundColor != previousBackgroundColor {
                if newBackgroundColor == "auto", let imageData = currentImageData {
                    if let cachedColor = imageData.dominantColor {
                        dominantColor = cachedColor
                    } else {
                        Task {
                            let color = await ImageColorExtractor.extractDominantColorAsync(from: imageData.image)
                            await MainActor.run {
                                self.dominantColor = color
                            }
                        }
                    }
                } else if newBackgroundColor != "auto" {
                    dominantColor = getBackgroundColor(newBackgroundColor)
                }
            }
        }
        .onTapGesture {
            // Re-enable display sleep before dismissing
            UIApplication.shared.isIdleTimerDisabled = false
            print("SlideshowView: Display sleep re-enabled (tap dismiss)")
            dismiss()
        }
    }
    // MARK: - New Queue-Based Functions

    private func initializeSlideshow() {
        loadAssetsTask = Task {
            await checkIfAlbumIsShared()
            await loadInitialAssets()
            await loadInitialImages()
            await showFirstImage()
        }
    }

    private func checkIfAlbumIsShared() async {
        guard let albumId = albumId, let albumService = albumService else { return }
        
        do {
            let album = try await albumService.getAlbumInfo(albumId: albumId, withoutAssets: true)
            print("SlideshowView: Album info - shared: \(album.shared)")
            await MainActor.run {
                self.isSharedAlbum = album.shared
            }
        } catch {
            print("SlideshowView: Failed to get album info: \(error)")
            await MainActor.run {
                self.isSharedAlbum = false
            }
        }
    }

    private func cleanup() {
        // Cancel any ongoing tasks first
        loadAssetsTask?.cancel()
        loadAssetsTask = nil

        stopAutoAdvance()

        // Clear all image data to free memory
        currentImageData = nil
        imageQueue.removeAll()
        assetQueue.removeAll()

        // Re-enable display sleep when slideshow ends
        UIApplication.shared.isIdleTimerDisabled = false
        print("SlideshowView: Display sleep re-enabled")

        // Restart auto-slideshow timer when slideshow ends
        NotificationCenter.default.post(name: NSNotification.Name("restartAutoSlideshowTimer"), object: nil)
    }

    private func loadInitialAssets() async {
        guard !Task.isCancelled else { return }

        do {
            let searchResult: SearchResult
            if enableShuffle && !isSharedAlbum {
                // Use random assets for non-shared albums when shuffle is enabled
                searchResult = try await assetProvider.fetchRandomAssets(limit: 100)
            } else {
                // Use regular asset fetching for shared albums or when shuffle is disabled
                searchResult = try await assetProvider.fetchAssets(
                    page: currentPage,
                    limit: 100
                )
            }

            await MainActor.run {
                let imageAssets = searchResult.assets.filter { $0.type == .image }
                // Handle starting index - drop assets before the starting point\n
                let actualStartingIndex = min(startingIndex, max(0, imageAssets.count - 1))
                self.assetQueue = Array(imageAssets.dropFirst(actualStartingIndex))
                self.hasMoreAssets = searchResult.nextPage != nil || (enableShuffle && !isSharedAlbum)
                print("SlideshowView: Loaded \(imageAssets.count) assets, starting at index \(startingIndex)")
            }
        } catch {
            await MainActor.run {
                print("SlideshowView: Failed to load initial assets: \(error)")
                self.isLoading = false
            }
        }
    }

    private func loadInitialImages() async {
        guard !assetQueue.isEmpty else {
            await MainActor.run {
                self.isLoading = false
            }
            return
        }

        // Load first 2-3 images
        let imagesToLoad = min(3, assetQueue.count)
        for i in 0..<imagesToLoad {
            guard i < assetQueue.count else { break }
            await loadImageIntoQueue(asset: assetQueue[i])
        }

        // Remove loaded assets from asset queue
        await MainActor.run {
            self.assetQueue.removeFirst(min(imagesToLoad, self.assetQueue.count))
        }
    }

    private func loadImageIntoQueue(asset: ImmichAsset) async {
        guard !Task.isCancelled else { return }

        do {
            guard let image = try await assetService.loadFullImage(asset: asset) else {
                print("SlideshowView: loadFullImage returned nil for asset \(asset.id)")
                return
            }

            let dominantColor = slideshowBackgroundColor == "auto" ?
                await ImageColorExtractor.extractDominantColorAsync(from: image) : nil

            await MainActor.run {
                self.imageQueue.append((asset: asset, image: image, dominantColor: dominantColor))
                print("SlideshowView: Loaded image for asset \(asset.id) into queue")
            }
        } catch {
            print("SlideshowView: Failed to load image for asset \(asset.id): \(error)")
        }
    }

    private func showFirstImage() async {
        await MainActor.run {
            guard !self.imageQueue.isEmpty else {
                self.isLoading = false
                return
            }

            // Move first image from queue to current
            guard !self.imageQueue.isEmpty else {
                print("SlideshowView: No images in queue to show")
                self.isLoading = false
                return
            }
            self.currentImageData = self.imageQueue.removeFirst()
            self.isLoading = false

            // Set dominant color if available
            if let dominantColor = self.currentImageData?.dominantColor,
               self.slideshowBackgroundColor == "auto" {
                self.dominantColor = dominantColor
            }

            // Start Ken Burns effect
            self.startKenBurnsEffect()

            // Start slideshow timer
            self.startAutoAdvance()

            // Preload more images if needed
            Task {
                await self.maintainImageQueue()
            }
        }
    }

    private func maintainImageQueue() async {
        // If we have fewer than 2 images in queue, load more
        await MainActor.run {
            if self.imageQueue.count < 2 {
                Task {
                    await self.loadMoreImagesIfNeeded()
                }
            }
        }
    }

    private func loadMoreImagesIfNeeded() async {
        let shouldLoadAssets = await MainActor.run {
            return self.assetQueue.count <= 2 && self.hasMoreAssets && !self.isLoadingAssets
        }

        if shouldLoadAssets {
            await loadMoreAssets()
        }

        // Load images from asset queue
        let assetsToLoad = await MainActor.run {
            return Array(self.assetQueue.prefix(min(2, self.assetQueue.count)))
        }

        for asset in assetsToLoad {
            await loadImageIntoQueue(asset: asset)
        }

        await MainActor.run {
            self.assetQueue.removeFirst(min(assetsToLoad.count, self.assetQueue.count))
        }
    }

    private func nextImage() {
        print("SlideshowView: nextImage() called")

        // Check if we have next image ready
        guard !imageQueue.isEmpty else {
            print("SlideshowView: No more images in queue")
            return
        }

        print("SlideshowView: Starting slide out animation")
        // Start slide out animation
        withAnimation(.easeInOut(duration: slideAnimationDuration)) {
            isTransitioning = true
        }

        // Wait for slide out to complete, then change image
        DispatchQueue.main.asyncAfter(deadline: .now() + slideAnimationDuration) {
            // Discard current image to free memory
            self.currentImageData = nil

            // Move next image from queue to current
            guard !self.imageQueue.isEmpty else {
                print("SlideshowView: No more images in queue to advance")
                return
            }
            self.currentImageData = self.imageQueue.removeFirst()

            // Set dominant color if available
            if let dominantColor = self.currentImageData?.dominantColor,
               self.slideshowBackgroundColor == "auto" {
                self.dominantColor = dominantColor
            }

            // Set new slide direction for the incoming image
            let directions: [SlideDirection] = [.left, .right, .up, .down, .diagonal_up_left, .diagonal_up_right, .diagonal_down_left, .diagonal_down_right, .zoom_out]
            self.slideDirection = directions.randomElement() ?? .right

            // Ensure slide-in animation plays
            withAnimation(.easeInOut(duration: self.slideAnimationDuration)) {
                self.isTransitioning = false
            }

            // Start Ken Burns effect
            self.startKenBurnsEffect()

            // Start timer for next image
            self.startAutoAdvance()

            // Maintain image queue
            Task {
                await self.maintainImageQueue()
            }

            print("SlideshowView: Advanced to next image, queue size: \(self.imageQueue.count)")
        }
    }

    private func startAutoAdvance() {
        stopAutoAdvance()
        // Start a one-shot timer after the image is loaded and visible
        autoAdvanceTimer = Timer.scheduledTimer(withTimeInterval: slideInterval, repeats: false) { _ in
            print("SlideshowView: Timer fired - queue size: \(self.imageQueue.count)")
            self.nextImage()
        }
    }

    private func stopAutoAdvance() {
        autoAdvanceTimer?.invalidate()
        autoAdvanceTimer = nil
    }


    private func calculateActualImageSize(imageSize: CGSize, containerSize: CGSize) -> CGSize {
        let imageAspectRatio = imageSize.width / imageSize.height
        let containerAspectRatio = containerSize.width / containerSize.height

        if imageAspectRatio > containerAspectRatio {
            // Image is wider than container - width will be constrained
            let actualWidth = containerSize.width
            let actualHeight = actualWidth / imageAspectRatio
            return CGSize(width: actualWidth, height: actualHeight)
        } else {
            // Image is taller than container - height will be constrained
            let actualHeight = containerSize.height
            let actualWidth = actualHeight * imageAspectRatio
            return CGSize(width: actualWidth, height: actualHeight)
        }
    }


    private func startKenBurnsEffect() {
        guard enableKenBurnsEffect else {
            // Reset to default values if Ken Burns is disabled
            kenBurnsScale = 1.0
            kenBurnsOffset = .zero
            return
        }

        // Generate random Ken Burns parameters
        let zoomDirections = [true, false] // true = zoom in, false = zoom out
        let shouldZoomIn = zoomDirections.randomElement() ?? true

        let startScale: CGFloat = shouldZoomIn ? 1.0 : 1.2
        let endScale: CGFloat = shouldZoomIn ? 1.2 : 1.0

        // Random pan direction
        let maxOffset: CGFloat = 20
        let startOffset = CGSize(
            width: CGFloat.random(in: -maxOffset...maxOffset),
            height: CGFloat.random(in: -maxOffset...maxOffset)
        )
        let endOffset = CGSize(
            width: CGFloat.random(in: -maxOffset...maxOffset),
            height: CGFloat.random(in: -maxOffset...maxOffset)
        )

        // Set initial values
        kenBurnsScale = startScale
        kenBurnsOffset = startOffset

        // Animate to end values over the slide duration
        withAnimation(.linear(duration: slideInterval)) {
            kenBurnsScale = endScale
            kenBurnsOffset = endOffset
        }
    }


    private func loadMoreAssets() async {
        // Prevent multiple simultaneous loads
        let shouldLoad = await MainActor.run {
            guard !self.isLoadingAssets && self.hasMoreAssets else {
                print("SlideshowView: Skipping asset load - already loading or no more assets")
                return false
            }
            self.isLoadingAssets = true
            return true
        }

        guard shouldLoad else { return }

        do {
            let searchResult: SearchResult
            if enableShuffle && !isSharedAlbum {
                // Use random assets for non-shared albums when shuffle is enabled
                searchResult = try await assetProvider.fetchRandomAssets(limit: 100)
            } else {
                await MainActor.run {
                    self.currentPage += 1
                }
                // Use regular asset fetching for shared albums or when shuffle is disabled
                searchResult = try await assetProvider.fetchAssets(
                    page: currentPage,
                    limit: 100
                )
            }

            await MainActor.run {
                let imageAssets = searchResult.assets.filter { $0.type == .image }
                self.assetQueue.append(contentsOf: imageAssets)
                self.hasMoreAssets = searchResult.nextPage != nil || (enableShuffle && !isSharedAlbum)
                self.isLoadingAssets = false
                print("SlideshowView: Loaded \(imageAssets.count) more assets, total queue: \(self.assetQueue.count)")
            }
        } catch {
            await MainActor.run {
                print("SlideshowView: Failed to load more assets: \(error)")
                self.isLoadingAssets = false
                self.hasMoreAssets = enableShuffle && !isSharedAlbum // Keep trying for shuffle mode on non-shared albums
            }
        }
    }


}

#Preview {
    // Set the UserDefaults value before creating the view
    UserDefaults.standard.set("auto", forKey: "slideshowBackgroundColor")
    UserDefaults.standard.set("10", forKey: "slideshowInterval")
    UserDefaults.standard.set(true, forKey: "hideImageOverlay")
    UserDefaults.standard.set(true, forKey: "enableReflectionsInSlideshow")
    UserDefaults.standard.set(true, forKey: "enableKenBurnsEffect")
    let (_, _, _, assetService, _, _, _) = MockServiceFactory.createMockServices()

    // Create mock assets for preview
    let mockAssets = [
        ImmichAsset(
            id: "mock-1",
            deviceAssetId: "mock-device-1",
            deviceId: "mock-device",
            ownerId: "mock-owner",
            libraryId: nil,
            type: .image,
            originalPath: "/mock/path1",
            originalFileName: "mock1.jpg",
            originalMimeType: "image/jpeg",
            resized: false,
            thumbhash: nil,
            fileModifiedAt: "2023-01-01",
            fileCreatedAt: "2023-01-01",
            localDateTime: "2023-01-01",
            updatedAt: "2023-01-01",
            isFavorite: false,
            isArchived: false,
            isOffline: false,
            isTrashed: false,
            checksum: "mock-checksum-1",
            duration: nil,
            hasMetadata: false,
            livePhotoVideoId: nil,
            people: [],
            visibility: "public",
            duplicateId: nil,
            exifInfo: nil
        )
    ]

     return SlideshowView(albumId: nil, personId: nil, tagId: nil, startingIndex: 0)
}
