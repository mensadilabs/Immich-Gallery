//
//  AssetGridView.swift
//  Immich Gallery
//

import SwiftUI

struct AssetGridView: View {
    @ObservedObject var assetService: AssetService
    @ObservedObject var authService: AuthenticationService
    @ObservedObject private var thumbnailCache = ThumbnailCache.shared
    let assetProvider: AssetProvider
    
    // Sorting
    @AppStorage("allPhotosSortField") private var allPhotosSortField = "localDateTime"
    @AppStorage("allPhotosSortOrder") private var allPhotosSortOrder = "desc"
    @State private var showingSortModal = false

    // Slideshow attributes
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
    @State private var shouldScrollToAsset: String?
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
    
    private func formatSortLabel(_ field: String) -> String {
        switch field {
        case "localDateTime": return "Date Taken"
        case "originalFileName": return "File Name"
        case "createdAt": return "Date Added" // Added display label for the new attribute
        default: return field.capitalized
        }
    }
    
    var body: some View {
        ZStack {
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
                    Text("Error").font(.title).foregroundColor(.white)
                    Text(errorMessage).foregroundColor(.gray).multilineTextAlignment(.center).padding()
                    Button("Retry") { loadAssets() }.buttonStyle(.borderedProminent)
                }
            } else if assets.isEmpty {
                VStack {
                    Image(systemName: "photo.on.rectangle.angled").font(.system(size: 60)).foregroundColor(.gray)
                    Text(getEmptyStateTitle()).font(.title).foregroundColor(.white)
                    Text(getEmptyStateMessage()).foregroundColor(.gray)
                }
            } else {
                VStack(spacing: 0) {
                    if isAllPhotos {
                        HStack {
                            Spacer()
                            Button(action: { showingSortModal = true }) {
                                HStack {
                                    Image(systemName: "line.3.horizontal.decrease.circle")
                                    Text("Sort: \(formatSortLabel(allPhotosSortField)) (\(allPhotosSortOrder.uppercased()))")
                                }
                            }
                            .buttonStyle(.bordered)
                            .padding(.trailing, 60)
                            .padding(.top, 20)
                        }
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
                                            isFocused: focusedAssetId == asset.id
                                        )
                                    }
                                    .frame(width: 300, height: 360)
                                    .id(asset.id)
                                    .focused($focusedAssetId, equals: asset.id)
                                    .animation(.easeInOut(duration: 0.2), value: focusedAssetId)
                                    .onAppear {
                                        if let index = assets.firstIndex(of: asset) {
                                            let threshold = max(assets.count - 100, 0)
                                            if index >= threshold && hasMoreAssets && !isLoadingMore {
                                                debouncedLoadMore()
                                            }
                                        }
                                    }
                                    .buttonStyle(CardButtonStyle())
                                }
                                
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
                            .padding(.horizontal).padding(.top, 20).padding(.bottom, 40)
                        }
                        .onChange(of: focusedAssetId) { newFocusedId in
                            if let focusedId = newFocusedId,
                               let focusedAsset = assets.first(where: { $0.id == focusedId }),
                               let index = assets.firstIndex(of: focusedAsset) {
                                currentAssetIndex = index
                            }
                            if let focusedId = newFocusedId, isProgrammaticFocusChange {
                                withAnimation(.easeInOut(duration: 0.5)) { proxy.scrollTo(focusedId, anchor: .center) }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { isProgrammaticFocusChange = false }
                            }
                        }
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showingFullScreen) {
            if let selectedAsset = selectedAsset {
                FullScreenImageView(
                    asset: selectedAsset, assets: assets, currentIndex: assets.firstIndex(of: selectedAsset) ?? 0,
                    assetService: assetService, authenticationService: authService, currentAssetIndex: $currentAssetIndex
                )
            }
        }
        .fullScreenCover(isPresented: $showingSlideshow) {
            let imageAssets = assets.filter { $0.type == .image }
            if !imageAssets.isEmpty {
                let startingIndex = currentAssetIndex < assets.count ? (imageAssets.firstIndex(of: assets[currentAssetIndex]) ?? 0) : 0
                SlideshowView(albumId: albumId, personId: personId, tagId: tagId, city: city, startingIndex: startingIndex, isFavorite: isFavorite)
            }
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
        .onPlayPauseCommand(perform: { startSlideshow() })
        .onAppear { if assets.isEmpty { loadAssets() } }
        .onDisappear { loadMoreTask?.cancel() }
        .onChange(of: showingFullScreen) { _, isShowing in
            if !isShowing && currentAssetIndex < assets.count {
                let currentAsset = assets[currentAssetIndex]
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    shouldScrollToAsset = currentAsset.id
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        isProgrammaticFocusChange = true
                        focusedAssetId = currentAsset.id
                    }
                }
            }
        }
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
    
    private func debouncedLoadMore() {
        guard !isLoadingMore && hasMoreAssets else { return }
        isLoadingMore = true
        loadMoreTask?.cancel()
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
    
    private func getEmptyStateTitle() -> String {
        if personId != nil { return "No Photos of Person" }
        if albumId != nil { return "No Photos in Album" }
        return "No Photos Found"
    }
    
    private func getEmptyStateMessage() -> String {
        if personId != nil { return "This person has no photos" }
        if albumId != nil { return "This album is empty" }
        return "Your photos will appear here"
    }
    
    private func startSlideshow() {
        NotificationCenter.default.post(name: NSNotification.Name("stopAutoSlideshowTimer"), object: nil)
        showingSlideshow = true
    }
}

