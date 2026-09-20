//
//  AssetGridView.swift
//  Immich Gallery
//
//  Created by mensadi-labs on 2025-06-29.
//

import SwiftUI

struct AssetGridView: View {
    private enum MediaFilter: Equatable {
        case all
        case video

        var iconName: String {
            switch self {
            case .all: "photo.on.rectangle.angled"
            case .video: "video.fill"
            }
        }

        var assetType: AssetType? {
            switch self {
            case .all: nil
            case .video: .video
            }
        }
    }

    @ObservedObject var assetService: AssetService
    @ObservedObject var authService: AuthenticationService
    let assetProvider: AssetProvider
    @AppStorage("allPhotosSortOrder") private var allPhotosSortOrder = "desc"
    @AppStorage(UserDefaultsKeys.assetSortOrder) private var assetSortOrder = "desc"
    let albumId: String? // Optional album ID to filter assets
    let personId: String? // Optional person ID to filter assets
    let tagId: String? // Optional tag ID to filter assets
    let city: String? // Optional city to filter assets
    let isAllPhotos: Bool // Whether this is the All Photos tab
    let isFavorite: Bool // Whether this is showing favorite assets
    let isLocked: Bool // Whether this is showing locked assets
    let onAssetsLoaded: (([ImmichAsset]) -> Void)? // Callback for when assets are loaded
    let deepLinkAssetId: String? // Asset ID to highlight from deep link
    let allowsSlideshow: Bool
    @State private var assets: [ImmichAsset] = []
    @State private var isLoading = false
    @State private var isLoadingMore = false
    @State private var errorMessage: String?
    @State private var selectedAsset: ImmichAsset?
    @State private var showingFullScreen = false
    @State private var currentAssetIndex: Int = 0 // Track current asset index for highlighting
    @FocusState private var focusedAssetId: String?
    @State private var isProgrammaticFocusChange = false // Flag to track programmatic focus changes
    @State private var shouldScrollToAsset: String? // Asset ID to scroll to
    @State private var nextPage: String?
    @State private var hasMoreAssets = true
    @State private var loadMoreTask: Task<Void, Never>?
    @State private var showingSlideshow = false
    @State private var showingFilterModal = false
    @State private var filters = PhotoFilterSelection.saved
    @State private var isScrolling = false
    @State private var mediaFilter: MediaFilter = .all
    @State private var loadGeneration = UUID()

    init(
        assetService: AssetService,
        authService: AuthenticationService,
        assetProvider: AssetProvider,
        albumId: String?,
        personId: String?,
        tagId: String?,
        city: String?,
        isAllPhotos: Bool,
        isFavorite: Bool,
        isLocked: Bool = false,
        onAssetsLoaded: (([ImmichAsset]) -> Void)?,
        deepLinkAssetId: String?,
        allowsSlideshow: Bool = true
    ) {
        self._assetService = ObservedObject(wrappedValue: assetService)
        self._authService = ObservedObject(wrappedValue: authService)
        self.assetProvider = assetProvider
        self.albumId = albumId
        self.personId = personId
        self.tagId = tagId
        self.city = city
        self.isAllPhotos = isAllPhotos
        self.isFavorite = isFavorite
        self.isLocked = isLocked
        self.onAssetsLoaded = onAssetsLoaded
        self.deepLinkAssetId = deepLinkAssetId
        self.allowsSlideshow = allowsSlideshow
    }
    
    private let columns = [
        GridItem(.fixed(300), spacing: 50),
        GridItem(.fixed(300), spacing: 50),
        GridItem(.fixed(300), spacing: 50),
        GridItem(.fixed(300), spacing: 50),
        GridItem(.fixed(300), spacing: 50),
    ]
    
