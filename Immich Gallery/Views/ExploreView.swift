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
    @ObservedObject var userManager: UserManager
    
    @State private var assets: [ImmichAsset] = []
    @State private var exploreItems: [ExploreAsset] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedAsset: ImmichAsset?
    @State private var showingFullScreen = false
    @State private var currentAssetIndex: Int = 0
    @State private var showingStats = false
    @State private var selectedExploreItem: ExploreAsset?
    
    var body: some View {
        ZStack {
            SharedGradientBackground()
            
            if isLoading {
                ProgressView("Loading explore data...")
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
                        loadExploreData()
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else if exploreItems.isEmpty {
                VStack {
                    Image(systemName: "photo")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    Text("No Places Found")
                        .font(.title)
                        .foregroundColor(.white)
                    Text("Photos with location data will appear here")
                        .foregroundColor(.gray)
                }
            } else {
                // cannot use sharedGridView directly because we want the button to scroll away
                ScrollView {
                    LazyVStack(spacing: 20) {
                        // Stats Button Header
                        VStack(spacing: 16) {
                            Button(action: {
                                showingStats = true
                            }) {
                                HStack(spacing: 16) {
                                    Image(systemName: "chart.bar.fill")
                                        .font(.title2)
                                        .foregroundColor(.blue)
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Library Statistics")
                                            .font(.headline)
                                            .foregroundColor(.primary)
                                        Text("View places visited and people stats")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.blue)
                                        .font(.caption)
                                }
                                .padding()
                                .background(Color.blue.opacity(0.05))
                                .cornerRadius(12)
                            }
                            .buttonStyle(CardButtonStyle())
                        }
                        .padding(.horizontal)
                        
                        // Grid Content
                        LazyVGrid(columns: GridConfig.peopleStyle.columns, spacing: GridConfig.peopleStyle.spacing) {
                            ForEach(exploreItems) { item in
                                Button(action: {
                                    selectedAsset = item.asset
                                    if let index = assets.firstIndex(of: item.asset) {
                                        currentAssetIndex = index
                                    }
                                    showingFullScreen = true
                                }) {
                                    SharedGridItemView(
                                        item: item,
                                        config: .peopleStyle,
                                        thumbnailProvider: ExploreThumbnailProvider(assetService: assetService),
                                        isFocused: false,
                                        animationTrigger: 0
                                    )
                                }
                                .frame(width: GridConfig.peopleStyle.itemWidth, height: GridConfig.peopleStyle.itemHeight)
                                .padding(10)
                                .buttonStyle(CardButtonStyle())
                            }
                        }
                    }
                    .padding(.vertical)
                }
            }
        }
        .sheet(isPresented: $showingStats) {
            StatsView(statsService: createStatsService())
        }
        .fullScreenCover(item: $selectedExploreItem) { exploreItem in
            ExploreDetailView(city: exploreItem.primaryTitle, assetService: assetService, authService: authService)
        }
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
    
    private func createStatsService() -> StatsService {
        let networkService = NetworkService(userManager: userManager)
        let exploreService = ExploreService(networkService: networkService)
        let peopleService = PeopleService(networkService: networkService)
        return StatsService(exploreService: exploreService, peopleService: peopleService, networkService: networkService)
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
