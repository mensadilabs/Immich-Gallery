//
//  AssetGridView.swift
//  Immich Gallery
//
//  Created by mensadi-labs on 2025-06-29.
//

import SwiftUI

struct AssetGridView: View {
    @ObservedObject var immichService: ImmichService
    @State private var assets: [ImmichAsset] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedAsset: ImmichAsset?
    @State private var showingFullScreen = false
    @FocusState private var focusedAssetId: String?
    
    private let columns = [
        GridItem(.fixed(280), spacing: 20),
        GridItem(.fixed(280), spacing: 20),
        GridItem(.fixed(280), spacing: 20),
        GridItem(.fixed(280), spacing: 20),
        GridItem(.fixed(280), spacing: 20)
    ]
    
    var body: some View {
        ZStack {
            // Background
            Color.black
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
                    Text("No Photos Found")
                        .font(.title)
                        .foregroundColor(.white)
                    Text("Your photos will appear here")
                        .foregroundColor(.gray)
                }
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 20) {
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
                            .frame(width: 280, height: 340)
                            .focused($focusedAssetId, equals: asset.id)
                            .scaleEffect(focusedAssetId == asset.id ? 1.05 : 1.0)
                            .animation(.easeInOut(duration: 0.2), value: focusedAssetId)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 80)
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
    }
    
    private func loadAssets() {
        guard immichService.isAuthenticated else {
            errorMessage = "Not authenticated. Please check your credentials."
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let fetchedAssets = try await immichService.fetchAssets(page: 1, limit: 100)
                await MainActor.run {
                    self.assets = fetchedAssets
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
}