// MARK: - Main Sort Settings View
struct SortSettingsView: View {
    @Binding var sortField: String
    @Binding var sortOrder: String
    var onApply: () -> Void
    
    // Internal state to hold changes until "Apply" is pressed
    @State private var localField: String
    @State private var localOrder: String

    init(sortField: Binding<String>, sortOrder: Binding<String>, onApply: @escaping () -> Void) {
        self._sortField = sortField
        self._sortOrder = sortOrder
        self.onApply = onApply
        self._localField = State(initialValue: sortField.wrappedValue)
        self._localOrder = State(initialValue: sortOrder.wrappedValue)
    }
    
    var body: some View {
        ZStack {
            // Background
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
            
            LinearGradient(
                colors: [Color.black.opacity(0.4), Color.blue.opacity(0.15)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                VStack(spacing: 15) {
                    Text("Sort Settings")
                        .font(.system(size: 80, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Select an option and press the center button to confirm")
                        .font(.title3)
                        .foregroundColor(.gray)
                }
                .padding(.top, 80)
                .padding(.bottom, 60)
                
                // Selection Area
                HStack(alignment: .top, spacing: 100) {
                    
                    // Column 1: Sort Field
                    VStack(alignment: .leading, spacing: 25) {
                        Label("Sort By", systemImage: "arrow.up.arrow.down")
                            .font(.headline)
                            .foregroundColor(.white.opacity(0.7))
                            .padding(.leading, 30)
                        
                        VStack(spacing: 20) {
                            SortOptionButton(label: "Date Taken", value: "localDateTime", currentSelection: $localField)
                            SortOptionButton(label: "Date Added", value: "createdAt", currentSelection: $localField)
                            SortOptionButton(label: "File Name", value: "originalFileName", currentSelection: $localField)
                        }
                        .frame(width: 750)
                    }
                    
                    // Column 2: Sort Order
                    VStack(alignment: .leading, spacing: 25) {
                        Label("Order", systemImage: "list.number")
                            .font(.headline)
                            .foregroundColor(.white.opacity(0.7))
                            .padding(.leading, 30)
                        
                        VStack(spacing: 20) {
                            SortOptionButton(label: "Descending", value: "desc", currentSelection: $localOrder)
                            SortOptionButton(label: "Ascending", value: "asc", currentSelection: $localOrder)
                        }
                        .frame(width: 750)
                    }
                }
                .padding(.horizontal, 100) // This creates the "gutter" at the edges
                
                Spacer()

                // Footer / Action Button
                Button(action: {
                    sortField = localField
                    sortOrder = localOrder
                    onApply()
                }) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Apply Settings")
                    }
                    .font(.title3)
                    .padding(.horizontal, 80)
                    .padding(.vertical, 15)
                }
                .buttonStyle(.borderedProminent)
                .padding(.bottom, 100)
            }
        }
    }
}

// MARK: - Supporting View: SortOptionButton
// This replaces the native Picker to prevent the "hover-to-select" bug
struct SortOptionButton: View {
    let label: String
    let value: String
    @Binding var currentSelection: String
    
    var body: some View {
        Button(action: {
            // This only triggers when the user CLICKs the remote
            currentSelection = value
        }) {
            HStack {
                Text(label)
                    .font(.title2)
                Spacer()
                if currentSelection == value {
                    Image(systemName: "checkmark")
                        .foregroundColor(.blue)
                        .font(.system(size: 30, weight: .bold))
                }
            }
            .padding(.horizontal, 50)
            .frame(maxWidth: .infinity)
            .frame(height: 100)
        }
        .buttonStyle(.card) // Provides the native Apple TV focus effect
    }
}
