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
    
    @AppStorage("allPhotosSortField") private var allPhotosSortField = "localDateTime"
    @AppStorage("allPhotosSortOrder") private var allPhotosSortOrder = "desc"
    
    @State private var filterYears: Set<Int> = UserDefaults.standard.allPhotosFilteredYears
    @State private var filterLocations: Set<String> = UserDefaults.standard.allPhotosFilteredLocations
    @State private var filterDevices: Set<String> = UserDefaults.standard.allPhotosFilteredDevices

    @State private var showingSortModal = false
    @State private var showingFilterModal = false

    // Context attributes
    let albumId: String?
    let personId: String?
    let tagId: String?
    let city: String?
    let isAllPhotos: Bool
    let isFavorite: Bool
    
    let onAssetsLoaded: (([ImmichAsset]) -> Void)?
    let deepLinkAssetId: String?
    
    @State private var assets: [ImmichAsset] = []
    @State private var isLoading = false
    @State private var isLoadingMore = false
    @State private var errorMessage: String?
    @State private var selectedAsset: ImmichAsset?
    @State private var showingFullScreen = false
    @State private var currentAssetIndex: Int = 0
    @FocusState private var focusedAssetId: String?
    @State private var isProgrammaticFocusChange = false
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
            SharedGradientBackground()
            
            if isLoading {
                loadingOverlay
            } else if let errorMessage = errorMessage {
                errorView(message: errorMessage)
            } else if assets.isEmpty {
                emptyStateView
            } else {
                VStack(spacing: 0) {
                    if isAllPhotos {
                        topToolbar
                    }

                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVGrid(columns: columns, spacing: 50) {
                                ForEach(assets) { asset in
                                    Button(action: {
                                        openAsset(asset)
                                    }) {
                                        AssetThumbnailView(
                                            asset: asset,
                                            assetService: assetService,
                                            isFocused: focusedAssetId == asset.id
                                        )
                                    }
                                    .frame(width: 300, height: 360)
                                    .id(asset.id)
                                    .focused($focusedAssetId, equals: asset.id)
                                    .onAppear {
                                        checkForLoadMore(item: asset)
                                    }
                                    .buttonStyle(CardButtonStyle())
                                }
                                
                                if isLoadingMore {
                                    bottomLoadingIndicator
                                }
                            }
                            .padding(.horizontal)
                            .padding(.top, 20)
                            .padding(.bottom, 40)
                        }
                        .onChange(of: focusedAssetId) { _, newId in
                            handleFocusChange(proxy: proxy, newId: newId)
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
                    currentIndex: currentAssetIndex,
                    assetService: assetService,
                    authenticationService: authService,
                    currentAssetIndex: $currentAssetIndex
                )
            }
        }
        .sheet(isPresented: $showingFilterModal) {
            FilterSettingsView(
                allAssets: assets,
                assetProvider: assetProvider, // Pass the provider
                selectedYears: $filterYears,
                selectedLocations: $filterLocations,
                selectedDevices: $filterDevices,
                onApply: {
                    applyFilters()
                }
            )
        }
        .sheet(isPresented: $showingSortModal) {
            SortSettingsView(
                sortField: $allPhotosSortField,
                sortOrder: $allPhotosSortOrder,
                onApply: {
                    showingSortModal = false
                    loadAssets()
                }
            )
        }
        .onPlayPauseCommand(perform: startSlideshow)
        .onAppear { if assets.isEmpty { loadAssets() } }
        .onDisappear { loadMoreTask?.cancel() }
    }

    // MARK: - Subviews
    
    private var loadingOverlay: some View {
        ProgressView("Loading photos...")
            .foregroundColor(.white)
            .scaleEffect(1.5)
    }
    
    private func errorView(message: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle").font(.system(size: 60)).foregroundColor(.orange)
            Text("Error").font(.title).foregroundColor(.white)
            Text(message).foregroundColor(.gray).multilineTextAlignment(.center).padding()
            Button("Retry") { loadAssets() }.buttonStyle(.borderedProminent)
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "photo.on.rectangle.angled").font(.system(size: 60)).foregroundColor(.gray)
            Text(getEmptyStateTitle()).font(.title).foregroundColor(.white)
            Text(getEmptyStateMessage()).foregroundColor(.gray)
            
            if !filterYears.isEmpty || !filterLocations.isEmpty || !filterDevices.isEmpty {
                Button("Clear All Filters") {
                    clearFilters()
                }
                .buttonStyle(.bordered)
            }
        }
    }
    
    private var topToolbar: some View {
        HStack(spacing: 30) {
            Spacer()
            
            // Filter Button
            Button(action: { showingFilterModal = true }) {
                let count = filterYears.count + filterLocations.count + filterDevices.count
                Label {
                    Text("Filter \(count > 0 ? "(\(count))" : "")")
                } icon: {
                    Image(systemName: count > 0 ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                }
            }
            .buttonStyle(.bordered)
            
            // Sort Button
            Button(action: { showingSortModal = true }) {
                Label {
                    Text("Sort: \(formatSortLabel(allPhotosSortField)) (\(allPhotosSortOrder.uppercased()))")
                } icon: {
                    Image(systemName: "arrow.up.arrow.down")
                }
            }
            .buttonStyle(.bordered)
            .padding(.trailing, 60)
        }
        .padding(.top, 20)
    }
    
    private var bottomLoadingIndicator: some View {
        HStack {
            Spacer()
            ProgressView().foregroundColor(.white).scaleEffect(1.2)
            Spacer()
        }
        .frame(height: 100)
    }

    // MARK: - Logic & Actions

    private func openAsset(_ asset: ImmichAsset) {
        selectedAsset = asset
        currentAssetIndex = assets.firstIndex(of: asset) ?? 0
        showingFullScreen = true
    }

    private func applyFilters() {
        UserDefaults.standard.allPhotosFilteredYears = filterYears
        UserDefaults.standard.allPhotosFilteredLocations = filterLocations
        UserDefaults.standard.allPhotosFilteredDevices = filterDevices
        showingFilterModal = false
        loadAssets()
    }

    private func clearFilters() {
        filterYears.removeAll()
        filterLocations.removeAll()
        filterDevices.removeAll()
        UserDefaults.standard.allPhotosFilteredYears = []
        UserDefaults.standard.allPhotosFilteredLocations = []
        UserDefaults.standard.allPhotosFilteredDevices = []
        loadAssets()
    }

    private func loadAssets() {
        guard authService.isAuthenticated else { return }
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
                    self.hasMoreAssets = searchResult.nextPage != nil
                    onAssetsLoaded?(searchResult.assets)
                }
                ThumbnailCache.shared.preloadThumbnails(for: searchResult.assets)
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }

    private func checkForLoadMore(item: ImmichAsset) {
        guard !isLoadingMore && hasMoreAssets else { return }
        if let index = assets.firstIndex(of: item), index >= assets.count - 40 {
            debouncedLoadMore()
        }
    }

    private func debouncedLoadMore() {
        loadMoreTask?.cancel()
        isLoadingMore = true
        loadMoreTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            if !Task.isCancelled { await MainActor.run { loadMoreAssets() } }
        }
    }

    private func loadMoreAssets() {
        guard hasMoreAssets && nextPage != nil else {
            isLoadingMore = false
            return
        }
        Task {
            do {
                let pageNumber = extractPageFromNextPage(nextPage!)
                let searchResult = try await assetProvider.fetchAssets(page: pageNumber, limit: 200)
                await MainActor.run {
                    if !searchResult.assets.isEmpty {
                        self.assets.append(contentsOf: searchResult.assets)
                        self.nextPage = searchResult.nextPage
                        self.hasMoreAssets = searchResult.nextPage != nil
                    } else {
                        self.hasMoreAssets = false
                    }
                    self.isLoadingMore = false
                }
                ThumbnailCache.shared.preloadThumbnails(for: searchResult.assets)
            } catch {
                await MainActor.run { self.isLoadingMore = false }
            }
        }
    }
    
    private func extractPageFromNextPage(_ nextPageString: String) -> Int {
        if let pageNumber = Int(nextPageString) { return pageNumber }
        return (assets.count / 100) + 2
    }

    private func handleFocusChange(proxy: ScrollViewProxy, newId: String?) {
        if let id = newId, let asset = assets.first(where: { $0.id == id }) {
            currentAssetIndex = assets.firstIndex(of: asset) ?? 0
            
            if isProgrammaticFocusChange {
                withAnimation(.easeInOut) {
                    proxy.scrollTo(id, anchor: .center)
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isProgrammaticFocusChange = false
                }
            }
        }
    }

    private func formatSortLabel(_ field: String) -> String {
        switch field {
        case "localDateTime": return "Date Taken"
        case "originalFileName": return "File Name"
        default: return field.capitalized
        }
    }

    private func getEmptyStateTitle() -> String {
        let count = filterYears.count + filterLocations.count + filterDevices.count
        return count > 0 ? "No Results for Filters" : "No Photos Found"
    }
    
    private func getEmptyStateMessage() -> String {
        let count = filterYears.count + filterLocations.count + filterDevices.count
        return count > 0 ? "Try adjusting your filter settings." : "Your photos will appear here."
    }

    private func startSlideshow() {
        NotificationCenter.default.post(name: NSNotification.Name("stopAutoSlideshowTimer"), object: nil)
        showingSlideshow = true
    }
}
