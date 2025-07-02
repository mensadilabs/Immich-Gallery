//
//  AssetGridView.swift
//  Immich Gallery
//
//  Created by mensadi-labs on 2025-06-29.
//

import SwiftUI

struct AssetGridView: View {
    @ObservedObject var immichService: ImmichService
    @ObservedObject private var thumbnailCache = ThumbnailCache.shared
    let albumId: String? // Optional album ID to filter assets
    @State private var assets: [ImmichAsset] = []
    @State private var isLoading = false
    @State private var isLoadingMore = false
    @State private var errorMessage: String?
    @State private var selectedAsset: ImmichAsset?
    @State private var showingFullScreen = false
    @FocusState private var focusedAssetId: String?
    @State private var nextPage: String?
    @State private var hasMoreAssets = true
    @State private var loadMoreTask: Task<Void, Never>?
    
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
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.blue.opacity(0.3),
                    Color.purple.opacity(0.2),
                    Color.gray.opacity(0.4)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
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
                    Text(albumId != nil ? "No Photos in Album" : "No Photos Found")
                        .font(.title)
                        .foregroundColor(.white)
                    Text(albumId != nil ? "This album is empty" : "Your photos will appear here")
                        .foregroundColor(.gray)
                }
            } else {

                   
                    
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 50) {
                        ForEach(assets) { asset in
                            UIKitFocusable(action: {
                                print("Asset selected: \(asset.id)")
                                selectedAsset = asset
                                showingFullScreen = true
                            }) {
                                AssetThumbnailView(
                                    asset: asset,
                                    immichService: immichService,
                                    isFocused: focusedAssetId == asset.id
                                )
                            }
                            .frame(width: 300, height: 360)
                            .focused($focusedAssetId, equals: asset.id)
                            .scaleEffect(focusedAssetId == asset.id ? 1.05 : 1.0)
                            .animation(.easeInOut(duration: 0.2), value: focusedAssetId)
                            .onAppear {
                                // More efficient index check using enumerated
                                if let index = assets.firstIndex(of: asset) {
                                    let threshold = max(assets.count - 8, 0) // Load when 8 items away from end
                                    if index >= threshold && hasMoreAssets && !isLoadingMore {
                                        debouncedLoadMore()
                                    }
                                }
                            }
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
                
            }
            }
        }
        .fullScreenCover(isPresented: $showingFullScreen) {
            if let selectedAsset = selectedAsset {
                FullScreenImageView(asset: selectedAsset, assets: assets, currentIndex: assets.firstIndex(of: selectedAsset) ?? 0, immichService: immichService)
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
    }
    
    private func loadAssets() {
        guard immichService.isAuthenticated else {
            errorMessage = "Not authenticated. Please check your credentials."
            return
        }
        
        isLoading = true
        errorMessage = nil
        nextPage = nil
        hasMoreAssets = true
        
        Task {
            do {
                let searchResult = try await immichService.fetchAssets(page: 1, limit: 100, albumId: albumId)
                await MainActor.run {
                    self.assets = searchResult.assets
                    self.nextPage = searchResult.nextPage
                    self.isLoading = false
                    // If there's no nextPage, we've reached the end
                    self.hasMoreAssets = searchResult.nextPage != nil
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
        // Cancel any existing load more task
        loadMoreTask?.cancel()
        
        // Create a new debounced task
        loadMoreTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000) // 300ms delay
            
            // Check if task was cancelled during sleep
            if Task.isCancelled { return }
            
            await MainActor.run {
                loadMoreAssets()
            }
        }
    }
    
    private func loadMoreAssets() {
        guard !isLoadingMore && hasMoreAssets && nextPage != nil else { return }
        
        isLoadingMore = true
        
        Task {
            do {
                // Extract page number from nextPage string
                let pageNumber = extractPageFromNextPage(nextPage!)
                let searchResult = try await immichService.fetchAssets(page: pageNumber, limit: 100, albumId: albumId)
                
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
}