    var body: some View {
        ZStack {
            // Background
            SharedGradientBackground()
            
            if isLoading {
                ProgressView("Loading photos...")
                    .foregroundColor(.white)
                    .scaleEffect(1.5)
            } else if let errorMessage = errorMessage {
                VStack {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 60))
                        .foregroundColor(.orange)
                    Text("Error")
                        .font(.title)
                        .foregroundColor(.white)
                    Text(errorMessage)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding()
                    Button("Retry") {
                        loadAssets()
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else if assets.isEmpty {
                VStack {
                    if shouldShowAllPhotosToolbar {
                        allPhotosToolbar
                            .padding(.bottom, 20)
                    }
                    Image(systemName: getEmptyStateIconName())
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    Text(getEmptyStateTitle())
                        .font(.title)
                        .foregroundColor(.white)
                    Text(getEmptyStateMessage())
                        .foregroundColor(.gray)
                }
            } else {
                VStack {
                    if shouldShowAllPhotosToolbar {
                        allPhotosToolbar
                            .padding(.bottom, 20)
                    }
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVGrid(columns: columns, spacing: 50) {
                            ForEach(assets) { asset in
                                Button(action: {
                                    selectedAsset = asset
                                    if let index = assets.firstIndex(of: asset) {
                                        currentAssetIndex = index
                                    }
                                    showingFullScreen = true
                                }) {
                                    AssetThumbnailView(
                                        asset: asset,
                                        assetService: assetService,
                                        isFocused: focusedAssetId == asset.id,
                                        shouldLoadThumbnail: !isScrolling,
                                        allowsThumbhashPlaceholder: false
                                    )
                                }
                                .frame(width: 300, height: 360)
                                .id(asset.id) // Add id for ScrollViewReader
                                .focused($focusedAssetId, equals: asset.id)
//                                .scaleEffect(focusedAssetId == asset.id ? 1.1 : 1.0)
                                .animation(.easeInOut(duration: 0.2), value: focusedAssetId)
                                .onAppear {
                                    // More efficient index check using enumerated
                                    if let index = assets.firstIndex(of: asset) {
                                        let threshold = max(assets.count - 100, 0) // Load when 20 items away from end
                                        if index >= threshold && hasMoreAssets && !isLoadingMore {
                                            debouncedLoadMore()
                                        }
                                    }
                                }
                                .buttonStyle(CardButtonStyle())
                            }
                            
                            // Loading indicator at the bottom
                            if isLoadingMore {
                                HStack {
                                    Spacer()
                                    ProgressView("Loading more...")
                                        .foregroundColor(.white)
                                        .scaleEffect(1.2)
                                    Spacer()
                                }
                                .frame(height: 100)
                                .padding()
                            }
                        }
                        // Pair the sparse, left-aligned grid with the right-aligned
                        // controls so focus can cross the empty horizontal gap.
                        .focusSection()
                        .padding(.horizontal)
                        .padding(.top, 20)
                        .padding(.bottom, 40)
                        .onChange(of: focusedAssetId) { newFocusedId in
                            // Update currentAssetIndex when focus changes
                            if let focusedId = newFocusedId,
                               let focusedAsset = assets.first(where: { $0.id == focusedId }),
                               let index = assets.firstIndex(of: focusedAsset) {
                                currentAssetIndex = index
                            }
                            
                            // Scroll to the focused asset when it changes
                            if let focusedId = newFocusedId {
                                if isProgrammaticFocusChange {
                                    withAnimation(.easeInOut(duration: 0.5)) {
                                        proxy.scrollTo(focusedId, anchor: .center)
                                    }
                                    // Reset the flag after scrolling
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        isProgrammaticFocusChange = false
                                    }
                                }
                            }
                        }
                        .onChange(of: shouldScrollToAsset) { assetId in
                            if let assetId = assetId {
                                // Use a more robust scrolling approach with proper timing
                                DispatchQueue.main.async {
                                    withAnimation(.easeInOut(duration: 0.5)) {
                                        proxy.scrollTo(assetId, anchor: .center)
                                    }
                                }
                                // Clear the trigger after a longer delay to ensure scroll completes
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                                    shouldScrollToAsset = nil
                                }
                                }
                            }
                        .onChange(of: deepLinkAssetId) { assetId in
                            if let assetId = assetId {
                                handleDeepLinkAsset(assetId)
                            }
                        }
                        .onScrollPhaseChange { _, newPhase, context in
                            isScrolling = ThumbnailScrollLoadingPolicy.shouldPauseLoading(
                                during: newPhase,
                                velocity: context.velocity
                            )
                        }
                        }
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showingFullScreen) {
            if let selectedAsset = selectedAsset {
                FullScreenImageView(
                    asset: selectedAsset, 
                    assets: assets, 
                    assetService: assetService, 
                    authenticationService: authService,
                    currentAssetIndex: $currentAssetIndex
                )
            }
        }
        .fullScreenCover(isPresented: $showingSlideshow) {
            let imageAssets = assets.filter { $0.type == .image }
            if !imageAssets.isEmpty {
                // Find the index of the current asset in the filtered image assets
                let startingIndex = currentAssetIndex < assets.count ? 
                    (imageAssets.firstIndex(of: assets[currentAssetIndex]) ?? 0) : 0
                if isAllPhotos {
                    SlideshowView(
                        launchContext: SlideshowLaunchContext(
                            startingIndex: startingIndex,
                            filters: filters,
                            favoritesOnly: isFavorite,
                            assetType: mediaFilter.assetType,
                            sortOrder: allPhotosSortOrder
                        )
                    )
                } else {
                    SlideshowView(albumId: albumId, personId: personId, tagId: tagId, city: city, startingIndex: startingIndex, isFavorite: isFavorite, isLocked: isLocked)
                }
            }
        }
        .onPlayPauseCommand(perform: {
            if allowsSlideshow {
                startSlideshow()
            }
        })
        .sheet(isPresented: $showingFilterModal) {
            FilterSettingsView(
                assetService: assetService,
                selection: $filters
            ) {
                applyFilters()
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: toggleMediaFilter) {
                    Image(systemName: mediaFilter.iconName)
                        .foregroundColor(.white)
                }
                .accessibilityLabel(mediaFilter == .all ? "Show videos only" : "Show all media")
                .accessibilityValue(mediaFilter == .all ? "All media" : "Videos only")
                .accessibilityHint("Toggles the media-type filter")
            }

            if !isAllPhotos {
                ToolbarItem(placement: .navigationBarTrailing) {
                    AssetSortToolbarButton(
                        sortOrder: assetSortOrder,
                        action: toggleAssetSortOrder
                    )
                }
            }
        }
        .onAppear {
            if assets.isEmpty {
                loadAssets()
            }
        }
        .onDisappear {
            // Cancel any pending load more tasks when view disappears
            loadMoreTask?.cancel()
        }
        .onChange(of: showingFullScreen) { _, isShowing in
            // When fullscreen is dismissed, highlight the current asset
            if !isShowing && currentAssetIndex < assets.count {
                let currentAsset = assets[currentAssetIndex]
                
                // Use a more robust approach with proper state management
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    // First, trigger the scroll
                    shouldScrollToAsset = currentAsset.id
                    
                    // Then set the focus after a short delay to ensure scroll starts
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        isProgrammaticFocusChange = true
                        focusedAssetId = currentAsset.id
                    }
                }
            }
        }
    }

    private var shouldShowAllPhotosToolbar: Bool {
        isAllPhotos
    }

    private func toggleAssetSortOrder() {
        assetSortOrder = assetSortOrder == "asc" ? "desc" : "asc"
        loadAssets()
    }

    private func toggleAllPhotosSortOrder() {
        allPhotosSortOrder = allPhotosSortOrder == "asc" ? "desc" : "asc"
        loadAssets()
    }

    private var allPhotosToolbar: some View {
        HStack(spacing: 30) {
            Spacer()

            Button(action: { showingFilterModal = true }) {
                let count = filters.activeCount
                Label {
                    Text("Filter \(count > 0 ? "(\(count))" : "")")
                } icon: {
                    Image(systemName: count > 0 ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                }
            }
            .buttonStyle(.bordered)

            AllPhotosSortButton(
                sortOrder: allPhotosSortOrder,
                action: toggleAllPhotosSortOrder
            )
        }
        // A one- or two-item grid may have no geometric focus candidate below
        // these controls unless both regions participate as focus sections.
        .focusSection()
    }
    
    private func loadAssets() {
        guard authService.isAuthenticated else {
            errorMessage = "Not authenticated. Please check your credentials."
            return
        }
        
        isLoading = true
        isLoadingMore = false
        loadMoreTask?.cancel()
        errorMessage = nil
        nextPage = nil
        hasMoreAssets = true
        let generation = UUID()
        loadGeneration = generation
        let assetType = mediaFilter.assetType
        
        Task {
            do {
                let searchResult = try await assetProvider.fetchAssets(
                    page: 1,
                    limit: 200,
                    assetType: assetType
                )
                await MainActor.run {
                    guard loadGeneration == generation else { return }
                    self.assets = searchResult.assets
                    self.nextPage = searchResult.nextPage
                    self.isLoading = false
                    // If there's no nextPage, we've reached the end
                    self.hasMoreAssets = searchResult.nextPage != nil
                    
                    // Notify parent view about loaded assets
                    onAssetsLoaded?(searchResult.assets)
                }
                
                // Preload thumbnails for better performance
                ThumbnailCache.shared.preloadThumbnails(for: searchResult.assets)
            } catch {
                await MainActor.run {
                    guard loadGeneration == generation else { return }
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }

    private func applyFilters() {
        filters.save()
        showingFilterModal = false
        loadAssets()
    }

    private func toggleMediaFilter() {
        mediaFilter = mediaFilter == .all ? .video : .all
        loadAssets()
    }
    
    private func debouncedLoadMore() {
        // Immediately set loading state to prevent multiple triggers
        guard !isLoadingMore && hasMoreAssets else { return }
        
        isLoadingMore = true
        
        // Cancel any existing load more task
        loadMoreTask?.cancel()
        
        // Create a new debounced task
        loadMoreTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000) // 300ms delay
            
            // Check if task was cancelled during sleep
            if Task.isCancelled {
                await MainActor.run {
                    isLoadingMore = false
                }
                return
            }
            
            await MainActor.run {
                loadMoreAssets()
            }
        }
    }
    
    private func loadMoreAssets() {
        guard hasMoreAssets && nextPage != nil else { 
            isLoadingMore = false
            return 
        }
        
        let generation = loadGeneration
        let assetType = mediaFilter.assetType

        Task {
            do {
                // Extract page number from nextPage string
                let pageNumber = extractPageFromNextPage(nextPage!)
                let searchResult = try await assetProvider.fetchAssets(
                    page: pageNumber,
                    limit: 200,
                    assetType: assetType
                )
                
                await MainActor.run {
                    guard loadGeneration == generation else { return }
                    if !searchResult.assets.isEmpty {
                        self.assets.append(contentsOf: searchResult.assets)
                        self.nextPage = searchResult.nextPage
                        
                        // If there's no nextPage, we've reached the end
                        self.hasMoreAssets = searchResult.nextPage != nil
                    } else {
                        self.hasMoreAssets = false
                    }
                    self.isLoadingMore = false
                }
                
                // Preload thumbnails for newly loaded assets
                ThumbnailCache.shared.preloadThumbnails(for: searchResult.assets)
            } catch {
                await MainActor.run {
                    guard loadGeneration == generation else { return }
                    self.isLoadingMore = false
                }
            }
        }
    }
    
    private func extractPageFromNextPage(_ nextPageString: String) -> Int {
        // Optimized page extraction with caching
        if let pageNumber = Int(nextPageString) {
            return pageNumber
        }
        
        // Try to extract from URL parameters more efficiently
        if nextPageString.contains("page="),
           let url = URL(string: nextPageString),
           let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let pageParam = components.queryItems?.first(where: { $0.name == "page" }),
           let pageNumber = Int(pageParam.value ?? "2") {
            return pageNumber
        }
        
        // Default fallback - calculate based on current assets count
        return (assets.count / 100) + 2
    }
    
    private func getEmptyStateTitle() -> String {
        if mediaFilter == .video, isFavorite {
            return "No Favorite Videos"
        } else if mediaFilter == .video, personId != nil {
            return "No Videos of Person"
        } else if mediaFilter == .video, albumId != nil {
            return "No Videos in Album"
        } else if mediaFilter == .video {
            return "No Videos Found"
        } else if isAllPhotos, filters.activeCount > 0 {
            return "No Results for Filters"
        } else if isFavorite {
            return "No Favorites Found"
        } else if personId != nil {
            return "No Photos of Person"
        } else if albumId != nil {
            return "No Photos in Album"
        } else {
            return "No Photos Found"
        }
    }
    
    private func getEmptyStateMessage() -> String {
        if mediaFilter == .video, isAllPhotos, filters.activeCount > 0 {
            return "Try adjusting your filters to find videos."
        } else if mediaFilter == .video, isFavorite {
            return "Your favorite videos will appear here"
        } else if mediaFilter == .video, personId != nil {
            return "This person has no videos"
        } else if mediaFilter == .video, albumId != nil {
            return "This album has no videos"
        } else if mediaFilter == .video {
            return "Videos in this collection will appear here"
        } else if isAllPhotos, filters.activeCount > 0 {
            return "Try adjusting your filter settings."
        } else if isFavorite {
            return "Your favorite photos and videos will appear here"
        } else if personId != nil {
            return "This person has no photos"
        } else if albumId != nil {
            return "This album is empty"
        } else {
            return "Your photos will appear here"
        }
    }

    private func getEmptyStateIconName() -> String {
        if mediaFilter == .video {
            return "video.fill"
        }
        if isFavorite {
            return "heart.fill"
        }
        return "photo.on.rectangle.angled"
    }
    
    private func startSlideshow() {
        debugLog("AutoSlideshow: starting slideshow (pausing inactivity monitoring)")
        NotificationCenter.default.post(name: NSNotification.Name(NotificationNames.pauseInactivityMonitoring), object: nil)
        showingSlideshow = true
    }
    
    private func handleDeepLinkAsset(_ assetId: String) {
        // Check if the asset is already loaded
        if assets.contains(where: { $0.id == assetId }) {
            focusedAssetId = assetId
            isProgrammaticFocusChange = true
        } else {
            // For now, just load the first page and hope the asset is there
            // In a more complex implementation, we could search for the asset across pages
            if assets.isEmpty {
                loadAssets()
                // After loading, try to find the asset again
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    if let foundAsset = assets.first(where: { $0.id == assetId }) {
                        focusedAssetId = foundAsset.id
                        isProgrammaticFocusChange = true
                    }
                }
            }
        }
    }
}

private struct AssetSortToolbarButton: View {
    let sortOrder: String
    let action: () -> Void

    private var isOldestFirst: Bool {
        sortOrder == "asc"
    }

    var body: some View {
        Button(action: action) {
            Text(isOldestFirst ? "Oldest → Newest" : "Newest → Oldest")
                .frame(width: 150)
        }
        .buttonStyle(.bordered)
        .frame(width: 190)
        .accessibilityLabel("Sort photos by date taken")
        .accessibilityValue(isOldestFirst ? "Oldest first" : "Newest first")
        .accessibilityHint(
            isOldestFirst
            ? "Switches to newest first"
            : "Switches to oldest first"
        )
    }
}
