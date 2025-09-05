//
//  ExploreView.swift
//  Immich Gallery
//
//  Created by mensadi-labs on 2025-09-05.
//

import SwiftUI

struct ExploreView: View {
    @ObservedObject var exploreService: ExploreService
    @ObservedObject var assetService: AssetService
    @ObservedObject var authService: AuthenticationService
    
    @State private var assets: [ImmichAsset] = []
    @State private var exploreItems: [ExploreAsset] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedAsset: ImmichAsset?
    @State private var showingFullScreen = false
    @State private var currentAssetIndex: Int = 0
    
    var body: some View {
        SharedGridView(
            items: exploreItems,
            config: .peopleStyle,
            thumbnailProvider: ExploreThumbnailProvider(assetService: assetService),
            isLoading: isLoading,
            errorMessage: errorMessage,
            onItemSelected: { item in
                selectedAsset = item.asset
                if let index = assets.firstIndex(of: item.asset) {
                    currentAssetIndex = index
                }
                showingFullScreen = true
            },
            onRetry: {
                loadExploreData()
            }
        )
        .onAppear {
            if assets.isEmpty {
                loadExploreData()
            }
        }
    }
    
    private func loadExploreData() {
        guard authService.isAuthenticated else {
            errorMessage = "Not authenticated. Please check your credentials."
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let result = try await exploreService.fetchExploreData()
                await MainActor.run {
                    self.assets = result
                    self.exploreItems = result.map { ExploreAsset(asset: $0) }
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

// MARK: - Thumbnail Provider for Explore Items
class ExploreThumbnailProvider: ThumbnailProvider {
    private let assetService: AssetService
    
    init(assetService: AssetService) {
        self.assetService = assetService
    }
    
    func loadThumbnails(for item: GridDisplayable) async -> [UIImage] {
        guard let exploreAsset = item as? ExploreAsset else { return [] }
        
        do {
            if let image = try await assetService.loadImage(asset: exploreAsset.asset, size: "thumbnail") {
                return [image]
            }
        } catch {
            print("Failed to load thumbnail for explore asset: \(error)")
        }
        
        return []
    }
}
