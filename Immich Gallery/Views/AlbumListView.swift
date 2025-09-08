//
//  AlbumListView.swift
//  Immich Gallery
//
//  Created by mensadi-labs on 2025-06-29.
//

import SwiftUI

struct AlbumListView: View {
    @ObservedObject var albumService: AlbumService
    @ObservedObject var authService: AuthenticationService
    @ObservedObject var assetService: AssetService
    @ObservedObject var userManager: UserManager
    @State private var albums: [ImmichAlbum] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var favoritesCount: Int = 0
    @State private var firstFavoriteAssetId: String?
    @State private var selectedAlbum: ImmichAlbum?
    
    private var thumbnailProvider: AlbumThumbnailProvider {
        AlbumThumbnailProvider(albumService: albumService, assetService: assetService)
    }
    
    private var allAlbums: [ImmichAlbum] {
        var result = albums
        if let favAlbums = createFavoritesAlbum() {
            result.insert(favAlbums, at: 0)
        }
        return result
    }
    
    var body: some View {
        SharedGridView(
            items: allAlbums,
            config: .albumStyle,
            thumbnailProvider: thumbnailProvider,
            isLoading: isLoading,
            errorMessage: errorMessage,
            onItemSelected: { album in
                selectedAlbum = album
            },
            onRetry: loadAlbums
        )
        .fullScreenCover(item: $selectedAlbum) { album in
            AlbumDetailView(album: album, albumService: albumService, authService: authService, assetService: assetService)
        }
        .onAppear {
            if albums.isEmpty {
                loadAlbums()
                loadFavoritesCount()
            }
        }
    }
    
    private func createFavoritesAlbum() -> ImmichAlbum?  {
        
        if let user = userManager.currentUser {
            let owner = Owner(
                id: user.id,
                email: user.email,
                name: user.name,
                profileImagePath: "",
                profileChangedAt: "",
                avatarColor: "primary"
            )
            
            return ImmichAlbum(
                id: "smart_favorites",
                albumName: "Favorites",
                description: "Collection",
                albumThumbnailAssetId: firstFavoriteAssetId,
                createdAt: ISO8601DateFormatter().string(from: Date()),
                updatedAt: ISO8601DateFormatter().string(from: Date()),
                albumUsers: [],
                assets: [],
                assetCount: favoritesCount,
                ownerId: user.id,
                owner: owner,
                shared: false,
                hasSharedLink: false,
                isActivityEnabled: false,
                lastModifiedAssetTimestamp: nil,
                order: nil,
                startDate: nil,
                endDate: nil
            )
        }
        return nil
    }
    
    private func loadFavoritesCount() {
        guard authService.isAuthenticated else { return }
        
        Task {
            do {
                let result = try await assetService.fetchAssets(page: 1, limit: nil, isFavorite: true)
                await MainActor.run {
                    self.favoritesCount = result.total
                    self.firstFavoriteAssetId = result.assets.first?.id
                }
            } catch {
                print("Failed to fetch favorites count: \(error)")
            }
        }
    }
    
    private func loadAlbums() {
        guard authService.isAuthenticated else {
            errorMessage = "Not authenticated. Please check your credentials."
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let fetchedAlbums = try await albumService.fetchAlbums()
                await MainActor.run {
                    // Filter out the config album from the display
                    let configAlbumName = AppConstants.configAlbumName
                    self.albums = fetchedAlbums.filter { $0.albumName !=  configAlbumName }
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


struct AlbumDetailView: View {
    let album: ImmichAlbum
    @ObservedObject var albumService: AlbumService
    @ObservedObject var authService: AuthenticationService
    @ObservedObject var assetService: AssetService
    @Environment(\.dismiss) private var dismiss
    @State private var albumAssets: [ImmichAsset] = []
    @State private var slideshowTrigger: Bool = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black
                    .ignoresSafeArea()
                
                AssetGridView(
                    assetService: assetService,
                    authService: authService,
                    assetProvider: createAssetProvider(for: album),
                    albumId: album.id.hasPrefix("smart_") ? nil : album.id,
                    personId: nil,
                    tagId: nil,
                    city: nil,
                    isAllPhotos: false,
                    isFavorite: album.id.hasPrefix("smart_") ? true : false,
                    onAssetsLoaded: { loadedAssets in
                        self.albumAssets = loadedAssets
                    },
                    deepLinkAssetId: nil
                )
            }
            .navigationTitle(album.albumName)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: startSlideshow) {
                        Image(systemName: "play.rectangle")
                            .foregroundColor(.white)
                    }
                    .disabled(albumAssets.isEmpty)
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
        .fullScreenCover(isPresented: $slideshowTrigger) {
            SlideshowView(
                albumId: album.id.hasPrefix("smart_") ? nil : album.id, 
                personId: nil, 
                tagId: nil, 
                city: nil,
                startingIndex: 0,
                isFavorite: album.id == "smart_favorites"
            )
        }
        .onAppear(){
            print("Album defaul view")
        }
    }
    
    private func createAssetProvider(for album: ImmichAlbum) -> AssetProvider {
        if album.id == "smart_favorites" {
            return AssetProviderFactory.createProvider(
                isFavorite: true,
                assetService: assetService
            )
        } else {
            return AssetProviderFactory.createProvider(
                albumId: album.id,
                assetService: assetService,
                albumService: albumService
            )
        }
    }
    
    private func startSlideshow() {
        // Stop auto-slideshow timer before starting slideshow
        NotificationCenter.default.post(name: NSNotification.Name("stopAutoSlideshowTimer"), object: nil)
        slideshowTrigger = true
    }
}

#Preview {
    let (_, userManager, authService, assetService, albumService, peopleService, _) =
         MockServiceFactory.createMockServices()
    AlbumListView(albumService: albumService, authService: authService, assetService: assetService, userManager: userManager)
}
