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
    @FocusState private var focusedAssetId: String?
    
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
            
            VStack(spacing: 20) {
                    // Search results
                    if isLoading {
                        Spacer()
                        ProgressView("Searching...")
                            .foregroundColor(.white)
                            .scaleEffect(1.5)
                        Spacer()
                    } else if let errorMessage = errorMessage {
                        Spacer()
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
                        Spacer()
                    } else if assets.isEmpty && !searchText.isEmpty {
                        Spacer()
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
                        Spacer()
                    } else if searchText.isEmpty {
                        Spacer()
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
                        Spacer()
                    } else {
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
                                    .buttonStyle(CardButtonStyle())
                                }
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 40)
                        }
                    }
            }
        }
        .searchable(text: $searchText, prompt: "Search by context: Mountains, sunsets, etc...")
        .onSubmit(of: .search) {
            performSearch()
        }
        .onChange(of: searchText) { oldValue, newValue in
            // Debounce search to avoid too many API calls while typing
            if !newValue.isEmpty {
                performSearch()
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
