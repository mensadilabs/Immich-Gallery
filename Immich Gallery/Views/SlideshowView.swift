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
    let city: String?
    let startingIndex: Int
    let isFavorite: Bool
    let isLocked: Bool
    let launchContext: SlideshowLaunchContext?
    @Environment(\.dismiss) private var dismiss

    // Services created internally
    private let assetService: AssetService
    private let albumService: AlbumService?
    
    // Asset provider created using factory - will be recreated with config if needed
    @State private var assetProvider: AssetProvider?
    @State private var slideshowConfig: SlideshowConfig?
    @State private var slideshowConfigurationError: String?

    init(albumId: String? = nil, personId: String? = nil, tagId: String? = nil, city: String? = nil, startingIndex: Int = 0, isFavorite: Bool = false, isLocked: Bool = false, launchContext: SlideshowLaunchContext? = nil) {
        self.albumId = albumId
        self.personId = personId
        self.tagId = tagId
        self.city = city
        self.startingIndex = launchContext.map { $0.startingIndex % 100 } ?? startingIndex
        self.isFavorite = isFavorite
        self.isLocked = isLocked
        self.launchContext = launchContext

        // Create services internally
        let userManager = UserManager()
        let networkService = NetworkService(userManager: userManager)
        self.assetService = AssetService(networkService: networkService)
        self.albumService = AlbumService(networkService: networkService)

        // Initial asset provider - will be replaced if config is fetched
        let initialProvider = AssetProviderFactory.createProvider(
            albumId: albumId,
            personId: personId,
            tagId: tagId,
            city: city,
            isAllPhotos: false, // Slideshow doesn't use "All Photos" mode
            isFavorite: isFavorite,
            isLocked: isLocked,
            assetService: assetService,
            albumService: albumService,
            config: nil
        )
        _assetProvider = State(initialValue: initialProvider)
        _enableShuffle = State(initialValue: launchContext == nil && UserDefaults.standard.enableSlideshowShuffle)
        if let launchContext {
            _currentPage = State(initialValue: launchContext.startingIndex / 100 + 1)
        }
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
    @State private var enableDynamicTransitions: Bool = UserDefaults.standard.enableDynamicTransitions
    @State private var dimensionMultiplier:Double = UserDefaults.standard.enableReflectionsInSlideshow ?  0.9 : 1.0
    @State private var kenBurnsScale: CGFloat = 1.0
    @State private var kenBurnsOffset: CGSize = .zero
    @State private var enableShuffle: Bool = UserDefaults.standard.enableSlideshowShuffle
    @State private var isSharedAlbum: Bool = false
    @State private var emptyQueueRetryCount = 0
    @State private var retriedAssetIDs: Set<String> = []
    @State private var isPreloadingImages = false
    @State private var isRestarting = false
    @FocusState private var isFocused: Bool
    
    /// Computed property to get current Art Mode level from UserDefaults
    private var currentArtModeLevel: ArtModeLevel {
        let levelString = UserDefaults.standard.artModeLevel
        return ArtModeLevel(rawValue: levelString) ?? .off
    }

    enum SlideDirection: CaseIterable {
        case left, right, up, down, diagonal_up_left, diagonal_up_right, diagonal_down_left, diagonal_down_right, zoom_out
        case zoom_in, fade, rotate, flip_horizontal, flip_vertical

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
            case .zoom_out, .zoom_in, .fade, .rotate, .flip_horizontal, .flip_vertical:
                return CGSize.zero // These transitions stay centered
            }
        }

        var scale: CGFloat {
            switch self {
            case .zoom_out: return 0.1 // Scale down to nearly invisible
            case .zoom_in: return 1.8  // Scale up past the frame
            default: return 1.0        // Normal scale
            }
        }

        var opacity: Double {
            switch self {
            // All in-place transitions fade so the swap is seamless
            case .zoom_out, .zoom_in, .fade, .rotate, .flip_horizontal, .flip_vertical:
                return 0.0
            default:
                return 1.0 // Sliding transitions stay fully opaque
            }
        }

        /// 2D rotation applied during the transition (for the spin effect).
        var rotation: Angle {
            switch self {
            case .rotate: return .degrees(90)
            default: return .zero
            }
        }

        /// 3D rotation (angle + axis) applied during the transition (for flip effects).
        var rotation3D: (angle: Double, axis: (x: CGFloat, y: CGFloat, z: CGFloat)) {
            switch self {
            case .flip_horizontal: return (90, (x: 0, y: 1, z: 0))
            case .flip_vertical:   return (90, (x: 1, y: 0, z: 0))
            default:               return (0, (x: 0, y: 1, z: 0))
            }
        }
    }

    // Global slide animation duration for both slide-in and slide-out
    private let slideAnimationDuration: Double = 1.5

    // Backoff used when the advance timer fires with nothing loaded yet. Retrying
    // keeps the slideshow moving once images arrive; backing off stops a slow or
    // down server from being hammered.
    private static let emptyQueueRetryDelays: [TimeInterval] = [2, 5, 15]

    // Transitions picked at random for each new image. Declared once as static
    // constants so they aren't reallocated on every slide advance.
    //
    // `basicTransitionPool` is the classic slide/zoom set used by the standard
    // effects — a flat list picked uniformly.
    private static let basicTransitionPool: [SlideDirection] = [
        .left, .right, .up, .down,
        .diagonal_up_left, .diagonal_up_right, .diagonal_down_left, .diagonal_down_right,
        .zoom_out
    ]

    // For the "Pan & Zoom+" effect, transitions are grouped into visual families.
    // We pick a family first (equal weight), then a variant within it — otherwise
    // the eight slide directions would dominate (~57%) and rotate/flip would
    // rarely appear. This gives each visual style roughly equal airtime.
    private static let transitionFamilies: [[SlideDirection]] = [
        [.left, .right, .up, .down,
         .diagonal_up_left, .diagonal_up_right, .diagonal_down_left, .diagonal_down_right], // slide
        [.zoom_out, .zoom_in],                                                              // zoom
        [.fade],                                                                            // fade
        [.rotate],                                                                          // spin
        [.flip_horizontal, .flip_vertical]                                                  // flip
    ]

    /// Picks the next transition, balancing visual families in dynamic mode.
    private func nextTransition() -> SlideDirection {
        guard enableDynamicTransitions else {
            return Self.basicTransitionPool.randomElement() ?? .right
        }
        let family = Self.transitionFamilies.randomElement() ?? Self.basicTransitionPool
        return family.randomElement() ?? .right
    }

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
                VStack(spacing: 16) {
                    Image(systemName: slideshowConfigurationError == nil ? "photo.on.rectangle.angled" : "exclamationmark.triangle")
                        .font(.system(size: 60))
                        .foregroundColor(slideshowConfigurationError == nil ? .gray : .orange)
                    Text(slideshowConfigurationError == nil ? "No images to display" : "Slideshow configuration error")
                        .font(.title)
                        .foregroundColor(.white)
                    if let slideshowConfigurationError {
                        Text(slideshowConfigurationError)
                            .font(.body)
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                    }
                }
            } else {
                // Main image display
                if isLoading {
                    ProgressView("Starting slideshow...")
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
                                .rotationEffect(isTransitioning ? slideDirection.rotation : .zero)
                                .rotation3DEffect(
                                    isTransitioning ? .degrees(slideDirection.rotation3D.angle) : .zero,
                                    axis: slideDirection.rotation3D.axis,
                                    perspective: 0.4
                                )
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
                                    .rotationEffect(isTransitioning ? slideDirection.rotation : .zero)
                                    .rotation3DEffect(
                                        isTransitioning ? .degrees(slideDirection.rotation3D.angle) : .zero,
                                        axis: slideDirection.rotation3D.axis,
                                        perspective: 0.4
                                    )
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
            enableDynamicTransitions = UserDefaults.standard.enableDynamicTransitions

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
            // Always fetch config first
            guard await fetchConfigAndUpdateProvider() else { return }
            await checkIfAlbumIsShared()
            await loadInitialAssets()
            await loadInitialImages()
            await showFirstImage()
        }
    }
    
    /// An explicit target the slideshow was launched with (a specific album,
    /// person, tag, city, or favorites view).
    struct SlideshowSelection: Equatable {
        let albumId: String?
        let personId: String?
        let tagId: String?
        let city: String?
        let isFavorite: Bool
        let isAllPhotosContext: Bool

        init(
            albumId: String?,
            personId: String?,
            tagId: String?,
            city: String?,
            isFavorite: Bool,
            isAllPhotosContext: Bool = false
        ) {
            self.albumId = albumId
            self.personId = personId
            self.tagId = tagId
            self.city = city
            self.isFavorite = isFavorite
            self.isAllPhotosContext = isAllPhotosContext
        }

        /// True when the slideshow was launched against a specific target rather
        /// than the generic all-photos / auto-slideshow entry point.
        var isExplicit: Bool {
            albumId != nil || personId != nil || tagId != nil || city != nil || isFavorite || isAllPhotosContext
        }
    }

    /// Where the slideshow should source its assets from.
    enum SlideshowSource: Equatable {
        /// Use the explicit selection the user launched the slideshow with.
        case selection(SlideshowSelection)
        /// Use the auto-slideshow config (the `immich-gallery-config` album).
        case config(SlideshowConfig)
    }

    /// Pure decision: given the launch selection and the fetched auto-slideshow
    /// config, decide which one drives the slideshow.
    static func resolveSlideshowSource(selection: SlideshowSelection, config: SlideshowConfig) -> SlideshowSource {
        // An explicit selection (a specific album, person, tag, city, or favorites)
        // always wins. The auto-slideshow config only drives the generic
        // all-photos / inactivity entry point where nothing specific was chosen.
        let configHasValues = !config.albumIds.isEmpty || !config.personIds.isEmpty
        if !selection.isExplicit && configHasValues {
            return .config(config)
        }
        return .selection(selection)
    }

    private func makeProvider(for source: SlideshowSource) -> AssetProvider {
        switch source {
        case .selection(let selection):
            return AssetProviderFactory.createProvider(
                albumId: selection.albumId,
                personId: selection.personId,
                tagId: selection.tagId,
                city: selection.city,
                isAllPhotos: false,
                isFavorite: selection.isFavorite,
                assetService: assetService,
                albumService: albumService,
                slideshowContext: launchContext
            )
        case .config(let config):
            return AssetProviderFactory.createProvider(
                albumId: nil,
                personId: nil,
                tagId: nil,
                isAllPhotos: false,
                isFavorite: false,
                assetService: assetService,
                albumService: albumService,
                config: config
            )
        }
    }

    private func fetchConfigAndUpdateProvider() async -> Bool {
        let selection = SlideshowSelection(
            albumId: albumId,
            personId: personId,
            tagId: tagId,
            city: city,
            isFavorite: isFavorite,
            isAllPhotosContext: launchContext != nil
        )

        guard let albumService = albumService else {
            // No album service available: fall back to the explicit selection.
            await MainActor.run {
                if !selection.isExplicit {
                    slideshowConfigurationError = "Could not load the slideshow configuration."
                    isLoading = false
                } else {
                    self.assetProvider = makeProvider(for: .selection(selection))
                }
            }
            return selection.isExplicit
        }

        let configService = SlideshowConfigService(albumService: albumService)
        let configResult = await configService.fetchSlideshowConfig()
        let config = configResult.config

        let shouldBlockAutoSlideshow = !selection.isExplicit && configResult.blocksAutoSlideshow
        await MainActor.run {
            self.slideshowConfig = config
            if shouldBlockAutoSlideshow {
                slideshowConfigurationError = configResult.userFacingMessage
                isLoading = false
                assetProvider = nil
                return
            }
            let source = SlideshowView.resolveSlideshowSource(selection: selection, config: config)
            switch source {
            case .config(let cfg):
                debugLog("AutoSlideshow: playing config album (albums=\(cfg.albumIds.count), people=\(cfg.personIds.count))")
            case .selection(let sel):
                debugLog("AutoSlideshow: playing \(sel.isExplicit ? "explicit selection" : "all photos")")
            }
            self.assetProvider = makeProvider(for: source)
        }
        return !shouldBlockAutoSlideshow
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

        NotificationCenter.default.post(name: NSNotification.Name(NotificationNames.resumeInactivityMonitoring), object: nil)
    }

    /// Fetches the first page of assets. `fromStartingIndex` only applies to the
    /// first play-through: a loop restart replays the source from its very first
    /// asset, no matter which photo the user launched the slideshow from.
    private func loadInitialAssets(fromStartingIndex: Bool = true) async {
        guard !Task.isCancelled, let assetProvider = assetProvider else { return }

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
                let actualStartingIndex = fromStartingIndex ? min(startingIndex, max(0, imageAssets.count - 1)) : 0
                self.assetQueue = Array(imageAssets.dropFirst(actualStartingIndex))
                self.hasMoreAssets = searchResult.nextPage != nil || (enableShuffle && !isSharedAlbum)
                print("SlideshowView: Loaded \(imageAssets.count) assets, starting at index \(startingIndex)")
            }
        } catch {
            await MainActor.run {
                print("SlideshowView: Failed to load initial assets: \(error)")
                if let message = configurationRequestErrorMessage(for: error) {
                    self.slideshowConfigurationError = message
                    self.assetProvider = nil
                }
                self.isLoading = false
            }
        }
    }

    private func configurationRequestErrorMessage(for error: Error) -> String? {
        guard slideshowConfig != nil else { return nil }
        guard case let ImmichError.httpError(statusCode, message) = error else { return nil }

        let serverMessage = message?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let serverMessage, !serverMessage.isEmpty {
            return "Immich returned HTTP \(statusCode): \(serverMessage)"
        }
        return "Immich returned HTTP \(statusCode)."
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
        var failedAssets: [ImmichAsset] = []
        for i in 0..<imagesToLoad {
            guard i < assetQueue.count else { break }
            let asset = assetQueue[i]
            let loaded = await loadImageIntoQueue(asset: asset)
            if !loaded {
                failedAssets.append(asset)
            }
        }

        // Remove the assets we attempted, then requeue the failures for one retry
        await MainActor.run {
            self.assetQueue.removeFirst(min(imagesToLoad, self.assetQueue.count))
            self.requeueFailedAssets(failedAssets)
        }
    }

    /// Raised when a full-image load outlives its deadline so the caller can treat
    /// it like any other load failure.
    private struct ImageLoadTimeout: Error {}

    /// Loads one asset's full-size image into the display queue.
    /// Returns false when the load failed, timed out, or produced no image, so the
    /// caller can decide what to do with the asset instead of silently dropping it.
    private func loadImageIntoQueue(asset: ImmichAsset) async -> Bool {
        guard !Task.isCancelled else { return false }

        // Originals are multi-megabyte, and one stalled download starves the whole
        // queue. Cap each load at 2x the slide interval, never under 15s so short
        // intervals don't cut off legitimate loads.
        let deadline = max(slideInterval * 2, 15)
        let assetService = self.assetService

        do {
            let image = try await withThrowingTaskGroup(of: UIImage?.self) { group -> UIImage? in
                group.addTask {
                    try await assetService.loadFullImage(asset: asset)
                }
                group.addTask {
                    try await Task.sleep(nanoseconds: UInt64(deadline * 1_000_000_000))
                    throw ImageLoadTimeout()
                }
                defer { group.cancelAll() }
                return try await group.next() ?? nil
            }

            guard let image = image else {
                print("SlideshowView: loadFullImage returned nil for asset \(asset.id)")
                return false
            }

            let dominantColor = slideshowBackgroundColor == "auto" ?
                await ImageColorExtractor.extractDominantColorAsync(from: image) : nil

            await MainActor.run {
                self.imageQueue.append((asset: asset, image: image, dominantColor: dominantColor))
                print("SlideshowView: Loaded image for asset \(asset.id) into queue")
            }
            return true
        } catch is ImageLoadTimeout {
            print("SlideshowView: Timed out after \(deadline)s loading asset \(asset.id)")
            return false
        } catch {
            print("SlideshowView: Failed to load image for asset \(asset.id): \(error)")
            return false
        }
    }

    /// Sends assets that failed to load to the back of the asset queue for one more
    /// attempt. Already-retried assets are dropped so a permanently broken asset
    /// can't cycle through the queue forever.
    @MainActor
    private func requeueFailedAssets(_ assets: [ImmichAsset]) {
        for asset in assets {
            guard !retriedAssetIDs.contains(asset.id) else {
                print("SlideshowView: Dropping asset \(asset.id) after failed retry")
                continue
            }
            retriedAssetIDs.insert(asset.id)
            assetQueue.append(asset)
        }
    }

    private func showFirstImage() async {
        await MainActor.run {
            // Move first image from queue to current
            guard !self.imageQueue.isEmpty else {
                print("SlideshowView: No images in queue to show")
                self.isLoading = false
                // Nothing loaded on the cold start (slow server, timed-out loads):
                // retry rather than sitting on the empty-state screen forever.
                self.scheduleEmptyQueueRetry()
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
        // One preloader at a time: the empty-queue retry can fire while a slow load
        // is still running, and overlapping runs would consume the same assets twice.
        let shouldPreload = await MainActor.run {
            guard !self.isPreloadingImages else {
                print("SlideshowView: Preload already in progress")
                return false
            }
            self.isPreloadingImages = true
            return true
        }
        guard shouldPreload else { return }

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

        var failedAssets: [ImmichAsset] = []
        for asset in assetsToLoad {
            let loaded = await loadImageIntoQueue(asset: asset)
            if !loaded {
                failedAssets.append(asset)
            }
        }

        await MainActor.run {
            self.assetQueue.removeFirst(min(assetsToLoad.count, self.assetQueue.count))
            self.requeueFailedAssets(failedAssets)
            self.isPreloadingImages = false
        }
    }

    private func nextImage() {
        print("SlideshowView: nextImage() called")

        // Check if we have next image ready
        guard !imageQueue.isEmpty else {
            print("SlideshowView: No more images in queue")
            scheduleEmptyQueueRetry()
            return
        }

        print("SlideshowView: Starting slide out animation")
        // Start slide out animation
        withAnimation(.easeInOut(duration: slideAnimationDuration)) {
            isTransitioning = true
        }

        // Wait for slide out to complete, then change image
        DispatchQueue.main.asyncAfter(deadline: .now() + slideAnimationDuration) {
            // Move next image from queue to current
            guard !self.imageQueue.isEmpty else {
                print("SlideshowView: No more images in queue to advance")
                // The queue drained during the transition: slide the current image
                // back in rather than stranding the view mid-animation, and retry.
                withAnimation(.easeInOut(duration: self.slideAnimationDuration)) {
                    self.isTransitioning = false
                }
                self.scheduleEmptyQueueRetry()
                return
            }

            // Discard current image to free memory before retaining the next one
            self.currentImageData = nil
            self.currentImageData = self.imageQueue.removeFirst()
            self.emptyQueueRetryCount = 0

            // Set dominant color if available
            if let dominantColor = self.currentImageData?.dominantColor,
               self.slideshowBackgroundColor == "auto" {
                self.dominantColor = dominantColor
            }

            // Set new slide direction/transition for the incoming image.
            self.slideDirection = self.nextTransition()

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

    /// Called whenever an advance finds nothing to show. Either the queue is only
    /// temporarily starved (retry with backoff) or the source has been played to
    /// the end (loop back to the beginning).
    private func scheduleEmptyQueueRetry() {
        // Nothing buffered, nothing pending, nothing left to fetch: the slideshow
        // has played everything, so loop back to the first asset. The current
        // image has already had its full interval by the time we get here, and it
        // stays on screen while the first page reloads.
        if assetQueue.isEmpty && !hasMoreAssets && !isLoadingAssets {
            guard currentImageData != nil else {
                // Never showed anything at all (empty album, no matching assets):
                // leave the empty state up instead of polling the server forever.
                print("SlideshowView: No assets to display, nothing to loop back to")
                return
            }
            restartFromBeginning()
            return
        }

        armEmptyQueueRetryTimer()
    }

    /// Arms the backoff timer that re-attempts an advance, and restarts the
    /// preloader, so a queue starved by a slow server recovers on its own.
    private func armEmptyQueueRetryTimer() {
        let delay = Self.emptyQueueRetryDelays[min(emptyQueueRetryCount, Self.emptyQueueRetryDelays.count - 1)]
        emptyQueueRetryCount += 1
        print("SlideshowView: Queue empty - retrying advance in \(delay)s")

        // Reuse autoAdvanceTimer so dismissal cancels the retry like any other timer
        stopAutoAdvance()
        autoAdvanceTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { _ in
            self.nextImage()
        }

        Task {
            await self.maintainImageQueue()
        }
    }

    /// Starts the source over from its first asset once every asset has played.
    /// The last image keeps showing until the first image of the new cycle is
    /// buffered, so the loop has no loading flash and no shortened slide.
    private func restartFromBeginning() {
        guard !isRestarting else { return }
        isRestarting = true
        print("SlideshowView: Reached the end - looping back to the beginning")

        // Reset pagination so the next fetch is page one again, and forget which
        // assets already burned their retry so each cycle gets fresh attempts.
        stopAutoAdvance()
        currentPage = 1
        hasMoreAssets = true
        retriedAssetIDs.removeAll()

        loadAssetsTask = Task {
            await loadInitialAssets(fromStartingIndex: false)
            await loadMoreImagesIfNeeded()

            guard !Task.isCancelled else { return }
            await MainActor.run {
                self.isRestarting = false
                guard !self.imageQueue.isEmpty else {
                    // The whole cycle produced nothing loadable. Fall back to the
                    // backoff timer rather than restarting again immediately, so a
                    // broken source can't hot-loop fetches.
                    print("SlideshowView: Loop restart loaded no images")
                    self.armEmptyQueueRetryTimer()
                    return
                }
                self.nextImage()
            }
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

        guard shouldLoad, let assetProvider = assetProvider else { return }

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
    let (_, _, _, assetService, _, _, _, _) = MockServiceFactory.createMockServices()

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

     return SlideshowView(albumId: nil, personId: nil, tagId: nil, city: nil, startingIndex: 0, isFavorite: false)
}
