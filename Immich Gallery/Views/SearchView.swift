//
//  SearchView.swift
//  Immich Gallery
//
//  Created by mensadi-labs on 2025-08-09.
//

import SwiftUI
import UIKit

struct SearchView: View {
    @ObservedObject var searchService: SearchService
    @ObservedObject var assetService: AssetService
    @ObservedObject var authService: AuthenticationService

    @State private var searchText = ""
    @State private var assets: [ImmichAsset] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedAsset: ImmichAsset?
    @State private var showingFullScreen = false
    @State private var currentAssetIndex: Int = 0
    @State private var isScrolling = false
    @State private var searchTask: Task<Void, Never>? = nil
    @FocusState private var focusedAssetId: String?

    var body: some View {
        ZStack {
            SharedGradientBackground()

            // Pass down tracking states to the dynamic geometric grid child view
            SearchGridContent(
                assets: assets,
                assetService: assetService,
                isScrolling: isScrolling,
                focusedAssetId: $focusedAssetId,
                selectedAsset: $selectedAsset,
                currentAssetIndex: $currentAssetIndex,
                showingFullScreen: $showingFullScreen
            )
            .onScrollPhaseChange { _, newPhase, context in
                isScrolling = ThumbnailScrollLoadingPolicy.shouldPauseLoading(
                    during: newPhase,
                    velocity: context.velocity
                )
            }
            .overlay {
                searchStateOverlay
            }
            // Standard tvOS searchable modifier
            .searchable(text: $searchText, prompt: "Search by context: Mountains, sunsets, etc...")
            .onSubmit(of: .search) {
                searchTask?.cancel()
                performSearch()
            }
            .onChange(of: searchText) { _, newValue in
                searchTask?.cancel()

                let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else {
                    assets = []
                    return
                }

                // 0.5-second debounce to protect your Immich instance from keyboard key-stutters
                searchTask = Task {
                    do {
                        try await Task.sleep(for: .seconds(0.5))
                        guard !Task.isCancelled else { return }
                        performSearch()
                    } catch {
                        // Task cancelled by a newer keystroke
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
    }

    @ViewBuilder
    private var searchStateOverlay: some View {
        if isLoading {
            ProgressView("Searching...")
                .foregroundColor(.white)
                .scaleEffect(1.5)
        } else if let errorMessage {
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
                    performSearch()
                }
                .buttonStyle(.borderedProminent)
            }
        } else if assets.isEmpty && !searchText.isEmpty {
            VStack {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 60))
                    .foregroundColor(.gray)
                Text("No Results Found")
                    .font(.title)
                    .foregroundColor(.white)
                Text("Try different search terms")
                    .foregroundColor(.gray)
            }
        } else if searchText.isEmpty {
            VStack {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 60))
                    .foregroundColor(.gray)
                Text("Search Your Photos")
                    .font(.title)
                    .foregroundColor(.white)
                Text("Use the search field to find your photos")
                    .foregroundColor(.gray)
            }
        }
    }

    private func performSearch() {
        let trimmedText = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            return
        }

        print("SearchView: Performing search for: '\(trimmedText)'")

        Task {
            await MainActor.run {
                isLoading = true
                errorMessage = nil
                assets = []
            }

            do {
                let result = try await searchService.searchAssets(query: trimmedText)
                await MainActor.run {
                    print("SearchView: Search completed, found \(result.assets.count) assets")
                    assets = result.assets
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    print("SearchView: Search failed with error: \(error)")
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
}

// Dynamic container view that adapts based on actual available layout width
private struct SearchGridContent: View {
    @Environment(\.isSearching) private var isSearching

    let assets: [ImmichAsset]
    let assetService: AssetService
    let isScrolling: Bool

    @FocusState.Binding var focusedAssetId: String?
    @Binding var selectedAsset: ImmichAsset?
    @Binding var currentAssetIndex: Int
    @Binding var showingFullScreen: Bool

    var body: some View {
        GeometryReader { geometry in
            // On tvOS, if a side grid keyboard is present, the available width drops below ~1300pt.
            // If a linear top-bar keyboard is active, the width stays full-screen (~1920pt).
            let isSideKeyboardActive = isSearching && (geometry.size.width < 1300)

            let gridWidth: CGFloat = isSideKeyboardActive ? 1_000 : 1_700
            let columnCount = isSideKeyboardActive ? 3 : 5

            let columns = Array(
                repeating: GridItem(.flexible(minimum: 250, maximum: 350), spacing: 50),
                count: columnCount
            )

            ScrollView {
                VStack(spacing: 0) {
                    LazyVGrid(columns: columns, alignment: .leading, spacing: 50) {
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
                                    shouldLoadThumbnail: !isScrolling
                                )
                            }
                            .frame(width: 300, height: 360)
                            .id(asset.id)
                            .focused($focusedAssetId, equals: asset.id)
                            .animation(.easeInOut(duration: 0.2), value: focusedAssetId)
                            .buttonStyle(CardButtonStyle())
                        }
                    }
                    .focusSection()
                    .frame(width: gridWidth, alignment: .leading)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.horizontal)
                    .padding(.bottom, 40)
                }
            }
            .defaultFocus($focusedAssetId, assets.first?.id)
        }
    }
}
