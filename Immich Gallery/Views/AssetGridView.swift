//
//  AssetGridView.swift
//  Immich Gallery
//
//  Created by mensadi-labs on 2025-06-29.
//

import SwiftUI

struct AssetGridView: View {
    @ObservedObject var assetService: AssetService
    @ObservedObject var authService: AuthenticationService
    @ObservedObject private var thumbnailCache = ThumbnailCache.shared
    let assetProvider: AssetProvider
    let albumId: String? // Optional album ID to filter assets
    let personId: String? // Optional person ID to filter assets
    let tagId: String? // Optional tag ID to filter assets
    let city: String? // Optional city to filter assets
    let isAllPhotos: Bool // Whether this is the All Photos tab
    let isFavorite: Bool // Whether this is showing favorite assets
    let onAssetsLoaded: (([ImmichAsset]) -> Void)? // Callback for when assets are loaded
    let deepLinkAssetId: String? // Asset ID to highlight from deep link
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
                    Image(systemName: "photo.on.rectangle.angled")
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
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVGrid(columns: columns, spacing: 50) {
                            ForEach(assets) { asset in
                                Button(action: {
                                    print("AssetGridView: Asset selected: \(asset.id)")
                                    selectedAsset = asset
                                    if let index = assets.firstIndex(of: asset) {
                                        currentAssetIndex = index
                                        print("AssetGridView: Set currentAssetIndex to \(index)")
                                    }
                                    showingFullScreen = true
                                }) {
                                    AssetThumbnailView(
                                        asset: asset,
                                        assetService: assetService,
                                        isFocused: focusedAssetId == asset.id
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
                                        
                                        // Check if this is the asset we need to scroll to
                                        if shouldScrollToAsset == asset.id {
                                            print("AssetGridView: Target asset appeared in grid - \(asset.id)")
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
                        .padding(.horizontal)
                        .padding(.top, 20)
                        .padding(.bottom, 40)
                        .onChange(of: focusedAssetId) { newFocusedId in
                            print("AssetGridView: focusedAssetId changed to \(newFocusedId ?? "nil"), isProgrammatic: \(isProgrammaticFocusChange)")
                            
                            // Update currentAssetIndex when focus changes
                            if let focusedId = newFocusedId,
                               let focusedAsset = assets.first(where: { $0.id == focusedId }),
                               let index = assets.firstIndex(of: focusedAsset) {
                                currentAssetIndex = index
                                print("AssetGridView: Updated currentAssetIndex to \(index) for focused asset")
                            }
                            
                            // Scroll to the focused asset when it changes
                            if let focusedId = newFocusedId {
                                if isProgrammaticFocusChange {
                                    print("AssetGridView: Programmatic focus change - scrolling to asset ID: \(focusedId)")
                                    withAnimation(.easeInOut(duration: 0.5)) {
                                        proxy.scrollTo(focusedId, anchor: .center)
                                    }
                                    // Reset the flag after scrolling
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        isProgrammaticFocusChange = false
                                    }
                                } else {
                                    print("AssetGridView: User navigation - not scrolling")
                                }
                            }
                        }
                        .onChange(of: shouldScrollToAsset) { assetId in
                            if let assetId = assetId {
                                print("AssetGridView: shouldScrollToAsset triggered - scrolling to asset ID: \(assetId)")
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
                                print("AssetGridView: Deep link asset ID received: \(assetId)")
                                handleDeepLinkAsset(assetId)
                            }
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
                    currentIndex: assets.firstIndex(of: selectedAsset) ?? 0, 
                    assetService: assetService, 
                    authenticationService: authService,
                    currentAssetIndex: $currentAssetIndex
                )
            }
        }
        .fullScreenCover(isPresented: $showingSlideshow) {
            let imageAssets = assets.filter { $0.type == .image }
            if !imageAssets.isEmpty {
                let _ = print("currentAssetIndex test", currentAssetIndex)
                // Find the index of the current asset in the filtered image assets
                let startingIndex = currentAssetIndex < assets.count ? 
                    (imageAssets.firstIndex(of: assets[currentAssetIndex]) ?? 0) : 0
                SlideshowView(albumId: albumId, personId: personId, tagId: tagId, city: city, startingIndex: startingIndex, isFavorite: isFavorite)
            }
        }
        .onPlayPauseCommand(perform: {
            print("Play pause tapped in AssetGridView - starting slideshow")
            startSlideshow()
        })
        .onAppear {
            print("Appared")
            if assets.isEmpty {
                loadAssets()
            }
        }
        .onDisappear {
            // Cancel any pending load more tasks when view disappears
            loadMoreTask?.cancel()
        }
        .onChange(of: showingFullScreen) { _, isShowing in
            print("AssetGridView: showingFullScreen changed to \(isShowing)")
            // When fullscreen is dismissed, highlight the current asset
            if !isShowing && currentAssetIndex < assets.count {
                let currentAsset = assets[currentAssetIndex]
                print("AssetGridView: Fullscreen dismissed, currentAssetIndex: \(currentAssetIndex), asset ID: \(currentAsset.id)")
                
                // Use a more robust approach with proper state management
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    // First, trigger the scroll
                    print("AssetGridView: Setting shouldScrollToAsset to \(currentAsset.id)")
                    shouldScrollToAsset = currentAsset.id
                    
                    // Then set the focus after a short delay to ensure scroll starts
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        print("AssetGridView: Setting focusedAssetId to \(currentAsset.id)")
                        print("AssetGridView: Setting isProgrammaticFocusChange to true")
                        isProgrammaticFocusChange = true
                        focusedAssetId = currentAsset.id
                        print("AssetGridView: focusedAssetId set to \(currentAsset.id)")
                    }
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name(NotificationNames.startAutoSlideshow))) { notification in
            startSlideshow()
        }
    }
    
    private func loadAssets() {
        guard authService.isAuthenticated else {
            errorMessage = "Not authenticated. Please check your credentials."
            return
        }
        
        isLoading = true
        errorMessage = nil
        nextPage = nil
        hasMoreAssets = true
        
        Task {
            do {
                let searchResult = try await assetProvider.fetchAssets(page: 1, limit: 200)
                await MainActor.run {
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
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
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
        
        Task {
            do {
                // Extract page number from nextPage string
                let pageNumber = extractPageFromNextPage(nextPage!)
                let searchResult = try await assetProvider.fetchAssets(page: pageNumber, limit: 200)
                
                await MainActor.run {
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
                    print("Failed to load more assets: \(error)")
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
        if personId != nil {
            return "No Photos of Person"
        } else if albumId != nil {
            return "No Photos in Album"
        } else {
        return "No Photos Found"
        }
    }
    
    private func getEmptyStateMessage() -> String {
        if personId != nil {
            return "This person has no photos"
        } else if albumId != nil {
            return "This album is empty"
        } else {
        return "Your photos will appear here"
        }
    }
    
    private func startSlideshow() {
        // Stop auto-slideshow timer before starting slideshow
        NotificationCenter.default.post(name: NSNotification.Name("stopAutoSlideshowTimer"), object: nil)
        showingSlideshow = true
    }
    
    private func handleDeepLinkAsset(_ assetId: String) {
        // Check if the asset is already loaded
        if assets.contains(where: { $0.id == assetId }) {
            print("AssetGridView: Asset \(assetId) found in loaded assets, scrolling and focusing")
            focusedAssetId = assetId
            isProgrammaticFocusChange = true
        } else {
            print("AssetGridView: Asset \(assetId) not found in current loaded assets")
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

